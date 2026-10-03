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
local function tapread(a,b,name,fn) table.insert(taps,s:install_read_tap(a,b,name,fn)) end
local function tapwrite(a,b,name,fn) table.insert(taps,s:install_write_tap(a,b,name,fn)) end
local function inject(k)
 assert(not pending,'previous strobe unconsumed')
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
   local b=v%128;if b<32 then b=b+64 end
   line=line..string.char(b)
  end
  sf:write(line..'\n')
 end
 raw:close();sf:close();machine.screens[':screen']:snapshot(out..'/screen.png')
end
local function install()
 tapread(0xc000,0xc000,'keyboard',function(a,d) if pending then return pending+128 end end)
 tapread(0xc010,0xc010,'strobe',function() if pending then log('consume',pending);pending=nil end end)
 tapread(0xc030,0xc030,'speaker',function() log('speaker',s:read_u8(labels._last_note),s:read_u8(labels._event_count)) end)
 tapwrite(0xc100,0xc7ff,'slot-write',function(a,d)log('io-write',a,d)end)
 tapread(0xc100,0xc7ff,'slot-read',function(a,d)
  -- Polling reads are numerous: record only the first occurrence per address.
  if not config.seen then config.seen={} end
  if not config.seen[a] then log('io-read',a,d);config.seen[a]=true end
 end)
 tapwrite(labels._event_count,labels._event_count,'event',function(a,d)log('event',s:read_u8(labels._last_note),d)end)
 tapwrite(labels._active,labels._active,'active',function(a,d)log('active',d,s:read_u8(labels._event_count))end)
 local meta=assert(io.open(out..'/machine.txt','w'))
 meta:write('MAME '..emu.app_version()..' '..emu.romname()..'\n')
 for tag,dev in pairs(machine.devices) do
  if tag:find('maincpu') or tag:find('mocking') then meta:write(tag..'\n') end
 end
 meta:close()
end
local function step()
 local now=time()
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
  snapshot();log('ready');stage='notes';index=1;nexttime=now+0.2
 elseif stage=='notes' then
  if index<=#config.keys then
   inject(config.keys[index]);index=index+1;nexttime=now+0.7
  else stage='interrupt';index=1;nexttime=now+0.1 end
 elseif stage=='interrupt' then
  if index<=#config.interrupt then
   inject(config.interrupt[index]);index=index+1;nexttime=now+0.05
  else stage='finish';nexttime=now+0.7 end
 elseif stage=='finish' then
  assert(s:read_u8(labels._active)==0,'stuck active')
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
