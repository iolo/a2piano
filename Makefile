CL65 ?= cl65
CA65 ?= ca65
PYTHON ?= python3
CFLAGS = -t apple2 --cpu 6502 -O -I src
SOURCES = src/main.c src/keyboard.c src/screen.c
OBJECTS = $(patsubst src/%.c,build/%.o,$(SOURCES)) build/platform.o build/notes.o build/speaker.o build/mockingboard.o
.PHONY: all disk check clean verify diagnostic-disk speaker-disk
all: disk
build:
	mkdir -p build
build/%.o: src/%.c src/piano.h src/notes.h | build
	$(CL65) $(CFLAGS) -c -o $@ $<
build/notes.c build/notes.json build/timing.inc &: tools/generate_notes.py | build
	$(PYTHON) tools/generate_notes.py
build/notes.o: build/notes.c src/notes.h
	$(CL65) $(CFLAGS) -c -o $@ $<
build/mockingboard.o: build/timing.inc
build/%.o: src/%.s | build
	$(CA65) -t apple2 --cpu 6502 -I build -l build/$*.lst -o $@ $<
build/a2piano.as: $(OBJECTS) src/apple2.cfg
	$(CL65) -t apple2 --cpu 6502 -C src/apple2.cfg -m build/a2piano.map -Ln build/a2piano.lbl -o $@ $(OBJECTS)
disk: build/a2piano.as
	$(PYTHON) tools/build_disk.py
check: disk
	$(PYTHON) -m unittest discover -s tests -v
clean:
	rm -rf build a2piano.po

verify: check diagnostic-disk speaker-disk
	$(PYTHON) tools/verify_emulator.py
	$(PYTHON) tools/analyze_capture.py
	$(PYTHON) tools/verify_keyboard.py
	$(PYTHON) tools/verify_variants.py
build/main-diagnostic.o: src/main.c src/piano.h src/notes.h | build
	$(CL65) $(CFLAGS) -D DIAGNOSTIC -c -o $@ $<
build/main-speaker.o: src/main.c src/piano.h src/notes.h | build
	$(CL65) $(CFLAGS) -D SPEAKER_ONLY -c -o $@ $<
build/diagnostic.as: build/main-diagnostic.o $(filter-out build/main.o,$(OBJECTS)) src/apple2.cfg
	$(CL65) -t apple2 --cpu 6502 -C src/apple2.cfg -m build/diagnostic.map -Ln build/diagnostic.lbl -o $@ $(filter %.o,$^)
build/speaker.as: build/main-speaker.o $(filter-out build/main.o build/mockingboard.o,$(OBJECTS)) src/apple2.cfg
	$(CL65) -t apple2 --cpu 6502 -C src/apple2.cfg -m build/speaker.map -Ln build/speaker.lbl -o $@ $(filter %.o,$^)
diagnostic-disk: build/diagnostic.as
	$(PYTHON) tools/build_disk.py --binary $< --output build/diagnostic.po --report-dir build/diagnostic
speaker-disk: build/speaker.as
	$(PYTHON) tools/build_disk.py --binary $< --output build/speaker-only.po --report-dir build/speaker-only
