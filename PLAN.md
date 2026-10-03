# a2piano implementation plan

## Goal and scope

Implement `PRD.md` and deliver `a2piano.po`: a bootable ProDOS disk image that starts a monophonic piano program on an Apple II+ with 64 KB RAM or a later compatible machine/emulator.

Use cc65, C, 6502 assembly, Make, a2kit, and ProDOS 2.4.3. Display the piano in 40×24 text mode. Default to the internal speaker; offer optional Mockingboard output with a manually entered slot. Exclude chords, sustain, velocity, recording, and other advanced features.

The repository currently contains only `PRD.md`. This plan covers implementation from an empty project through a verified disk image; it does not imply that any software or hardware tests have already passed.

## Requirements to reconcile

Use the following confirmed decisions and explicit planning assumptions. Keep these decisions visible in implementation documentation rather than silently carrying the diagram errors into code.

| PRD ambiguity | Proposed implementation decision |
| --- | --- |
| A3–F5 is almost two octaves. | Confirmed by the user: the range is intentionally limited to fit the 40-column screen. Keep A3–F5 inclusive: 21 chromatic notes, comprising 13 white and 8 black keys, spanning 20 semitones. Do not expand to two full octaves. |
| White-key diagram labels include A5/B5 before C5. | Correct those labels to A4/B4. |
| Black-key labels and positions do not match the white keys. | Draw black keys only at A#3, C#4, D#4, F#4, G#4, A#4, C#5, and D#5. Redraw their placement accordingly. |
| A quarter note has no stated tempo. | Use a fixed 120 BPM equivalent: each note lasts at most 500 ms. Keep the duration in one build-time constant; do not add a tempo UI. |
| “Until another key is pressed” does not specify unassigned keys. | Any new key event ends the current note. A mapped note key immediately starts its note; Space or an unassigned key leaves silence. |
| Older keyboard support mentions machines before the II+. | Support the older keyboard layout on the specified II+ minimum. Original Apple II compatibility is outside the required release scope. |
| Later machines and emulators may run faster. | Establish accurate playback at normal Apple II speed first. Use compatible normal-speed operation on accelerated machines/emulators; document unsupported speed configurations. |
| Mockingboard “or clone” covers differing implementations. | Target a conventional Mockingboard-compatible VIA/AY register interface first. Name the tested card/emulator configuration; do not claim support for every clone. |

Proposed key mapping, preserving the PRD's white-key sequence and as many black-key bindings as possible:

| Notes in ascending order | IIe and later keys | II+ keys |
| --- | --- | --- |
| A3 B3 C4 D4 E4 F4 G4 A4 B4 C5 D5 E5 F5 | Tab Q W E R T Y U I O P [ ] | Esc Q W E R T Y U I O P Left Right |
| A#3 C#4 D#4 F#4 G#4 A#4 C#5 D#5 | 1 4 5 7 8 9 - = | 1 4 5 7 8 9 : - |

The diagram's `2` binding is omitted because the corrected range has only eight black keys. Normalize alphabetic case on later keyboards. Treat repeated key events as retriggers; do not attempt to infer key release. Verify the actual character codes for Tab, Esc, arrows, brackets, colon, minus, and equals on each keyboard profile.

## Architecture

- **C application layer:** startup choices, model/layout selection, note lookup, and static screen drawing. Use fixed-size data and modest stack/RAM usage.
- **6502 platform layer:** keyboard latch handling, speaker playback, and timing-sensitive Mockingboard access. Compile for the original 6502 instruction set so the II+ remains supported.
- **One note table:** note identifiers, display labels, key bindings, speaker timing parameters, and AY periods. Generate pitch values at build time using equal temperament with A4 = 440 Hz; avoid floating-point work on the Apple II.
- **Shared playback contract:** idle → note starts → note stops on timeout or input. Both backends implement the same duration and interruption rules. Never permit simultaneous notes.
- **Timing ownership:** use a cycle-counted assembly loop for the speaker, with bounded keyboard polling included in its cycle budget. Account for branch paths and page crossings. Do no C rendering or disk I/O while producing a speaker tone. For Mockingboard, use a verified polling/timer approach that maintains duration while checking input; an interrupt-driven system is unnecessary for the initial scope.
- **Text display:** draw static content once on text page 1. Render white keys in inverse and black keys in normal text. Use uppercase, II+-compatible glyphs and explicit row addressing. Keep all content within 40 columns and 24 rows. Defer optional live-note highlighting unless it can preserve timing; it is not required by the PRD.
- **Hardware boundaries:** document zero-page ownership, register clobbers, interrupt-state handling, and C/assembly calling conventions. Silence output on timeout and application-controlled transitions. Do not depend on IIe-only video or timing facilities for the common path.

Suggested source layout:

