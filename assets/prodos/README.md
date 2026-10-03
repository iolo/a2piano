# Pinned ProDOS boot inputs

These are the unmodified boot blocks, ProDOS 2.4.3, and BASIC.SYSTEM 1.7
from the official [ProDOS 2.4.3 release](https://prodos8.com/releases/prodos-243/).
The two files use a2kit's `any` JSON format, preserving bytes and ProDOS metadata.
The build verifies every input against `SHA256.json` and every imported payload.

Source: [ProDOS8-Releases/ProDOS_2_4_3.po](https://github.com/ProDOS-8/ProDOS8-Releases/blob/master/ProDOS_2_4_3.po)

Official image SHA-256, verified against the project's `SHA256SUM`:
`398d333cb2ab92df9f8bb2cf64b946f2567116910eb8359cf4bdee5d4194f0fa`.
Git blob: `d464c92578d4ed15dc4acd49eee43e51256808fd`.
Retrieved and checked 2026-10-03. No auxiliary utilities are included.

Extraction commands (a2kit 4.4.2):

```sh
a2kit get -d ProDOS_2_4_3.po -f 0..2 -t block > boot.bin
a2kit get -d ProDOS_2_4_3.po -f PRODOS -t any > PRODOS.json
a2kit get -d ProDOS_2_4_3.po -f BASIC.SYSTEM -t any > BASIC.SYSTEM.json
```

The range `0..2` is exclusive at its upper bound: two 512-byte boot blocks.

## Notices / redistribution review

ProDOS and BASIC.SYSTEM are third-party Apple system software, maintained in
this release by John Brooks and contributors. Their embedded copyright
notices remain intact. The release page, release README, and GitHub repository
metadata were checked: no explicit redistribution license was supplied
(`license: null` in GitHub metadata). Public download availability is not an
open-source license. These inputs and the resulting disk are retained here for
the requested local build; this project grants no additional redistribution
rights to Apple's system software. No public release/upload was performed.
Confirm applicable permission before redistributing the bundled system files.
The project sources do not purport to relicense those files.
