# a2piano

A monophonic text-mode piano for an Apple II+ with 64 KB (48 KB plus a language
card), or a compatible later machine. Boot **[a2piano.po](a2piano.po)** in the
first floppy drive. ProDOS 2.4.3 automatically launches the program; no `BRUN`
command is needed.

- [Instant Play on Apple2Ts](https://apple2ts.com/#https://raw.githubusercontent.com/iolo/a2piano/main/a2piano.po)
- [Download ProDOS Disk Image](https://raw.githubusercontent.com/iolo/a2piano/main/a2piano.po) and Play on your Apple II

## Play

1. Press **Return** for the detected keyboard layout, or **O** for the old II+
   layout / **N** for the IIe and later layout.
2. Press **Return** or **S** for the internal speaker. For a conventional
   Mockingboard, press **M**, enter its installed slot **1–7**, then **Y**.
   Invalid slots are ignored. Esc at the slot prompt or any key other than Y
   at confirmation cancels to speaker. The program never searches for a card.
3. Play the mapped keys. On a detected **Apple //e**, hold a key to sustain
   its note and release all ordinary keys to stop. A different mapped key
   replaces the note; Space or an unassigned key stops it. Automatic repeats
   do not interrupt a held tone. This works with both sound outputs.
   On II+ and machines without enabled release sensing, notes retain the
   **500 ms** maximum duration and repeat events retrigger.

Mockingboard notes start with a strong attack and fade to silence in about
one second, even while held. A new press restarts the decay; //e key release,
Space, and unassigned keys still stop immediately. On II+, the existing
500 ms limit can cut the decay short. The internal speaker keeps its steady
tone. Mockingboard's hardware envelope starts at maximum volume, so its attack
is louder than the earlier fixed-volume version.

The piano occupies 40×24 text page 1, with inverse white keys and normal black
keys. The displayed range is intentionally A3–F5: 21 chromatic notes, 13 white
and 8 black keys. Bindings follow the revised PRD keyboard layout. Note labels
use A4/B4 and C#5/D#5 to keep the A3–F5 chromatic sequence consistent.

| White notes | IIe / later | II+ / old |
|---|---|---|
| A3 | Tab | Esc |
| B3 C4 D4 E4 F4 G4 A4 B4 C5 D5 | Q W E R T Y U I O P | Q W E R T Y U I O P |
| E5 F5 | [ ] | Left Right |

| Black notes | IIe / later | II+ / old |
|---|---|---|
| A#3 C#4 D#4 F#4 G#4 A#4 | 1 3 4 6 7 8 | 1 3 4 6 7 8 |
| C#5 D#5 | 0 - | 0 : |

Uppercase and lowercase letters behave alike. Release sensing uses the //e's
**Any Key Down** flag, not individual key-up events. If you hold Q, press W,
then release W while Q remains held, the W note remains selected until all keys
are released (its Mockingboard volume still decays); it cannot return
automatically to Q. Shift, Control, Caps Lock, and
the Apple keys do not count as ordinary held keys.

Release sensing follows detected hardware, independently of the O/N layout
choice. IIc is enabled by the same hardware identification but is untested;
IIgs and unknown models retain timed notes. On II+, releasing a key can leave
the note sounding until timeout (REPT retriggers). Esc plays A3 in old layout;
it is not an exit key. Reset the machine to change startup settings.

Use normal **1 MHz / NTSC-compatible** speed. On a IIgs, choose normal speed;
on an accelerated system/emulator, disable acceleration. PAL timing, fast mode,
physical cards, and other clone interfaces have not been validated. No chords,
sustain pedal, velocity, recording, tempo control, or live highlighting are included.

## Build

Prerequisites: GNU Make 4.3+, Python 3.9+, cc65 (`cl65`, `ca65`), a2kit. Tested
with cc65 V2.19 Git `a028ac414` and a2kit **4.4.2**. No network access or manual
disk editing is needed; boot inputs are pinned under `assets/prodos/`.

```sh
make                 # builds a2piano.po
make disk            # repackage and verify the image
make check           # disk verification + deterministic host checks
make diagnostic-disk # build/diagnostic.po; input diagnostics without tones
make speaker-disk    # build/speaker-only.po; independent speaker-only build
make clean           # deletes generated build/ artifacts and a2piano.po
```

`CL65`, `CA65`, `PYTHON`, and `A2KIT` can select installed tool paths. Generated
notes, assembly listings, linker map/labels, raw payload, catalog, and packaging
manifest are saved in `build/`. Directory dates are canonicalized so repeated
builds with the same toolchain produce identical disk bytes. The default
image is 143,360 bytes in **ProDOS sector order**, with 207 free blocks.

For runtime acceptance, install MAME 0.285 and NumPy for the selected Python,
and supply your own MAME ROM sets. The test runner copies the disk and isolates
all emulator output; it does not modify installed ROMs or user emulator state.

```sh
MAME_ROMPATH=/path/to/roms make verify
```

Required profiles: `apple2p`, `apple2e`, and `apple2ep`, plus Disk II ROMs and
`votrsc01a` for MAME's Mockingboard model. An available `apple2ee` set is also
smoke-tested; otherwise that optional profile is explicitly skipped. `MAME`
can override the executable. `make verify` collects WAV audio, bus timestamps,
keyboard results, machine settings and screenshots in `build/verification/`.
Host-only `make check` does not claim emulator coverage.

See [verification results](docs/VERIFICATION.md), [hardware/timing details](docs/HARDWARE.md),
and [third-party notices](THIRD_PARTY.md). All reported hardware behavior was
measured in emulators; no physical Apple II or Mockingboard was tested.