```text
Makefile
src/main.c                 Startup and application state
src/keyboard.c             Layout tables and input translation
src/screen.c               Piano drawing and startup prompts
src/notes.h                Shared note definitions
src/platform.s             Model identification and keyboard access
src/speaker.s              Cycle-counted speaker playback
src/mockingboard.s         Slot-specific VIA/AY access and playback
tools/generate_notes.py    Build-time pitch/timing tables
tools/build_disk.sh        a2kit packaging and verification
assets/prodos/             Pinned boot inputs and provenance
tests/                    Note-map and hardware verification fixtures
build/                    Intermediate binaries, maps, reports
a2piano.po                Final release image
README.md                 Build, boot, controls, and tested configurations
```

## Milestones

### 1. Prove the toolchain and boot path

1. Inspect installed cc65 and a2kit versions and record the working commands. Pin ProDOS 2.4.3 boot inputs with source and checksum; check redistribution terms before bundling them.
2. Build a minimal C/assembly program for the `apple2` target, explicitly using a 6502-compatible CPU setting. Produce a linker map and verify runtime, stack, and memory placement against a 64 KB II+ configuration with a language card.
3. Choose the simplest supported startup chain. Start with ProDOS → BASIC.SYSTEM → a tokenized `STARTUP` launcher → the piano BIN program, using a2kit to package/tokenize as necessary. Verify filenames, file types, load address, and startup behavior.
4. Create a 140 KB ProDOS-order `.po` image with actual boot blocks and required system files. Import cc65 AppleSingle output by its data fork and metadata; do not load an AppleSingle header as machine code.
5. Cold-boot the image on II+ and IIe emulator profiles and reach a recognizable test screen without typing a launch command.

**Exit criterion:** a repeatable build produces a disk that automatically launches the minimal program on both minimum target profiles. Resolve boot/runtime issues before adding audio.

### 2. Implement model detection, keyboard input, and display

1. Implement model-family identification following the PRD-linked Apple technical note. Only distinguish the families needed for keyboard defaults; provide an old/new layout choice at startup for clones or unusual keyboards.
2. Add a startup output prompt with internal speaker selected by default. Only request a slot when Mockingboard is selected. Validate slot input before deriving any hardware addresses; never probe slots for a card.
3. Implement the corrected note map and keyboard strobe handling. Consume each event once and normalize letter case. Keep Space dedicated to silence; avoid using Esc as a global exit because it plays A3 in the old layout.
4. Draw the complete piano, note labels, selected output/layout, and a short Space-to-stop hint within 40×24. Use simple text characters for borders, including textual arrow-key legends if needed.
5. Check all 21 notes and all special keys in both layouts using a diagnostic build before connecting sound.

**Exit criterion:** the screen fits and has the required attributes, and every mapped key produces the intended note identifier on II+ and IIe profiles.

### 3. Implement internal-speaker playback

1. Generate half-period parameters for all notes using the selected normal-speed CPU clock. Include loop, keyboard-poll, and duration-counter costs in the timing calculation.
2. Implement immediate note start, 500 ms maximum duration, interruption, Space-to-stop, and repeat retriggering. Keep the input polling cadence fast enough to meet the responsiveness target below.
3. Audit the hot loop's cycle counts and page placement using the assembler listing/linker map. Account for interrupt interference and restore any processor state changed by playback.
4. Measure output across the note range from emulator audio or speaker-toggle timestamps, especially A3, A4, and F5. Exercise rapid alternation and stop requests during playback.

**Exit criterion:** all notes are audible at the intended pitches, stop automatically, and respond to new input without stuck tones or material timing jitter.

### 4. Implement Mockingboard playback

1. Review the Mockingboard programming references below before coding register access: use the original Sweet Micro Systems manual as the hardware authority, Rubywand's Mini-manual as a concise programming guide, and Jeremy Rand's `a2bejwld` as a working code reference. Cross-check VIA/AY initialization, register selection/write sequencing, mixer bits, and tone-period calculations against the original documentation and the selected card/emulator. Adapt examples to the manually selected slot; retain the PRD's no-autodetection requirement.
2. Derive register addresses only from the explicitly selected slot. Explain in the prompt/help that the user must select a slot containing a compatible card. Include a cancel path before initialization; no autodetection or probing.
3. Initialize one AY tone channel with fixed volume, disable noise/envelopes and other channels used by this implementation, and generate the corresponding pitch-period table for the verified AY clock.
4. Implement the same input, duration, retrigger, and silence semantics as the speaker backend. Mute the channel on all application-controlled stop paths.
5. Verify with a supported emulator/card in at least two valid slot configurations. Check that speaker mode works with no Mockingboard installed and performs no Mockingboard initialization.

**Exit criterion:** manually selected Mockingboard playback passes the same note and input checks as the speaker, without slot autodetection or unintended extra voices.

### 5. Package and verify the release

1. Provide `make`, `make disk`, `make check`, and `make clean` targets with documented prerequisites. `make disk` must produce `a2piano.po` from pinned inputs without manual disk editing.
2. Re-catalog the output image; verify file types, load metadata, available space, and extracted executable bytes against the build output.
3. Cold-boot the final image, not just a raw binary. Run the acceptance matrix below and save configuration details, screenshots, and timing/audio evidence under `build/`.
4. Write concise build and usage documentation, including startup choices, corrected note mapping, duration, key-repeat behavior, normal-speed requirements, and tested Mockingboard configuration.
5. Deliver `a2piano.po`, source/build scripts, and verification results. Record any untested hardware separately from configurations that passed.

