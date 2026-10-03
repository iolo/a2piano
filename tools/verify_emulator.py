#!/usr/bin/env python3
"""Cold-boot release disk in isolated MAME processes; collect real bus/audio data."""
import argparse, hashlib, json, os, shutil, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def run_case(name,model,slot=0,layout=None,setup=None):
    modern=(model!='apple2p') if layout is None else layout
    data=json.loads((ROOT/'build/notes.json').read_text())['notes']
    keys=[r['new_key' if modern else 'old_key'] for r in data]
    choices=setup or ([13 if layout is None else (78 if modern else 79)]+([77,48,56,48+slot,89] if slot else [13]))
    interrupt=[81,87,32,81,90,81,81,81,32]+[81,93 if modern else 21]*8+[32]
    if modern:interrupt += [113,119,32]
    out=ROOT/'build/verification'/name
    if out.exists():shutil.rmtree(out)
    out.mkdir(parents=True)
    shutil.copyfile(ROOT/'a2piano.po',out/'disk.po')
    scenario={'setup':choices,'keys':keys,'interrupt':interrupt}
    (out/'scenario.json').write_text(json.dumps(scenario,indent=2)+'\n')
    (out/'scenario.lua').write_text('return {'+','.join(k+'={'+','.join(map(str,v))+'}' for k,v in scenario.items())+'}\n')
    env=dict(os.environ,SDL_VIDEODRIVER='dummy',SDL_AUDIODRIVER='dummy',A2_OUT=str(out),A2_ROOT=str(ROOT))
    cmd=[os.environ.get('MAME','mame'),model,'-noreadconfig','-rompath',args.rompath,
         '-video','none','-sound','sdl','-nothrottle','-skip_gameinfo','-homepath',str(out),
         '-cfg_directory',str(out),'-nvram_directory',str(out),'-flop1',str(out/'disk.po'),
         '-autoboot_script',str(ROOT/'tests/runtime.lua'),'-autoboot_delay','0','-wavwrite',str(out/'audio.wav')]
    if model=='apple2p':cmd+=['-sl0','lang','-ramsize','48K']
    if model=='apple2e':cmd+=['-ramsize','64K','-aux','']
    cmd+=['-sl4','mockingboard' if slot==4 else '', '-sl5','mockingboard' if slot==5 else '']
    (out/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
    with (out/'mame.log').open('wb') as log:
        result=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=60)
    assert result.returncode==0,(out/'mame.log').read_text()
    assert (out/'PASS').exists(),(out/'FAIL').read_text() if (out/'FAIL').exists() else (out/'mame.log').read_text()
    manifest={'model':model,'slot':slot,'modern':modern,'sha256':hashlib.sha256((ROOT/'a2piano.po').read_bytes()).hexdigest()}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(name+': captured',flush=True)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rompath',default=os.environ.get('MAME_ROMPATH'))
    p.add_argument('--case',default='all')
    args=p.parse_args()
    if not args.rompath:p.error('set MAME_ROMPATH or pass --rompath with your MAME ROM directory')
    cases=[('speaker-ii-plus','apple2p',0,None,None),('speaker-iie','apple2e',0,None,None),
           ('speaker-platinum','apple2ep',0,None,None),('speaker-enhanced','apple2ee',0,None,None),('mb-slot4','apple2e',4,None,None),
           ('mb-slot5','apple2p',5,None,None),('override-old','apple2e',0,False,None),
           ('override-new','apple2p',0,True,None),('cancel-slot','apple2e',0,None,[13,77,48,56,27]),
           ('cancel-confirm','apple2e',0,None,[13,77,52,78])]
    for case in cases:
        if args.case in ('all',case[0]):
            if case[1]=='apple2ee':
                result=subprocess.run([os.environ.get('MAME','mame'),'apple2ee','-rompath',args.rompath,'-verifyroms'],capture_output=True)
                if result.returncode:
                    print('speaker-enhanced: SKIP (enhanced IIe ROM set unavailable)',flush=True)
                    continue
            run_case(*case)
