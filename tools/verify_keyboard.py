#!/usr/bin/env python3
import json,os,re,shutil,subprocess,wave
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[1]
for name in ['speaker-ii-plus','speaker-iie','speaker-platinum','mb-slot4','mb-slot5']:
 src=root/'build/verification'/name
 out=root/'build/verification'/('keyboard-'+name);out.mkdir(exist_ok=True)
 cmd=json.loads((src/'command.json').read_text())
 cmd=[s.replace(str(src),str(out)).replace('tests/runtime.lua','tests/keyboard.lua') for s in cmd]
 shutil.copyfile(root/'a2piano.po',out/'disk.po')
 slot=json.loads((src/'manifest.json').read_text())['slot']
 env=dict(os.environ,SDL_VIDEODRIVER='dummy',SDL_AUDIODRIVER='dummy',A2_OUT=str(out),A2_ROOT=str(root),A2_MB_SLOT=str(slot))
 with (out/'mame.log').open('wb') as f:r=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=40)
 text=(out/'keyboard.txt').read_text();print(name+': '+text[text.find('held repeat'):].strip())
 assert r.returncode==0 and 'PASS all physical' in text
 if name=='mb-slot4':
  held_start=float(re.search(r'held start=([\d.]+)',text)[1])
  held_release=float(re.search(r'held release=([\d.]+)',text)[1])
  starts=[float(t) for t in re.findall(r'envelope start=([\d.]+)',text)]
  onsets=[t for t in starts if held_start<t<held_release]
  assert len(onsets)==1,'auto-repeat restarted the fading note'
  onset=onsets[0]
  with wave.open(str(out/'audio.wav')) as w:
   rate=w.getframerate()
   samples=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,w.getnchannels())
  levels=[]
  for offset in [.03,.20,.40,.65,.85]:
   clip=samples[int((onset+offset)*rate):int((onset+offset+.035)*rate)].astype(float)
   levels.append(float(np.sqrt(np.mean((clip-clip.mean(axis=0))**2,axis=0)).max()))
  assert levels[0]>100 and all(a>b*1.1 for a,b in zip(levels,levels[1:])),levels
  quiet=samples[int((onset+1.15)*rate):int((onset+1.8)*rate)].astype(float)
  assert np.ptp(quiet,axis=0).max()<4,'envelope did not reach and hold silence'
  # A new press after the silent hold must start audibly at full level again.
  next_onset=next(t for t in starts if t>held_release)
  clip=samples[int((next_onset+.025)*rate):int((next_onset+.06)*rate)].astype(float)
  restarted=float(np.sqrt(np.mean((clip-clip.mean(axis=0))**2,axis=0)).max())
  assert restarted>levels[0]*.9,'new note failed to restart envelope'
  result={'decay_rms':levels,'envelope_restarts_during_hold':len(onsets),
          'late_hold_peak_to_peak':float(np.ptp(quiet,axis=0).max()),'restarted_rms':restarted,'passed':True}
  (out/'decay-result.json').write_text(json.dumps(result,indent=2)+'\n')
  with wave.open(str(root/'build/verification/mockingboard-decay.wav'),'wb') as w:
   w.setnchannels(samples.shape[1]);w.setsampwidth(2);w.setframerate(rate)
   w.writeframes(samples[int((onset-.025)*rate):int((onset+1.85)*rate)].tobytes())
  print('hardware envelope: PASS decay, silent hold, no repeat restart, and new-note restart',flush=True)
