# Verification results

Verified 2026-10-03 with cc65 V2.19 Git `a028ac414`, a2kit 4.4.2, and MAME 0.285. These are emulator results, not physical-hardware results.

Release: `a2piano.po`, 143,360 bytes, SHA-256:
`1843c0c7d3ffbed956c9f230110c8e2a6f1a662d458746469c4438871155df5b`.

The executable payload is 4412 bytes at $0803. The disk contains ProDOS 2.4.3, BASIC.SYSTEM 1.7, tokenized STARTUP and the BIN payload; 207 blocks remain free. Payloads, boot blocks, file types, load addresses and the tokenized launcher were extracted and checked after packaging. Two successive packaging runs produced identical bytes.

## Measured acceptance

| Cold-boot configuration | Output | Max pitch error (audio) | Note behavior | Max audible start latency (ms) |
|---|---|---:|---:|---:|
| apple2p | Speaker, no card installed | 0.324% | 499.47–501.58 ms timeout | 15.54 |
| apple2e | Speaker, no card installed | 0.324% | Hold until release | 12.31 |
| apple2ee | Speaker, no card installed | 0.324% | Hold until release | 12.31 |
| apple2ep | Speaker, no card installed | 0.324% | Hold until release | 12.31 |
| apple2e | Mockingboard slot 4 | 0.538% | Hardware decay; release mutes | 12.35 |
| apple2p | Mockingboard slot 5 | 0.538% | Hardware decay; 501.02 ms timeout | 13.72 |

All 21 pitches on every listed configuration passed ±1%; fallback durations passed 500 ms ±5%; sound replacement passed 20 ms. IIe pitch captures use a simulated half-second key hold, released on an emulator frame boundary; this is no longer a playback timeout. Speaker transition traces show constant half-periods in both modes (less than 2 microseconds of measured jitter), including fallback countdown wraps. Audio FFT measurement is independent of the generated pitch table and includes actual emulated AY output.

Native speaker tests on IIe and Platinum IIe sustain Q for two seconds with exactly one dispatched event, while hardware auto-repeat is consumed without oscillator gaps. Short taps, re-pressing the same key, Q→W overlap, releasing W while Q remains held, Space, and unassigned Z all pass. IIe Mockingboard passes the same input tests and R8 is verified zero after explicit stops. Measured native IIe release latency is 1.49 ms for the speaker and 1.40 ms for Mockingboard (including marker cleanup). Native II+ tests still generate 31 repeat events during a two-second Q+REPT hold and expire after release.

Hardware-envelope audio checks cover every pitch in both Mockingboard profiles:
four successive RMS windows must diminish while pitch stays within tolerance.
A native two-second IIe hold additionally verifies the complete decay and silent
tail. RMS levels at 30, 200, 400, 650, and 850 ms after envelope onset were
3747, 1915, 706, 147, and 44 sample units. The 1.15–1.8 second window has only
one sample unit of peak-to-peak mixer dither. Exactly one R13 write occurs during
the hold, proving auto-repeat does not restart the envelope. A fresh press
restarts the audible attack (RMS 4078). These are captured AY audio measurements,
not just programmed register values. The logical `active` flag stays set during
a silent hold until release, so it no longer means that audio is audible.

II+ was configured with 48 KB main RAM plus the 16 KB language card. The unenhanced IIe had 64 KB main RAM and an empty auxiliary slot. Enhanced IIe and Platinum IIe provided later-CPU smoke coverage. The enhanced IIe ROM was assembled locally from already installed AppleWin ROM bytes, with both halves matching MAME’s expected SHA-1 values, and passed `-verifyroms`. No ROMs are distributed here.

## Requirement audit

