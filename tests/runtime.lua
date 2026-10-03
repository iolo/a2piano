-- Run only in the isolated process created by tools/verify_emulator.py.
local machine=manager.machine
local cpu=machine.devices[':maincpu']
local s=cpu.spaces['program']
local out=os.getenv('A2_OUT')
local config=dofile(out..'/scenario.lua')
local labels={}
for line in io.lines((os.getenv('A2_LABELS') or (os.getenv('A2_ROOT')..'/build/a2piano.lbl'))) do
 local addr,name=line:match('al (%x+) %.([%w_]+)')
 if addr then labels[name]=tonumber(addr,16) end
end
local f=assert(io.open(out..'/events.csv','w'));f:write('kind,time,a,b\n')
local function time() return machine.time:as_double() end
local function log(kind,a,b) f:write(string.format('%s,%.12f,%d,%d\n',kind,time(),a or 0,b or 0)) end
local taps={};local pending=nil;local index=1;local stage='boot';local nexttime=12
local held_code=0;local held_until=0
local idle_screen={};local visual_error=nil;local marked_frames={}
-- Independent screen coordinates for all 21 chromatic notes (zero-based).
local white_columns={[0]=0,[2]=3,[3]=6,[5]=9,[7]=12,[8]=15,[10]=18,
 [12]=21,[14]=24,[15]=27,[17]=30,[19]=33,[20]=36}
local black_columns={[1]=2,[4]=8,[6]=11,[9]=17,[11]=20,[13]=23,[16]=29,[18]=32}
local function verify_marker(playing)
 if #idle_screen==0 then return end
 local note=s:read_u8(labels._last_note)
 local white=white_columns[note]~=nil
 local column=white_columns[note] or black_columns[note]
 local marker=playing and column and ((white and 14 or 9)*40+column+1) or 0
 for y=0,23 do for x=0,39 do
  local i=y*40+x+1
  local expected=i==marker and (white and 42 or 170) or idle_screen[i]
  local actual=s:read_u8(0x400+(y%8)*128+math.floor(y/8)*40+x)
  if actual~=expected then
   visual_error=string.format('marker mismatch note=%d playing=%s at %d,%d: %d != %d',note,tostring(playing),x,y,actual,expected)
   return
  end
 end end
end
local function tapread(a,b,name,fn) table.insert(taps,s:install_read_tap(a,b,name,fn)) end
local function tapwrite(a,b,name,fn) table.insert(taps,s:install_write_tap(a,b,name,fn)) end
local function inject(k,duration)
 assert(not pending,'previous strobe unconsumed')
 held_code=k;held_until=time()+(duration or 0.1)
 pending=k;log('latch',k,index)
end
local function snapshot()
 local sf=assert(io.open(out..'/screen.txt','w'))
 local raw=assert(io.open(out..'/screen.bin','wb'))
 for y=0,23 do
  local line=''
  for x=0,39 do
   local v=s:read_u8(0x400+(y%8)*128+math.floor(y/8)*40+x)
   raw:write(string.char(v))
   if stage=='ready' then idle_screen[y*40+x+1]=v end
   local b=v%128;if b<32 then b=b+64 end
   line=line..string.char(b)
  end
  sf:write(line..'\n')
 end
 raw:close();sf:close();machine.screens[':screen']:snapshot(out..'/screen.png')
end
local function install()
 tapread(0xc000,0xc000,'keyboard',function() return pending and pending+128 or held_code end)
 tapread(0xc010,0xc010,'strobe',function()
  if pending then log('consume',pending);pending=nil end
  return held_code+(held_until>0 and 128 or 0)
 end)
 tapread(0xc030,0xc030,'speaker',function() log('speaker',s:read_u8(labels._last_note),s:read_u8(labels._event_count)) end)
 tapwrite(0xc100,0xc7ff,'slot-write',function(a,d)log('io-write',a,d)end)
 tapread(0xc100,0xc7ff,'slot-read',function(a,d)
  -- Polling reads are numerous: record only the first occurrence per address.
  if not config.seen then config.seen={} end
  if not config.seen[a] then log('io-read',a,d);config.seen[a]=true end
 end)
 tapwrite(labels._event_count,labels._event_count,'event',function(a,d)log('event',s:read_u8(labels._last_note),d)end)
 tapwrite(labels._active,labels._active,'active',function(a,d)
  log('active',d,s:read_u8(labels._event_count));verify_marker(d==1)
 end)
 local meta=assert(io.open(out..'/machine.txt','w'))
 meta:write('MAME '..emu.app_version()..' '..emu.romname()..'\n')
 for tag,dev in pairs(machine.devices) do
  if tag:find('maincpu') or tag:find('mocking') then meta:write(tag..'\n') end
 end
 meta:close()
end
local function step()
 local now=time()
 assert(not visual_error,visual_error)
 if #idle_screen>0 and s:read_u8(labels._active)==1 then
  local kind=white_columns[s:read_u8(labels._last_note)] and 'white' or 'black'
  if not marked_frames[kind] then
   machine.screens[':screen']:snapshot(out..'/active-'..kind..'.png');marked_frames[kind]=true
  end
 end
 if held_until>0 and now>=held_until then
  held_until=0;log('release',held_code)
 end
 if now<nexttime then return end
 if stage=='boot' then
  assert(now<30,'boot prompt timeout')
  -- Wait for actual startup prompt, after cc65 has finished bank switching.
  if s:read_u8(0x480)~=193 or s:read_u8(0x700)~=210 then return end
  install();stage='setup';index=1
 end
 if stage=='setup' then
  if index<=#config.setup then inject(config.setup[index]);index=index+1;nexttime=now+0.3;return end
  stage='ready';nexttime=now+0.1
 elseif stage=='ready' then
  assert(now<25,'startup never reached ready')
  if s:read_u8(labels._ready)~=1 then return end
  assert(s:read_u8(labels._release_supported)==(emu.romname()=='apple2p' and 0 or 1),'AKD model detection')
  snapshot();log('ready');stage='notes';index=1;nexttime=now+0.2
 elseif stage=='notes' then
  if index<=#config.keys then
   inject(config.keys[index],0.5);index=index+1;nexttime=now+0.7
  else stage='interrupt';index=1;nexttime=now+0.1 end
 elseif stage=='interrupt' then
  if index<=#config.interrupt then
   inject(config.interrupt[index],0.025);index=index+1;nexttime=now+0.05
  else stage='finish';nexttime=now+0.7 end
 elseif stage=='finish' then
  assert(s:read_u8(labels._active)==0,'stuck active')
  verify_marker(false);assert(not visual_error,visual_error)
  log('finish');f:close()
  local pass=assert(io.open(out..'/PASS','w'));pass:write('runtime completed\n');pass:close()
  stage='done';machine:exit()
 end
end
emu.register_frame_done(function()
 local ok,err=pcall(step)
 if not ok then
  local fail=assert(io.open(out..'/FAIL','w'));fail:write(tostring(err));fail:close()
  snapshot();f:close();stage='done';machine:exit()
 end
end)
