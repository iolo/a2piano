# a2piano

Simple Piano simulator for Old 8bit Apple II series of computers

## Final Output
- A bootable disk image contains Piano program: a2piano.po

## Target H/W

- Apple II+ or later
- 64K+ RAM
- Optional: Mockingboard or clone
- or equivalent emulators

## Tech stack

- cc65 toolchain
- Make or shell script
- C and 6502 assembly
- ProDOS 2.4.3(latest stable)
- A2kit Disk Image Utility
- Apple II Text 40x24

## Features

- Available output:
  - Internal speaker (default)
  - Mockingboard (No autodetect, ask slot number)
- A3 to F5 notes (2 octaves)
- No advanced features like: chord, sustain, velocity, etc.
- Support both ][+(or before) and //e(or later) keyboard layouts(see below)
- Default duration is 1/4 note or until another key is pressed or spacebar is pressed
- Spacebar to stop playing the current note

## Implementation notes

- Black keys should displayed "NORMAL"(white/green text on black background)
- White keys should displayed "INVESE"(black text on white/green background)
- To detect Apple II family: https://prodos8.com/docs/technote/misc/07/
- Apple II doesn't support key release event

```
0         1         2
0123456789012345678901234567890123456789 ; columns

                                 :       ; old keyboard
   1     3  4     6  7  8     0  -       ; new keyboard
========================================
  |  |: |  |  |: |  |  |  |: |  |  |: |
  |  |: |  |  |: |  |  |  |: |  |  |: |
  |A#|: |C#|D#|: |F#|G#|A#|: |D#|E#|: |  ; note for black keys
--+--+: +--+--+: +--+--+--+: +--+--+: +-
:  :  :  :  :  :  :  :  :  :  :  :  :  :
:  :  :  :  :  :  :  :  :  :  :  :  :  :
:A3:B3:C4:D4:E4:F4:G4:A5:B5:C5:D5:E5:F5: ; note for white keys
+--+--+--+--+--+--+--+--+--+--+--+--+--+
TAB Q  W  E  R  T  Y  U  I  O  P  [  ]   ; new keyboard
ESC                               ←  →   ; old keyboard
```
