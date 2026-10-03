local m=manager.machine;local s=m.devices[':maincpu'].spaces['program']
local out=os.getenv('A2_OUT');local root=os.getenv('A2_ROOT')
local labels={}
for line in io.lines(root..'/build/a2piano.lbl') do local a,n=line:match('al (%x+) %.([%w_]+)');if a then labels[n]=tonumber(a,16)end end
local f=assert(io.open(out..'/keyboard.txt','w'))
f:write(m.natkeyboard:dump()..'\n')
for tag,port in pairs(m.ioport.ports) do for name,field in pairs(port.fields) do f:write(tag..' '..name..' mask='..field.mask..'\n') end end
f:flush()
local modern=emu.romname()~='apple2p'
local slot=tonumber(os.getenv('A2_MB_SLOT') or '0')
local keys=modern and {9,49,81,87,52,69,53,82,84,55,89,56,85,57,73,79,45,80,61,91,93} or {27,49,81,87,52,69,53,82,84,55,89,56,85,57,73,79,58,80,45,8,21}
local held={}
local function release() for _,v in ipairs(held)do v:clear_value()end;held={}end
local nexttime=12;local stage=0;local index=1;local before=0
local released_at=0;local stopped_at=0;local last_edge=0;local max_gap=0;local min_gap=1
local ay_data=0;local ay_register=0;local ay_volume=0;local taps={}
local function install_taps()
table.insert(taps,s:install_write_tap(labels._active,labels._active,'release-time',function(a,d)
 if d==0 then stopped_at=m.time:as_double() end
end))
table.insert(taps,s:install_read_tap(0xc030,0xc030,'held-tone',function()
 if stage==6 then
  local now=m.time:as_double()
  if last_edge>0 then local gap=now-last_edge;max_gap=math.max(max_gap,gap);min_gap=math.min(min_gap,gap) end
  last_edge=now
 end
end))
if slot>0 then
 table.insert(taps,s:install_write_tap(0xc000+slot*256,0xc001+slot*256,'ay-volume',function(a,d)
  if a%256==1 then ay_data=d
  elseif d==7 then ay_register=ay_data
  elseif d==6 then
   if ay_register==8 then ay_volume=ay_data end
   if ay_register==13 then
    assert(ay_data==0,'unexpected envelope shape')
    f:write(string.format('envelope start=%.12f\n',m.time:as_double()));f:flush()
   end
  end
 end))
end
end
local function press(name)
 local field
 for _,port in pairs(m.ioport.ports) do if port.fields[name] then field=port.fields[name];break end end
 assert(field,'missing physical key '..name);field:set_value(1);table.insert(held,field);return field
end
local function done()
 f:write('PASS all physical keyboard bindings, hold and release\n');f:close();m:exit();stage=4
