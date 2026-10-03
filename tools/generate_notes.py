#!/usr/bin/env python3
"""One source of note mapping and equal-tempered timing, A4 = 440 Hz."""
import json, math
from pathlib import Path
CPU_HZ = 1020484
AY_HZ = 1022727
DURATION_MS = 500
LABELS = 'A3 A#3 B3 C4 C#4 D4 D#4 E4 F4 F#4 G4 G#4 A4 A#4 B4 C5 C#5 D5 D#5 E5 F5'.split()
OLD = [27,49,81,87,52,69,53,82,84,55,89,56,85,57,73,79,58,80,45,8,21]
NEW = [9,49,81,87,52,69,53,82,84,55,89,56,85,57,73,79,45,80,61,91,93]
def rows():
    result=[]; white_col=0
    for i,label in enumerate(LABELS):
        hz=440*2**((i-12)/12)
        # speaker: fixed 51 cycles + 5*inner + 1284*outer.
        target=CPU_HZ/(2*hz)
        candidates=[(abs(51+5*b+1284*a-target),a,b) for a in range(2) for b in range(1,256)]
        _,a,b=min(candidates); half=51+5*b+1284*a
        white='#' not in label
        col=white_col if white else white_col-1
        if white: white_col+=3
        result.append(dict(label=label,old_key=OLD[i],new_key=NEW[i],white=int(white),column=col,
                           delay_outer=a,delay_inner=b,toggles=math.floor(CPU_HZ*DURATION_MS/1000/half),
                           ay_period=round(AY_HZ/(16*hz)),hz=hz,half_cycles=half,
                           speaker_hz=CPU_HZ/(2*half),ay_hz=AY_HZ/(16*round(AY_HZ/(16*hz)))))
    return result
if __name__=='__main__':
    out=Path('build');out.mkdir(exist_ok=True)
    data=rows()
    fields=['old_key','new_key','white','column','delay_outer','delay_inner','toggles','ay_period']
    (out/'notes.c').write_text('#include "notes.h"\nconst Note notes[NOTE_COUNT] = {\n'+''.join('    {"'+r['label']+'", '+', '.join(str(r[f]) for f in fields)+'},\n' for r in data)+'};\n')
    (out/'notes.json').write_text(json.dumps({'cpu_hz':CPU_HZ,'ay_hz':AY_HZ,'duration_ms':DURATION_MS,'notes':data},indent=2)+'\n')
    (out/'timing.inc').write_text('; Generated, do not edit\nMB_TICKS = 10\nMB_TIMER = '+str(math.floor(CPU_HZ*DURATION_MS/10000)-2)+'\n')
