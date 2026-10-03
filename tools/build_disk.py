#!/usr/bin/env python3
"""Build a bootable ProDOS-order disk, verifying every imported byte."""
import argparse, hashlib, json, os, struct, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
A2KIT = os.environ.get('A2KIT', 'a2kit')
def a2(*args, data=None):
    return subprocess.run([A2KIT, *map(str,args)],input=data,stdout=subprocess.PIPE,check=True).stdout

def apple_single(data):
    assert struct.unpack_from('>II',data)==(0x51600,0x20000)
    entries={}
    for i in range(struct.unpack_from('>H',data,24)[0]):
        kind,offset,length=struct.unpack_from('>III',data,26+i*12)
        assert offset+length<=len(data)
        entries[kind]=data[offset:offset+length]
    access,kind,addr=struct.unpack('>HHI',entries[11])
    assert kind==6 and addr==0x803
    return entries[1],addr

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary',type=Path,default=Path('build/a2piano.as'))
    parser.add_argument('--output',type=Path,default=Path('a2piano.po'))
    parser.add_argument('--report-dir',type=Path,default=Path('build'))
    args=parser.parse_args()
    args.report_dir.mkdir(parents=True,exist_ok=True)
    assets=Path('assets/prodos')
    pins=json.loads((assets/'SHA256.json').read_text())
    for name,digest in pins.items():
        assert hashlib.sha256((assets/name).read_bytes()).hexdigest()==digest,name
    disk=args.report_dir/'packaging.po'
    disk.unlink(missing_ok=True)
    a2('mkdsk','-t','po','-o','prodos','-v','A2PIANO','-d',disk)
    a2('put','-t','block','-f','0..2','-d',disk,data=(assets/'boot.bin').read_bytes())
    for name in ['PRODOS','BASIC.SYSTEM']:
        a2('put','-t','any','-f',name,'-d',disk,data=(assets/(name+'.json')).read_bytes())
    startup=a2('tokenize','-t','atxt','-a','2049',data=b'10 PRINT CHR$(4);"BRUN A2PIANO"\n')
    a2('put','-t','atok','-f','STARTUP','-a','2049','-d',disk,data=startup)
    payload,addr=apple_single(args.binary.read_bytes())
    (args.report_dir/'a2piano.bin').write_bytes(payload)
    a2('put','-t','bin','-f','A2PIANO','-a',addr,'-d',disk,data=payload)
    # Canonical no-date directory metadata: a2kit timestamps new entries with
    # host time. ProDOS directory entries are 39 bytes, creation at +24 and
    # last modification at +33; volume header only has creation. This disk's
    # four files fit block 2. Use a2kit block I/O to retain ProDOS ordering.
    directory=bytearray(a2('get','-t','block','-f','2','-d',disk))
    assert directory[4]>>4==15 and directory[35]==39
    assert int.from_bytes(directory[37:39],'little')==4
    for entry in range(5):
        offset=4+39*entry
        directory[offset+24:offset+28]=bytes(4)
        if entry:directory[offset+33:offset+37]=bytes(4)
    a2('put','-t','block','-f','2','-d',disk,data=bytes(directory))
    expected={'PRODOS':(255,0),'BASIC.SYSTEM':(255,0),'STARTUP':(252,2049),'A2PIANO':(6,addr)}
    for name,(kind,load) in expected.items():
        meta=json.loads(a2('get','-t','any','-f',name,'-d',disk))
        assert int(meta['fs_type'],16)==kind
        assert int.from_bytes(bytes.fromhex(meta['aux']),'little')==load
        if name in ['PRODOS','BASIC.SYSTEM']:
            assert meta['chunks']==json.loads((assets/(name+'.json')).read_text())['chunks']
    assert a2('get','-t','bin','-f','A2PIANO','-d',disk)==payload
    assert a2('get','-t','atok','-f','STARTUP','-d',disk)==startup
    assert a2('get','-t','block','-f','0..2','-d',disk)==(assets/'boot.bin').read_bytes()
    catalog=a2('catalog','-d',disk).decode()
    (args.report_dir/'catalog.txt').write_text(catalog)
    (args.report_dir/'disk.json').write_text(json.dumps({'sha256':hashlib.sha256(disk.read_bytes()).hexdigest(),'bytes':len(disk.read_bytes()),'load':addr,'payload_bytes':len(payload),'files':expected},indent=2)+'\n')
    assert len(disk.read_bytes())==143360
    args.output.write_bytes(disk.read_bytes())
    disk.unlink()
    print(catalog)
if __name__=='__main__': main()
