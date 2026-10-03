import importlib.util, json, re, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('notes',ROOT/'tools/generate_notes.py')
gen=importlib.util.module_from_spec(spec);spec.loader.exec_module(gen)

class Notes(unittest.TestCase):
    def test_range(self):
        rows=gen.rows()
        self.assertEqual(len(rows),21)
        self.assertEqual([r['label'] for r in rows], 'A3 A#3 B3 C4 C#4 D4 D#4 E4 F4 F#4 G4 G#4 A4 A#4 B4 C5 C#5 D5 D#5 E5 F5'.split())
        self.assertEqual(sum(r['white'] for r in rows),13)
        self.assertEqual(rows[12]['hz'],440)
    def test_mapping(self):
        rows=gen.rows()
        for field in ['old_key','new_key']:
            keys=[r[field] for r in rows]
            self.assertEqual(len(set(keys)),21)
            self.assertNotIn(32,keys)
        self.assertEqual([rows[i]['old_key'] for i in [0,16,18,19,20]],[27,58,45,8,21])
        self.assertEqual([rows[i]['new_key'] for i in [0,16,18,19,20]],[9,45,61,91,93])
    def test_timing(self):
        for r in gen.rows():
            self.assertLess(abs(r['speaker_hz']/r['hz']-1),.01)
            self.assertLess(abs(r['ay_hz']/r['hz']-1),.01)
            self.assertTrue(.475 <= r['toggles']*r['half_cycles']/gen.CPU_HZ <= .5)
            self.assertTrue(1<=r['ay_period']<=4095)
            self.assertTrue(0<=r['delay_outer']<=1 and 1<=r['delay_inner']<=255)
    def test_generation(self):
        self.assertEqual(json.loads((ROOT/'build/notes.json').read_text())['notes'],gen.rows())
    def test_memory_and_pages(self):
        labels={n:int(a,16) for a,n in re.findall(r'al ([0-9A-Fa-f]+) \.([\w_]+)',(ROOT/'build/a2piano.lbl').read_text())}
        self.assertEqual(labels['speaker_loop']//256,labels['speaker_end']//256)
        self.assertEqual(labels['__LC_LAST__'],0xd400) # no code behind ROM
        self.assertLess(labels['__MAIN_LAST__'],0x8e00)
        self.assertLess(labels['__BSS_RUN__']+labels['__BSS_SIZE__'],0x8e00)
        self.assertEqual(labels['__HIMEM__'],0x9600)
    def test_display_bounds(self):
        for r in gen.rows():
            self.assertLess(r['column']+(2 if r['white'] else 1),40)
            self.assertGreaterEqual(r['column'],0)