end
local function step()
 local now=m.time:as_double();if now<nexttime then return end
 if stage==0 then
  assert(now<30,'boot timeout')
  if s:read_u8(0x480)~=193 or s:read_u8(0x700)~=210 then return end
  m.natkeyboard:post('\r');stage=1;nexttime=now+1
 elseif stage==1 then install_taps();m.natkeyboard:post(slot>0 and ('m'..slot..'y') or '\r');stage=2;nexttime=now+3
 elseif stage==2 then
  assert(s:read_u8(labels._ready)==1,'not ready')
  if index>21 then stage=5;nexttime=now+.2;return end
  before=s:read_u8(labels._event_count)
  m.natkeyboard:post(string.char(keys[index]));stage=3;nexttime=now+.5
 elseif stage==3 then
  local k=s:read_u8(labels._last_key);local n=s:read_u8(labels._last_note);local c=s:read_u8(labels._event_count)
  f:write(string.format('key=%d observed=%d note=%d events=%d\n',keys[index],k,n,c-before));f:flush()
  assert(k==keys[index] and n==index-1 and c==before+1,'physical mapping')
  index=index+1;stage=2;nexttime=now+.1
 elseif stage==5 then
  before=s:read_u8(labels._event_count)
  f:write(string.format('held start=%.12f\n',now));f:flush()
  local q=modern and m.ioport.ports[':X1'].fields['q  Q'] or m.ioport.ports[':kbd:nkbd:X1'].fields['Q']
  q:set_value(1);table.insert(held,q)
  if not modern then local r=m.ioport.ports[':kbd:nkbd:keyb_repeat'].fields['Rept'];r:set_value(1);table.insert(held,r) end
  stage=6;nexttime=now+2
 elseif stage==6 then
  assert(s:read_u8(labels._active)==1,'held key tracking ended early')
  release()
  released_at=now
  f:write(string.format('held release=%.12f\n',now));f:flush()
  local count=(s:read_u8(labels._event_count)-before)%256
  f:write('held repeat events='..count..'\n');f:flush()
  assert(modern and count==1 or not modern and count>=2,'incorrect auto-repeat behavior')
  if modern and slot==0 then assert(last_edge>now-.01 and max_gap-min_gap<.000002,
   string.format('sustain interrupted: last=%f now=%f min=%f max=%f',last_edge,now,min_gap,max_gap)) end
  if modern and slot==0 then f:write(string.format('held tone jitter=%.3f us\n',(max_gap-min_gap)*1000000)) end
  assert(s:read_u8(labels._last_note)==2,'held wrong note')
  stage=7;nexttime=now+(modern and .02 or .8)
 elseif stage==7 then
  assert(s:read_u8(labels._active)==0,'held note did not stop')
  if slot>0 then assert(ay_volume==0,'AY not muted') end
  if not modern then done();return end
  assert(stopped_at>=released_at and stopped_at-released_at<.020,'release latency')
  f:write(string.format('release latency=%.3f ms\n',(stopped_at-released_at)*1000));f:flush()
  press('q  Q');stage=8;nexttime=now+.1
 elseif stage==8 then
  assert(s:read_u8(labels._active)==1 and s:read_u8(labels._last_note)==2,'short tap onset')
  release();released_at=now;stage=9;nexttime=now+.02
 elseif stage==9 then
  assert(s:read_u8(labels._active)==0 and stopped_at-released_at<.020,'short tap release')
  press('q  Q');stage=10;nexttime=now+.1
 elseif stage==10 then
  press('w  W');stage=11;nexttime=now+.1
 elseif stage==11 then
  assert(s:read_u8(labels._active)==1 and s:read_u8(labels._last_note)==3,
   string.format('overlap replacement: active=%d note=%d key=%d',s:read_u8(labels._active),s:read_u8(labels._last_note),s:read_u8(labels._last_key)))
  held[#held]:clear_value();table.remove(held)
  stage=12;nexttime=now+.1
 elseif stage==12 then
  assert(s:read_u8(labels._active)==1 and s:read_u8(labels._last_note)==3,'AKD should stay high with Q held')
  press('Space');stage=13;nexttime=now+.1
 elseif stage==13 then
  assert(s:read_u8(labels._active)==0,'Space did not stop overlapping note')
  if slot>0 then assert(ay_volume==0,'Space did not mute AY') end
  release();stage=14;nexttime=now+.1
 elseif stage==14 then
  press('q  Q');stage=15;nexttime=now+.1
 elseif stage==15 then
  assert(s:read_u8(labels._active)==1,'same key did not play again after release')
  press('z  Z');stage=16;nexttime=now+.1
 elseif stage==16 then
  assert(s:read_u8(labels._active)==0,'unassigned key did not stop note')
  if slot>0 then assert(ay_volume==0,'unassigned key did not mute AY') end
  release();done()
 end
end
emu.register_frame_done(function()local ok,e=pcall(step);if not ok then release();f:write('FAIL '..tostring(e));f:close();stage=4;m:exit()end end)