| Requirement | Evidence and outcome |
|---|---|
| Actual disk cold-boots, no launch command | Every runtime case mounts a fresh copy of the final image and waits for the startup prompt. II+, IIe, enhanced IIe, and Platinum IIe passed. |
| 6502 / 64 KB / no auxiliary dependency | All compilation explicitly targets 6502; NMOS II+ executes all keys and both backends. 64 KB IIe with no aux card passes. Linker and page assertions pass. |
| 40×24 inverse/normal display | All 960 screen cells are captured; white/black attributes and absence of flashing are checked. Final screenshots were visually inspected. Uppercase and II+-compatible separators are used. |
| Active-key marker | Every runtime note start checks all 960 screen cells against the idle screen plus exactly one star. Every stop checks exact restoration, covering replacement, timeout, release, Space, and unassigned keys. White and black active-key screenshots were visually inspected. Screen writes happen outside the timed audio loops. |
| Exactly 21 notes, corrected bindings | Host table checks, actual compiled application event traces, and native MAME keyboard delivery all cover A3–F5. Every special key code matched the plan. |
| Case normalization | Injected lowercase q/w and native keyboard tests reach B3/C4. |
| Input, repeat, monophony | New notes, Space, unassigned Z, re-pressed Q, and rapid low/high alternation pass. Native IIe holds ignore repeat without interrupting the tone; overlapping keys retain the last note until all keys are released or a different key arrives. A pending-character buffer preserves events across the AKD/strobe-clear race. |
| Duration / silence | II+ pitches on both backends expire. IIe speaker holds exceed the old timeout; Mockingboard fades to silence during a hold. Release still stops either output immediately. WAV silence windows after stops pass; every application-controlled return mutes the AY channel. |
| Optional card / no autodetection | Speaker and canceled-card paths run with both card slots empty; no reads or writes to any $C100–$C7FF slot window occur after startup. Card cases touch only their selected slot, after Y confirmation. Invalid 0/8 entries generate no hardware access. |
| Single voice / hardware decay | Captured AY writes maintain R9/R10=0, R8=$10 while logically active, mixer $3E, and second AY muted. R11/R12 set period 3995 and exactly one R13=0 write restarts each note. WAV measurements verify diminishing amplitude, silent tail, and audible restart. |
| Model default and manual override | Defaults match II+/IIe families; both override directions pass all 21 notes. AKD capability follows the machine, independently of O/N layout. The unknown-family code defaults to old layout and timed notes. Unknown physical clones are untested. |
| Independently bootable speaker build | `make speaker-disk` creates a separate disk without the Mockingboard backend; II+ and IIe boot/mapping/audio tests pass. |
| Diagnostic build | `make diagnostic-disk` boots on II+ and IIe; all 21 event identifiers pass with no speaker transitions. |
| Deterministic packaging and host checks | `make verify` passes six host tests, recatalog/extraction checks, all runtime/audio cases, native input tests on both backends, and both variant disks. Repeated packaging is byte-identical. |
| Documentation and pinned inputs | README, HARDWARE, third-party notices, input checksums, and this report are included. |

## Evidence files and reproduction

- [Complete measured results](../build/verification/results.json), including each note’s frequency, duration, and speaker jitter.
- [Build and test log](../build/verification/build-and-test.log) and [reproducibility check](../build/reproducibility.txt).
- Each `build/verification/<case>/` contains `command.json`, `manifest.json`, `events.csv`, `audio.wav`, `screen.bin`, `screen.txt`, `screen.png`, `active-white.png`, `active-black.png`, `machine.txt`, and `report.json`.
- `keyboard-*` directories hold natural-keyboard mappings and held-key results. `variant-*` directories hold diagnostic/speaker-only results.
- [Decay measurements](../build/verification/keyboard-mb-slot4/decay-result.json) and
  [Mockingboard decay audio sample](../build/verification/mockingboard-decay.wav),
  cropped from the native two-second B3 hold without volume normalization.
- [Linker map](../build/a2piano.map), assembly listings, [catalog](../build/catalog.txt), and [packaging manifest](../build/disk.json).

Run `MAME_ROMPATH=/path/to/roms make verify` to rebuild and reproduce. NumPy is needed only for audio analysis. `make check` requires no emulator or NumPy. The trace injector models a latched event and AKD hold/release state; the separate native-keyboard suite verifies keyboard translation, physical emulated repeat, short taps, overlapping keys, and release latency. MAME runs unthrottled on the host, but measurements use emulated time and the native machine clocks, not host elapsed time.

## Coverage limits

No physical Apple II/Mockingboard, IIc, IIgs, PAL, accelerated clock, unusual AY clock, NMI-driven peripheral, or arbitrary clone was tested. The program requires normal-speed operation. Apple2TS enhanced-IIe smoke testing was attempted in a private session, but the sandbox could not reach its upload endpoint; the session was stopped, and it is not counted as a pass. Enhanced-IIe coverage instead uses the verified MAME ROM profile.

The plan’s manufacturer-manual review used the Primary Routines reproduced in the locally available Definitive Guide because the web tool did not expose the linked scan’s page images. The register interface was cross-checked against Jeremy Rand’s pinned source and actual MAME sound. ProDOS redistribution terms were reviewed and are documented separately; no public publishing was performed.
