#!/usr/bin/env python3
"""Assert acceptance thresholds using MAME bus traces and independently rendered audio."""
import csv, hashlib, json, statistics, wave
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1]

def analyze(path):
    meta=json.loads((path/'manifest.json').read_text())
    assert meta['sha256']==hashlib.sha256((ROOT/'a2piano.po').read_bytes()).hexdigest(),'stale capture'
    notes=json.loads((ROOT/'build/notes.json').read_text())['notes']
    release_supported=meta['model']!='apple2p'
    scenario=json.loads((path/'scenario.json').read_text())
    rows=[dict(kind=r['kind'],t=float(r['time']),a=int(r['a']),b=int(r['b'])) for r in csv.DictReader((path/'events.csv').open())]
    assert rows[-1]['kind']=='finish'
    ready=next(r['t'] for r in rows if r['kind']=='ready')
    play=[r for r in rows if r['t']>ready]
    latches=[r for r in play if r['kind']=='latch']
    events=[];count=0
    for r in play:
        if r['kind']=='event' and r['b']!=count:
            assert r['b']==count+1
            events.append(r);count=r['b']
    keys=scenario['keys']+scenario['interrupt']
    assert [r['a'] for r in latches]==keys
    assert len(events)==len(keys)
    mapping={r['new_key' if meta['modern'] else 'old_key']:i for i,r in enumerate(notes)}
    for k,event in zip(keys,events):
        assert event['a']==mapping.get(k-32 if 97<=k<=122 else k,255),(k,event)
    active=[r for r in play if r['kind']=='active']
    starts=[r for r in active if r['a']==1]
    stops=[r for r in active if r['a']==0]
    assert len(starts)==len(stops)
    assert all(r['a']==(1 if i%2==0 else 0) for i,r in enumerate(active))
    latencies=[]
    for event,latch in zip(events,latches):
        assert 0<=event['t']-latch['t']<.020
        next_start=next((r for r in starts if r['b']==event['b']),None)
        if next_start:latencies.append(next_start['t']-latch['t'])
    for stop in stops[21:]:
        previous=[r for r in play if (r['kind']=='latch' or (release_supported and r['kind']=='release')) and r['t']<=stop['t']]
        assert stop['t']-previous[-1]['t']<.020,('stop latency',stop)
    for a,b in zip(starts[:21],stops[:21]):assert .475<=b['t']-a['t']<=.525
    raw=(path/'screen.bin').read_bytes();assert len(raw)==960
    assert not any(64<=b<128 for b in raw),'flashing glyph'
    for r in notes:
        x=r['column']
        if r['white']:assert raw[15*40+x]<64 and raw[15*40+x+1]<64
        else:assert raw[10*40+x]>=128 and raw[10*40+x+1]>=128
    if not meta['slot']:assert 'mockingboard' not in (path/'machine.txt').read_text(),'card installed in speaker case'
    writes=[r for r in rows if r['kind']=='io-write']
    reads=[r for r in rows if r['kind']=='io-read']
    ay=[];regs=[[0]*16 for _ in range(2)];data=[0,0];select=[0,0]
    if not meta['slot']:
        assert not writes and not reads,'speaker/cancel path accesses card slots'
    else:
        base=0xc000+meta['slot']*256
        yes=[r['t'] for r in rows if r['kind']=='consume' and r['a']==89][0]
        assert writes and all(base<=r['a']<base+256 and r['t']>yes for r in writes)
        assert all(base<=r['a']<base+256 and r['t']>yes for r in reads)
        for r in writes:
            off=r['a']-base;chip=off//128;reg=off%128
            if reg==1:data[chip]=r['b']
            elif reg==0:
                if r['b']==0:regs[chip]=[0]*16
                elif r['b']==7:select[chip]=data[chip]
                elif r['b']==6:
                    idx=select[chip];assert idx<16;regs[chip][idx]=data[chip]
                    ay.append(dict(t=r['t'],chip=chip,reg=idx,value=data[chip]))
                    assert regs[chip][9]==regs[chip][10]==0,'extra AY voices'
                    assert regs[chip][8] in [0,10],'envelope or unexpected volume'
                    if regs[chip][8]:assert chip==0 and regs[chip][7]==62
        assert regs[0][8]==regs[1][8]==0,'unmuted final AY'
    # Actual first speaker transition / AY volume write includes the C dispatch
    # and parameter-copy overhead after the diagnostic active flag.
    sound_latencies=[]
    for start,stop in zip(starts,stops):
        latch=latches[start['b']-1]
        if meta['slot']:
            onset=next(r['t'] for r in ay if r['reg']==8 and r['value']==10 and start['t']<=r['t']<stop['t'])
        else:
            onset=next(r['t'] for r in play if r['kind']=='speaker' and r['b']==start['b'])
        sound_latencies.append(onset-latch['t'])
    assert max(sound_latencies)<.020
    # MAME WAV contains independent routed output channels; measure the audible
    # oscillator, not just the programmed period. Tiny +/-1 mixer dither is ignored.
    with wave.open(str(path/'audio.wav')) as w:
        rate=w.getframerate();channels=w.getnchannels()
        samples=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,channels)
    results=[]
    for i,(start,stop) in enumerate(zip(starts[:21],stops[:21])):
        expected=notes[i]['hz']
        clip=samples[int((start['t']+.06)*rate):int((start['t']+.40)*rate)].astype(float)
        spans=np.ptp(clip,axis=0);channel=int(np.argmax(spans))
        assert spans[channel]>100,'inaudible output'
        assert all(v<4 for c,v in enumerate(spans) if c!=channel),'unintended output channel'
        v=clip[:,channel];v-=v.mean();nfft=131072
        spectrum=np.abs(np.fft.rfft(v*np.hanning(len(v)),n=nfft))
        peak=int(np.argmax(spectrum));freq=peak*rate/nfft
        error=100*(freq/expected-1)
        assert abs(error)<1,(i,expected,freq,error)
        result=dict(note=notes[i]['label'],expected_hz=expected,audio_hz=freq,error_percent=error,duration_ms=1000*(stop['t']-start['t']))
        if not meta['slot']:
            toggles=[r['t'] for r in play if r['kind']=='speaker' and r['b']==i+1]
            if not release_supported:assert len(toggles)==notes[i]['toggles']
            intervals=np.diff(toggles)
            result['toggle_hz']=1/(2*statistics.mean(intervals))
            result['jitter_us']=float(np.ptp(intervals)*1e6)
            assert result['jitter_us']<2
            # MAME's clock differs slightly from the nominal table clock.
            assert abs(result['toggle_hz']/notes[i]['speaker_hz']-1)<.002
        results.append(result)
    # Following every completed note there must be silence until the next latch.
    for stop in stops[:21]:
        quiet=samples[int((stop['t']+.04)*rate):int((stop['t']+.12)*rate)].astype(float)
        assert np.ptp(quiet,axis=0).max()<4,'tone after timeout'
    report=dict(configuration=meta,notes=results,events=len(events),max_start_latency_ms=1000*max(sound_latencies),passed=True)
    (path/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    return report
if __name__=='__main__':
    reports={p.name:analyze(p) for p in sorted((ROOT/'build/verification').iterdir()) if (p/'manifest.json').exists()}
    assert reports,'no captures'
    (ROOT/'build/verification/results.json').write_text(json.dumps(reports,indent=2)+'\n')
    for name,r in reports.items():
        print(f"{name}: PASS {len(r['notes'])} pitches; max pitch error {max(abs(n['error_percent']) for n in r['notes']):.3f}%; input {r['max_start_latency_ms']:.2f} ms")
