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

The keyboard latch is read at $C000, acknowledged once through $C010, and
masked to seven bits. Alphabetic case normalizes in C. There is no release
inference. A playback routine returns with a new strobe still pending; the
shared dispatcher consumes it once, then either starts a replacement or stays
silent. Space and all unassigned events stop sound. Esc is a note in old layout.
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
All branches remain on one page, enforced by a link-time assertion. The outer
path adds 1284 cycles, including its alternate branch cost. Low-byte countdown
wrap has no variable branch. Interrupts are masked during the note, and no C,
ROM, disk, or screen work occurs in the loop. A new latch is tested every
half-period, at most about 2.28 ms apart. Returning without further $C030
accesses is the speaker's silent state.

`DURATION_MS` in `tools/generate_notes.py` is the single duration control,
default 500 ms (one quarter note at 120 BPM). The half-cycle count is rounded
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
R7=$3E, R8=10, R9=R10=0; the second chip remains silent. Volume bit 4 is clear,
so no envelope is used. Noise is disabled. The tone is `AY clock/(16*period)`
with a 12-bit period and the documented nominal 1,022,727 Hz AY clock.

The first VIA's T1 runs continuously in 10 approximately 50 ms periods. Its
interrupt enable bits remain off; the application polls IFR and the keyboard,
acknowledging T1 by reading its low counter. Stop paths set R8=0 before returning
and leave continuous timer mode. Pitch bytes are replaced while muted. No C
rendering runs during playback. The application owns these VIA settings until
machine reset; it does not promise to preserve another program's card state.

## Reviewed references

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
