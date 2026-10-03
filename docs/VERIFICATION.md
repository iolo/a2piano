# Verification results

Verified 2026-10-03 with cc65 V2.19 Git `a028ac414`, a2kit 4.4.2, and MAME 0.285. These are emulator results, not physical-hardware results.

Release: `a2piano.po`, 143,360 bytes, SHA-256:
`872c2644f4393c6317e2c95f22930b6027f6b715d808b692efb4562eb8917404`.

The executable payload is 4040 bytes at $0803. The disk contains ProDOS 2.4.3, BASIC.SYSTEM 1.7, tokenized STARTUP and the BIN payload; 208 blocks remain free. Payloads, boot blocks, file types, load addresses and the tokenized launcher were extracted and checked after packaging. Two successive packaging runs produced identical bytes.

## Measured acceptance

| Cold-boot configuration | Output | Max pitch error (audio) | Note duration (ms) | Max audible start latency (ms) |
|---|---|---:|---:|---:|
| apple2p | Speaker, no card installed | 0.324% | 498.20–500.31 | 12.40 |
| apple2e | Speaker, no card installed | 0.324% | 498.20–500.31 | 12.47 |
| apple2ee | Speaker, no card installed | 0.324% | 498.20–500.31 | 12.46 |
| apple2ep | Speaker, no card installed | 0.324% | 498.20–500.31 | 12.46 |
| apple2e | Mockingboard slot 4 | 0.538% | 499.75–499.75 | 10.97 |
| apple2p | Mockingboard slot 5 | 0.538% | 499.75–499.75 | 10.93 |

All 21 pitches on every listed configuration passed ±1%; all durations passed 500 ms ±5%; sound replacement passed 20 ms. Speaker transition traces also show constant half-periods across the 16-bit countdown wrap (less than 2 microseconds of measured jitter). Audio FFT measurement is independent of the generated pitch table and includes the actual emulated AY output.

II+ was configured with 48 KB main RAM plus the 16 KB language card. The unenhanced IIe had 64 KB main RAM and an empty auxiliary slot. Enhanced IIe and Platinum IIe provided later-CPU smoke coverage. The enhanced IIe ROM was assembled locally from already installed AppleWin ROM bytes, with both halves matching MAME’s expected SHA-1 values, and passed `-verifyroms`. No ROMs are distributed here.

## Requirement audit

| Requirement | Evidence and outcome |
|---|---|
| Actual disk cold-boots, no launch command | Every runtime case mounts a fresh copy of the final image and waits for the startup prompt. II+, IIe, enhanced IIe, and Platinum IIe passed. |
| 6502 / 64 KB / no auxiliary dependency | All compilation explicitly targets 6502; NMOS II+ executes all keys and both backends. 64 KB IIe with no aux card passes. Linker and page assertions pass. |
| 40×24 inverse/normal display | All 960 screen cells are captured; white/black attributes and absence of flashing are checked. Final screenshots were visually inspected. Uppercase and II+-compatible separators are used. |
| Exactly 21 notes, corrected bindings | Host table checks, actual compiled application event traces, and native MAME keyboard delivery all cover A3–F5. Every special key code matched the plan. |
| Case normalization | Injected lowercase q/w and native keyboard tests reach B3/C4. |
| Input, repeat, monophony | New notes, Space, unassigned Z, repeated Q, and rapid low/high alternation pass. Physical emulated held keys retrigger: II+ Q+REPT generated 31 events in two seconds; IIe/Platinum Q generated 21. After release, output expired. |
| Duration / silence | All pitches on both backends expire. WAV silence windows after timeout pass; every application-controlled return mutes the AY channel. |
| Optional card / no autodetection | Speaker and canceled-card paths run with both card slots empty; no reads or writes to any $C100–$C7FF slot window occur after startup. Card cases touch only their selected slot, after Y confirmation. Invalid 0/8 entries generate no hardware access. |
| No extra voices / envelopes | Captured AY writes maintain R9/R10=0, fixed R8=10 while active, mixer $3E, second AY muted. Independent WAV channels confirm single-output audio. |
| Model default and manual override | Defaults match II+/IIe families; both override directions pass all 21 notes. The unknown-family code returns to the same unconditional O/N choice, defaulting old. Unknown physical clones are untested. |
| Independently bootable speaker build | `make speaker-disk` creates a separate disk without the Mockingboard backend; II+ and IIe boot/mapping/audio tests pass. |
| Diagnostic build | `make diagnostic-disk` boots on II+ and IIe; all 21 event identifiers pass with no speaker transitions. |
| Deterministic packaging and host checks | `make check` passes six host tests plus recatalog/extraction checks. `make clean` followed by the build and complete verification passes. Repeated packaging is byte-identical. |
| Documentation and pinned inputs | README, HARDWARE, third-party notices, input checksums, and this report are included. |

## Evidence files and reproduction

- [Complete measured results](../build/verification/results.json), including each note’s frequency, duration, and speaker jitter.
- [Build and test log](../build/verification/build-and-test.log) and [reproducibility check](../build/reproducibility.txt).
- Each `build/verification/<case>/` contains `command.json`, `manifest.json`, `events.csv`, `audio.wav`, `screen.bin`, `screen.txt`, `screen.png`, `machine.txt`, and `report.json`.
- `keyboard-*` directories hold natural-keyboard mappings and held-key results. `variant-*` directories hold diagnostic/speaker-only results.
- [Linker map](../build/a2piano.map), assembly listings, [catalog](../build/catalog.txt), and [packaging manifest](../build/disk.json).

Run `MAME_ROMPATH=/path/to/roms make verify` to rebuild and reproduce. NumPy is needed only for audio analysis. `make check` requires no emulator or NumPy. The trace injector models a latched event for sub-frame latency measurements; the separate native-keyboard suite verifies keyboard translation and physical emulated repeat. MAME runs unthrottled on the host, but measurements use emulated time and the native machine clocks, not host elapsed time.

## Coverage limits

No physical Apple II/Mockingboard, IIc, IIgs, PAL, accelerated clock, unusual AY clock, NMI-driven peripheral, or arbitrary clone was tested. The program requires normal-speed operation. Apple2TS enhanced-IIe smoke testing was attempted in a private session, but the sandbox could not reach its upload endpoint; the session was stopped, and it is not counted as a pass. Enhanced-IIe coverage instead uses the verified MAME ROM profile.

The plan’s manufacturer-manual review used the Primary Routines reproduced in the locally available Definitive Guide because the web tool did not expose the linked scan’s page images. The register interface was cross-checked against Jeremy Rand’s pinned source and actual MAME sound. ProDOS redistribution terms were reviewed and are documented separately; no public publishing was performed.
