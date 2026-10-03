# Implementation and hardware contract

## Model, memory, and calling convention

`cl65 -t apple2 --cpu 6502` uses the standard Apple II runtime. The custom linker
configuration adds a page-aligned TIMING segment and otherwise keeps the cc65
layout. The ProDOS BIN loads at $0803; AppleSingle headers are parsed by entry
identifier and excluded from the payload. BASIC.SYSTEM sets HIMEM; the linker
ceiling is $9600 with a $0800 software-stack reservation. There is no heap use,
auxiliary-RAM use, recursive C code, or application code in the language card.
The linker map and host tests check these placements on each build.

cc65 owns zero page $80-$99. Assembly does not allocate extra zero page. The
Mockingboard routines temporarily use cc65 `ptr1`, do not call C, and return
before C uses it again. All assembly entry points may clobber A/X/Y and
arithmetic flags. Fastcall slot/layout arguments arrive in A; keyboard/model
byte results return in A with X=0. Playback uses `PHP/SEI/.../PLP` so the caller's
interrupt state is restored. Speaker playback also clears decimal mode within
that protected interval. Timing assumes no nonmaskable interrupt source.

`detect_layout` follows [Apple Miscellaneous TN #7](https://prodos8.com/docs/technote/misc/07/).
It exposes ROM with $C082, performs the $FE1F carry test and ROM ID tests, then
restores cc65's readable language-card bank 2 with $C080. The supported entry
path is a cold ProDOS/BASIC.SYSTEM launch, with main ROM selected (including
normal IIgs ROM-bank state). Calling the binary from an arbitrary monitor with
alternate ROM/auxiliary banks selected is not supported. Only the keyboard
family is needed: II+ is old, IIe/IIc/IIgs is new, unknown defaults old with an
explicit choice. Original Apple II / Integer BASIC is outside release scope.

The keyboard latch is read at $C000, acknowledged through $C010, and masked
to seven bits. Alphabetic case normalizes in C. Detection also sets
`release_supported` for IIe/IIc ROM IDs; the IIgs carry-test path and unknown
machines leave it disabled. Choosing a different O/N layout cannot change
this hardware capability.

On IIe/IIc, bit 7 of $C010 (AKD) stops a note when no ordinary key is held.
The dispatcher saves AKD while acknowledging an event and skips already
released notes. Playback compares the raw $C000 character against `held_key`
before reading $C010, discarding same-code repeats without restarting sound.
A different character is saved in `pending_key` for the dispatcher: this also
preserves a new event whose strobe was cleared by an AKD read between polls.
There is no 500 ms timeout in this mode. Mockingboard's envelope can reach
silence while the key remains logically active, preventing auto-repeat from
restarting a decayed note. AKD excludes modifiers and Apple keys; overlapping
keys retain the last note until all ordinary keys are up.
Individual releases and a return to an earlier held note cannot be inferred.

II+ and other fallback machines retain the timed loop, returning with a new
strobe pending. Space and unassigned events stop sound in both modes. Esc is
a note in old layout.
`last_key`, `last_note`, `event_count`, `ready`, and `active` are diagnostic
symbols; their addresses are in the linker label file. They require no screen
updates during audio.

## Speaker timing

The nominal NTSC effective CPU clock is 1,020,484 Hz. The table generator uses
A4=440 Hz and equal temperament. Every half-cycle has exactly:

```
51 + 1284 * delay_outer + 5 * delay_inner cycles
```

`delay_outer` is 0 or 1 and `delay_inner` is 1..255. The fixed 51 cycles include
the speaker access, keyboard poll, balanced 16-bit decrement, and loop control.
The separate AKD loop replaces the countdown with character comparison,
release polling, and padding for exactly the same interval. Both loops' branches
remain on one page, enforced by link-time assertions. The outer
path adds 1284 cycles, including its alternate branch cost. Low-byte countdown
wrap has no variable branch. Interrupts are masked during the note, and no C,
ROM, disk, or screen work occurs in the loop. A new latch is tested every
half-period, at most about 2.28 ms apart. Returning without further $C030
accesses is the speaker's silent state.

`DURATION_MS` in `tools/generate_notes.py` is the single duration control,
default 500 ms for fallback machines (one quarter note at 120 BPM). The half-cycle count is rounded
down so nominal playback does not exceed the limit. Timing quantization and
emulator clocks are reported by the runtime measurements, not inferred solely
from the formula. Bus captures validate every note and include countdown wraps.

## Mockingboard

The target is the conventional two-VIA/two-AY Mockingboard register interface,
verified using MAME 0.285 `mockingboard` in slots 4 and 5. Speaker mode never
initializes, probes, reads, or writes these slot interfaces. The user chooses a
slot 1..7 and confirms before any hardware access. Assembly validates the
range again. Other clones and nonstandard clocking are unverified.

The first VIA is at $Cn00 and the second at $Cn80. DDRA=$FF, DDRB=$07. Port A
carries register/data bytes; port B transitions 7→4 to latch, 6→4 to write, and
0→4 to reset. Both AY chips reset silent. Only first-chip channel A is enabled:
R7=$3E, R8=$10, R9=R10=0; the second chip remains silent. Channel A uses the
hardware envelope via volume bit 4. Noise is disabled. The tone is `AY clock/(16*period)`
with a 12-bit period and the documented nominal 1,022,727 Hz AY clock.

The first VIA's T1 runs continuously in 10 approximately 50 ms periods. Its
interrupt enable bits remain off; timed playback polls IFR and the keyboard,
acknowledging T1 by reading its low counter. AKD playback instead polls the
keyboard until a different character or release, ignoring timer expiry.
Stop paths set R8=0 before returning
and leave continuous timer mode. Pitch bytes are replaced while muted. No C
rendering runs during playback. The application owns these VIA settings until
machine reset; it does not promise to preserve another program's card state.

### Volume decay: hardware versus software

| Approach | Implementation | Constraints |
|---|---|---|
| AY hardware envelope (selected) | Program a period and falling shape at note onset, then let the chip change amplitude. | One shared envelope per AY; 16 volume steps and fixed shapes; a falling envelope starts at maximum amplitude. |
| Software volume decay | Use the VIA timer to write successive fixed levels to R8. | Requires periodic writes and decay state, but permits a custom curve, starting volume, and independent channel envelopes. |

The hardware envelope is simpler for the current monophonic player. Its shared
generator imposes no voice conflict here, and no volume-update loop is needed.
This is a falling amplitude envelope, not a full ADSR synthesizer or sampled piano.

Register names in General Instrument's manual use **octal**: amplitude R10–R12
are decimal 8–10, and envelope R13–R15 are decimal 11–13. Code throughout this
project uses decimal register indices. Decimal 14/15 are I/O ports, not envelope
registers. On each note, while channel A is muted, the player writes:

- R11/R12: fine/coarse envelope period, generated from `ENVELOPE_MS`.
- R13=0: falling shape, 15 down to 0, then hold silence. Writing it retriggers
  the envelope even when its value is unchanged.
- R8=$10: enable envelope amplitude on channel A.

`ENVELOPE_MS=1000` in `tools/generate_notes.py` produces period 3995 ($0F9B)
at the nominal 1,022,727 Hz AY clock. The 16-step envelope cycle is
`256 * period / AY_HZ`; adjacent steps are `16 * period / AY_HZ` apart.
Shape 0 reaches zero after 15 steps, about 0.938 seconds, and stays there.
The hardware's logarithmic amplitude levels make the falling sequence sound
like a decay rather than a linear fade. Peak amplitude is 15, higher than the
previous fixed level 10; hardware envelope mode cannot independently scale it.

Same-code //e auto-repeat does not rewrite R13. A new note or a re-press after
release starts a fresh decay. All stop paths still write R8=0 immediately;
there is no release tail. II+ retains its 500 ms cap and repeat retriggering.
The internal speaker backend has no volume-decay change.

## Reviewed references

- [General Instrument AY-3-8910/8912 data manual](https://pub.intvprime.com/ba4ef/ie/Programming/AY-3-8910-8912-Programmable-Sound-Generator-Data-Manual.pdf),
  amplitude control and envelope shape/period sections. Its register names use octal.
- [MAME 0.285 AY implementation](https://github.com/mamedev/mame/blob/mame0285/src/devices/sound/ay8910.cpp),
  16-step AY envelope, period timing, and shape-register retrigger behavior;
  timing is additionally checked against captured audio rather than relying
  on ambiguous divider wording in historical descriptions.
- [Apple IIe Reference Manual](https://www.applelogic.org/files/AIIEREF.pdf),
  keyboard section: $C010 AKD and its strobe-clearing side effect.
- [cc65 Apple II runtime](https://cc65.github.io/doc/apple2.html), including
  AppleSingle, HIMEM, startup and language-card behavior.
- Installed a2kit 4.4.2 CLI and `src/fs/prodos/directory.rs`, for disk packaging
  and deterministic directory timestamps.
- [Sweet Micro Systems manual scan](https://www.classic-computing.de/wp-content/uploads/2023/06/Apple2_Mockingboard_Manual.pdf).
  The web tool could identify the scan but could not supply its page images.
  The manufacturer's Primary Routines were reviewed in their reproduced
  listings in *Mockingboard Definitive Guide v1.4 (2024)*, Appendix F pp. 70–71,
  together with the programming chapter and tone/register tables.
- [Rubywand Mini-manual](https://gswv.apple2.org.za/a2zine/Docs/Mockingboard_MiniManual.html).
  Its prose reverses the A/C mixer bit labels; the implementation uses AY tone
  bits 0/1/2 for A/B/C and noise bits 3/4/5, corroborated by the register tables
  and measured single-channel MAME output.
- [Jeremy Rand's a2bejwld](https://github.com/jeremysrand/a2bejwld/tree/62da1e9bf26db9e3dfe01c024c6a36509e14adc2),
  reviewed commit `62da1e9bf26db9e3dfe01c024c6a36509e14adc2`:
  `mockingboard.c`, `mockingboard.h`, and `sound.c`. Consulted for sequencing,
  slot mapping, mixer bits, and integration; detection/speech code was not
  imported. The a2piano assembly is newly written. See THIRD_PARTY.md.

Hardware reset/power removal is outside application-controlled stop paths.
Use normal-speed NTSC-compatible operation. PAL timing, acceleration, IIgs
fast mode, alternate AY clocks, and external NMI sources are not validated.
