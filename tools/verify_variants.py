#!/usr/bin/env python3
"""Boot the separate diagnostic and speaker-only disks; check their behavior."""
import csv,json,os,shutil,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
for variant in ['diagnostic','speaker']:
 for model in ['speaker-ii-plus','speaker-iie']:
    src=root/'build/verification'/model
    out=root/'build/verification'/('variant-'+variant+'-'+model);out.mkdir(exist_ok=True)
    cmd=json.loads((src/'command.json').read_text())
    cmd=[s.replace(str(src),str(out)) for s in cmd]
    disk=root/'build'/('diagnostic.po' if variant=='diagnostic' else 'speaker-only.po')
    shutil.copyfile(disk,out/'disk.po')
    scenario=json.loads((src/'scenario.json').read_text())
    if variant=='speaker':scenario['setup']=[13]
    (out/'scenario.lua').write_text('return {'+','.join(k+'={'+','.join(map(str,v))+'}' for k,v in scenario.items())+'}\n')
    env=dict(os.environ,SDL_VIDEODRIVER='dummy',SDL_AUDIODRIVER='dummy',A2_OUT=str(out),A2_ROOT=str(root),A2_LABELS=str(root/'build'/(variant+'.lbl')))
    for name in ['PASS','FAIL']:(out/name).unlink(missing_ok=True)
    with (out/'mame.log').open('wb') as f:r=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=40)
    assert r.returncode==0 and (out/'PASS').exists(),out
    rows=list(csv.DictReader((out/'events.csv').open()));ready=float(next(r['time'] for r in rows if r['kind']=='ready'))
    notes=[];count=0
    for r in rows:
        if float(r['time'])>ready and r['kind']=='event' and int(r['b'])!=count:
            count=int(r['b']);notes.append(int(r['a']))
    assert notes[:21]==list(range(21))
    sound=[r for r in rows if float(r['time'])>ready and r['kind']=='speaker']
    assert bool(sound)==(variant=='speaker')
    assert not [r for r in rows if r['kind'].startswith('io-')]
    (out/'variant-result.json').write_text(json.dumps({'variant':variant,'model':model,'mapped_notes':21,'speaker_transitions':len(sound),'passed':True},indent=2)+'\n')
    print(variant+' '+model+': PASS',flush=True)
