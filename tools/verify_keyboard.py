#!/usr/bin/env python3
import json,os,shutil,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
for name in ['speaker-ii-plus','speaker-iie','speaker-platinum']:
 src=root/'build/verification'/name
 out=root/'build/verification'/('keyboard-'+name);out.mkdir(exist_ok=True)
 cmd=json.loads((src/'command.json').read_text())
 cmd=[s.replace(str(src),str(out)).replace('tests/runtime.lua','tests/keyboard.lua') for s in cmd]
 shutil.copyfile(root/'a2piano.po',out/'disk.po')
 env=dict(os.environ,SDL_VIDEODRIVER='dummy',SDL_AUDIODRIVER='dummy',A2_OUT=str(out),A2_ROOT=str(root))
 with (out/'mame.log').open('wb') as f:r=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=40)
 text=(out/'keyboard.txt').read_text();print(name+': '+text[text.find('held repeat'):].strip())
 assert r.returncode==0 and 'PASS all physical' in text
