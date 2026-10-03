local m=manager.machine;local s=m.devices[':maincpu'].spaces['program']
local out=os.getenv('A2_OUT');local root=os.getenv('A2_ROOT')
local labels={}
for line in io.lines(root..'/build/a2piano.lbl') do local a,n=line:match('al (%x+) %.([%w_]+)');if a then labels[n]=tonumber(a,16)end end
local f=assert(io.open(out..'/keyboard.txt','w'))
f:write(m.natkeyboard:dump()..'\n')
for tag,port in pairs(m.ioport.ports) do for name,field in pairs(port.fields) do f:write(tag..' '..name..' mask='..field.mask..'\n') end end
f:flush()
local modern=emu.romname()~='apple2p'
local keys=modern and {9,49,81,87,52,69,53,82,84,55,89,56,85,57,73,79,45,80,61,91,93} or {27,49,81,87,52,69,53,82,84,55,89,56,85,57,73,79,58,80,45,8,21}
local held={}
local function release() for _,v in ipairs(held)do v:clear_value()end;held={}end
local nexttime=12;local stage=0;local index=1;local before=0
local function step()
 local now=m.time:as_double();if now<nexttime then return end
 if stage==0 then
  assert(now<30,'boot timeout')
  if s:read_u8(0x480)~=193 or s:read_u8(0x700)~=210 then return end
  m.natkeyboard:post('\r');stage=1;nexttime=now+1
 elseif stage==1 then m.natkeyboard:post('\r');stage=2;nexttime=now+3
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
  local q=modern and m.ioport.ports[':X1'].fields['q  Q'] or m.ioport.ports[':kbd:nkbd:X1'].fields['Q']
  q:set_value(1);table.insert(held,q)
  if not modern then local r=m.ioport.ports[':kbd:nkbd:keyb_repeat'].fields['Rept'];r:set_value(1);table.insert(held,r) end
  stage=6;nexttime=now+2
 elseif stage==6 then
  release()
  local count=(s:read_u8(labels._event_count)-before)%256
  f:write('held repeat events='..count..'\n');f:flush()
  assert(count>=2,'held key failed to retrigger')
  assert(s:read_u8(labels._last_note)==2,'held wrong note')
  stage=7;nexttime=now+.8
 elseif stage==7 then
  assert(s:read_u8(labels._active)==0,'held note did not expire')
  f:write('PASS all physical keyboard bindings and held repeat\n');f:close();m:exit();stage=4
 end
end
emu.register_frame_done(function()local ok,e=pcall(step);if not ok then release();f:write('FAIL '..tostring(e));f:close();stage=4;m:exit()end end)