**Exit criterion:** the final image satisfies the acceptance checks and can be rebuilt and booted using the documented process.

## Acceptance and verification

The numeric tolerances below are proposed engineering targets, not additional PRD requirements.

| Area | Required check |
| --- | --- |
| Boot | Final disk automatically launches on a 64 KB II+ and a IIe. Smoke-test enhanced IIe and available later-family profiles; document coverage. |
| CPU/RAM | No 65C02-only instructions or auxiliary-RAM requirement in the common program. Linker/runtime layout fits the minimum machine. |
| Display | All content stays inside 40×24; white keys are inverse, black keys normal; no unintended flashing or lowercase dependency. |
| Mapping | Exactly 21 reachable notes from A3 through F5, without gaps or duplicate key bindings within a layout. Check all special keys and letter-case normalization. |
| Pitch | Measure all notes on both backends. Target ±1% at the documented normal clock; record deviations caused by timing quantization or clock differences. |
| Duration | With no further input, stop after 500 ms, targeting ±5% on both backends. Test low and high notes to catch pitch-dependent duration errors. |
| Input | Target sound replacement/stop within 20 ms of a latched event. Test new notes, Space, unassigned keys, held-key repeat, and rapid alternation. |
| Monophony | A new note replaces the old one; Mockingboard does not leave other channels sounding. |
| Output selection | Default speaker succeeds without a sound card. Mockingboard requires explicit slot selection; invalid slot input is rejected before hardware access. |
| Layout compatibility | Default layout follows detected family; manual override works; unknown clones can select either layout. |
| Packaging | Image uses ProDOS sector order and contains verified boot/system/startup files plus the correct executable payload and metadata. |

Automate deterministic checks for note-table coverage, duplicate bindings, generated pitch error, and disk contents. Use emulator interaction and timing/audio captures for behavior that host-side tests cannot prove. Real-hardware testing is desirable when available; emulator results alone must not be reported as physical-hardware validation.

## Main risks and sequencing

- **Keyboard mapping:** the A3–F5 range is confirmed. Settle the proposed key mapping in milestone 2 before tuning sound or finalizing the drawing.
- **Speaker timing versus responsiveness:** build and measure the cycle-counted loop early. Reduce runtime work in the loop if pitch or input latency misses its target.
- **Boot compatibility:** prove the actual ProDOS 2.4.3 startup chain on a 6502 II+ first; a valid filesystem or a directly loaded binary is insufficient evidence.
- **Card variation:** verify the intended Mockingboard interface before implementation and limit compatibility claims to tested variants.
- **Clock variation:** record CPU/AY clock assumptions and emulator speed settings. Treat PAL/accelerated configurations as separate validation cases before claiming accurate pitch there.

Implement milestones in order. Keep an independently bootable speaker-only build while adding Mockingboard support so hardware-specific debugging does not obscure the minimum configuration.

## References

- [PRD.md](PRD.md) — requested scope and original keyboard sketch.
- [Apple II Miscellaneous Technical Note #7](https://prodos8.com/docs/technote/misc/07/) — ROM identification procedure; use the documented ROM-bank prerequisites when implementing detection.
- [cc65 Apple II target documentation](https://cc65.github.io/doc/apple2.html) — implementation reference for runtime, executable format, and startup details.
- [a2kit documentation](https://github.com/dfgordon/a2kit) — implementation reference for image creation, import/export, and tokenization; confirm syntax against the installed version.

### Mockingboard programming

- [Jeremy Rand's a2bejwld](https://github.com/jeremysrand/a2bejwld) — working Apple II C/assembly project. Start with [`mockingboard.c`](https://github.com/jeremysrand/a2bejwld/blob/master/a2bejwld/mockingboard.c), [`mockingboard.h`](https://github.com/jeremysrand/a2bejwld/blob/master/a2bejwld/mockingboard.h), and [`sound.c`](https://github.com/jeremysrand/a2bejwld/blob/master/a2bejwld/sound.c) for slot-address mapping, initialization, register writes, and sound integration. Use the sound routines as implementation references without importing card detection or speech features. Record the reviewed commit and retain the project's MIT license notice if reusing code.
- [Apple II MockingBoard Mini-manual, by Rubywand](https://gswv.apple2.org.za/a2zine/Docs/Mockingboard_MiniManual.html) — concise guide to sound registers, VIA access, initialization, and assembly write/reset sequences. Its examples use slot 4; parameterize addresses for the user's selected slot and cross-check register bit assignments against the original documentation.
- [Original Sweet Micro Systems Mockingboard manual (PDF scan)](https://www.classic-computing.de/wp-content/uploads/2023/06/Apple2_Mockingboard_Manual.pdf) — original manufacturer documentation, preserved by the Verein zum Erhalt klassischer Computer ([archive page](https://www.classic-computing.de/mockingboard-doku/)). Use as the primary manual when verifying hardware behavior and programming details; the linked copy is hosted by an archive, not the original manufacturer.
