# IMAGE: making executables without the linker

Phase 3 of `PLAN.md`, run on 2026-10-21 on VAX/VMS V5.5-2H4. IMAGE
(`saostoic-text/stoic/image`, Jonathan Mark, 1982) writes the running
STOIC, with everything compiled into it, as a new `.EXE`. It does this
without LINK: it takes the image header of the kernel prototype
`SAO$KERNEL:HEAD0.EXE`, patches its image section descriptors (ISDs), and
writes live memory behind it. `STOIC.EXE` and `RED.EXE` are made this way
(`stoic.cre`, `red.cre`).

**Result:** IMAGE works on V5.5-2, with both the shipped and the rebuilt
STOIC. An image made by IMAGE runs, keeps its words, variables and strings,
gets a new revision date, and can itself make a second layer that also
works. Its limits are the 16-bit windows of the kernel (defect 6), the
fixed P0 layout it inherits from HEAD0 (defect 11), and several new defects
listed at the end.

The tests are in `tests/image/`; their recorded output is in
`tests/image/results/`. Values below are hex unless they say otherwise.

## How IMAGE works

### The memory IMAGE writes

A running STOIC has three regions that IMAGE saves
(`kernel/rkernel.mar:1975-1992` for the user-table cells):

| Region | Prototype in the exe | At run time | Grows from |
|---|---|---|---|
| data | `DATA_0` (200), VPN 1 | copied at startup into an `$EXPREG`'d block, `USER_DATA` (CFA00 shipped, 80200 rebuilt) | `.D` |
| dictionary | `DICT_0` (F800), VPN 7C | in place | `DICT_PNTR` |
| code | `CODE_0` (1FC00), VPN FE | in place | `CODE_PNTR` |

- **Data** is copied at startup: `rkernel.mar:333-345` allocates a block
  with a moat page in front and `MOVC3`s the prototype into it. So the data
  that runs is never the data in the exe file.
- **Dictionary and code** run where the exe put them. At startup
  `rkernel.mar:392-407` deletes and recreates the pages from
  `USER_DICTIONARY` and `USER_CODE` up to the end of each psect as
  writable, and sets `DICT_PNTR` and `CODE_PNTR` to the start of them.
  New words go there.

### Step by step

`IMAGE` is `"Creating writable image" MSG ... IMAGE_WRT`, and `IMAGE_WRT`
is `-1 .IMAGE` (`image:215-221`). The first definition of `IMAGE`,
`0 .IMAGE`, is the pre-V4 read-only form; it is hidden by the second one
but can still be called as `0 .IMAGE`.

`.IMAGE` (`image:193-213`) takes a file name and a write flag:

1. **UPDATE_POINTERS** (`image:91-95`):
   - stores the data length, `.D − USER_DATA`, in the first word of the
     data region;
   - rounds `DICT_PNTR` and `CODE_PNTR` up to a page and stores them in
     `USER_DICTIONARY` and `USER_CODE`.

   This changes the parent too. After `'T1.TMP IMAGE` the parent shows
   `USER_DICTIONARY=14C00 DICT_PNTR=14A9F` (`a-ship.txt`, a3-make1):
   the boundary is past the pointer, so a later SAVE in the parent writes
   from the new boundary.
2. **Reads the prototype header.** It opens `SAO$KERNEL:HEAD0.EXE` and reads
   VBN 1, one 512-byte block, into `HEAD` (`image:199-200`).
3. **SCHEDULE_WRITES** (`image:152-163`) walks the ISDs. The header itself
   is the first write. Each ISD of size 10 is a resident (file-backed)
   section, and DO_RESIDENT (`image:139-150`) tries it against data,
   dictionary and code in turn with CHECK_ISD (`image:124-137`):
   - The ISD matches when its VPN is the page of `DATA_0`, `DICT_0` or
     `CODE_0`.
   - The data region is written **from `USER_DATA`**, the live copy, into
     the prototype's VPN (`image:128`).
   - On a match:
     - SET_NOWRT clears the WRT and CRF flags (`image:64-66`, `:129`);
     - FIX_COUNT stores the new page count (`image:86-89`);
     - FIX_DZRO (`image:79-84`) moves the demand-zero ISD that follows up
       by the growth and shortens it by the same amount. When the write
       flag is 0 it also makes that ISD no-write.
   - A resident ISD that matches none of the three (ISD 7, the fixup
     vector at VPN 17E) is copied block by block from HEAD0
     (SCHEDULE_COPY, `image:106-114`).
4. **Creates the output** with block I/O (`image:204`).
5. **SET_REVISION** (`rdef:1490-1493`) puts the current time in `DATE`, so
   the new exe gets a new revision date. The parent's date is saved before
   and restored after (`image:205-208`).
6. **WRITE_IMAGE** (`image:179-191`) writes the header, then each region
   from memory or from HEAD0. If it did not find exactly three regions it
   prints an error, but only after the file has been written.

What the header looks like before and after (shipped HEAD0, `a-ship.txt`):

| ISD | HEAD0 | T1 (first layer) | T2 (second layer) |
|---|---|---|---|
| 1 data | 3 pages at VPN 1, flags 8A | A pages, flags 80 | A pages |
| 2 DZRO | 78 at VPN 4 | 71 at VPN B | 71 at VPN B |
| 3 dictionary | 10 at VPN 7C | 2A | 2B |
| 4 DZRO | 72 at VPN 8C | 58 at VPN A6 | 57 at VPN A7 |
| 5 code | 11 at VPN FE | 30 | 32 |
| 6 DZRO | 6F at VPN 10F | 50 at VPN 12E | 4E at VPN 130 |
| 7 fixups | 1 at VPN 17E, from VBN 26 | copied, VBN 66 | copied, VBN 69 |
| 8 | stack, 14 pages | unchanged | unchanged |
| 9, 10 | shareable images (size 24) | unchanged | unchanged |

Each resident section plus its DZRO keeps the same total size, so the
layout of P0 is the same in every generation. The rebuilt HEAD0 has the
same resident ISDs, a 2-page fixup vector, and four shareable ISDs of size
1F (FORRTL, LIBRTL, MTHRTL and the rest, `a-new.txt`) instead of two.

The first block is the only header block in both HEAD0s (`HDRBLKCNT=1`).

### IMAGE, IMAGE_WRT and `0 .IMAGE`

| Form | Resident sections | DZRO sections | On V5.5-2 |
|---|---|---|---|
| `IMAGE`, `IMAGE_WRT`, `-1 .IMAGE` | no-write | writable | runs |
| `0 .IMAGE` | no-write | **no-write** | `SYSTEM-F-BADISD` |

`R1` in `a-ship.txt` is `'R1.TMP 0 .IMAGE` (its ISDs are printed in
decimal): the DZRO flags are 132 (84) where `IMAGE` gives 8C. VMS V4 and
later refuse a demand-zero section that is not writable, so `RUN R1`
fails with BADISD. This is why the second `IMAGE` exists, and why the
shipped `REDHIREZ.EXE` of 1983 fails the same way (defect 21).

Even the "writable" form makes the resident sections no-write
(`image:129`). That is safe: the data runs from its `$EXPREG`'d copy, and
the dictionary and code pages above `USER_DICTIONARY` and `USER_CODE` are
recreated writable at startup. Words compiled before IMAGE cannot be
patched in the child.

### What the child inherits

The data region is copied as it is, so the child starts with whatever the
parent had there when IMAGE ran:

- **the radix**: an exe made in DECIMAL starts in DECIMAL;
- **`LINE_BUFFER`**;
- **`U_IFI`**, the current LOAD level. Made from inside a LOAD file, the
  exe opens SYS$INPUT on channel 1, and its first `;F` at console level
  reads channel 0, which was never opened (defect 23);
- **every absolute address the parent compiled**. They are right only if
  the child's `$EXPREG` regions land where the parent's did. They do on
  one system: T1 and T2 run with `USER_DATA=CFA00`, the same as the
  shipped STOIC. They do not when the shareable images change, which is
  defect 22.

## SAVE, XLOAD and the revision date

SAVE and XLOAD (`kernel/rms.mar:655-760`) write and read the same three
regions, from `USER_DICTIONARY`, `USER_CODE` and `USER_DATA` to the current
pointers. The first block holds the block counts and `DATE`, the revision
date of the exe that made the file. XLOAD compares the two longwords of
the date (`rms.mar:678-681`) and calls `@DATE_ERROR` if they differ, which
prints the message and aborts the line. XLOAD keeps `U_IFI` and `VOCAB_SP`
across the load (`_SAVE_DATA`, `_RESTORE_DATA`).

Because IMAGE gives each new exe a new date, a save file loads only into
the exe that made it. `a7-xload` tries a file saved in STOIC.EXE inside
T2:

    Invalid save file date in XLOAD
    Current image date:	21-OCT-2026 17:28:14.86
    Save file date:		 9-SEP-1985 21:17:31.34
    AFTER XLOAD

The refusal ends only the line: the next line runs. The message is the
kernel's `I_DATE_ERROR` (`rkernel.mar:566-584`). rdef defines another one,
"Error in XLOAD: invalid revision date" (`rdef:1497-1507`), but nothing
stores it in `DATE_ERROR`, so it is never used.

The date check is what makes SAVE/XLOAD safe: within one exe on one
system, the regions are always at the same addresses, so the absolute
addresses in a save file still hold. The round trip in one exe was shown
in Phase 1 (`tests/14-save`, `14-xload`).

## Results on V5.5-2

Run with `tests/image/run` (after `tools/vax-do tests/image/SETUP.COM`).
Each group runs in one VAX job; `SAO$KERNEL` is pointed at a copy of the
shipped or the rebuilt `HEAD0.EXE` in `[.WORK.IMG]`.

| Test | What it does | Result |
|---|---|---|
| a2-show | prints HEAD0's header and the pointers | as in the table above. Reading STOIC.EXE's header the same way gives RMS-W-RAC, not investigated further |
| a3-make1 | defines `SQ`, a VARIABLE `V1`=4321, a string `S1`; SAVE; `'T1.TMP IMAGE`; `'R1.TMP 0 .IMAGE` | T1 written; parent's revision unchanged (−1) |
| a4-run1 | `T1 7 SQ = V1 @ = S1 MSG DATE @ REV0 @ NE = CR ;F` | `49 4321HELLO FROM LAYER 1 -1`: words, variable and string kept, new date. `R1`: BADISD |
| a5-make2 | in T1: adds `CUBE`, `V2`, changes `S1` and `V1`; `'T2.TMP IMAGE` | T1's new words start at 14C00 and 25C00, the pages IMAGE rounded to |
| a6-run2 | runs T2 | `49 27 4326 77HELLO FROM LAYER 2 -1`: both layers work |
| a7-xload | XLOAD of the save file from a3 in T2 | refused, see above |
| a-new | a2–a7 with the rebuilt STOIC.EXE and HEAD0 | the same, with the rebuilt addresses |
| c1 | IMAGE from inside a LOAD file | `INCH 1`; the exe works if it leaves with `1 1 $EXIT` instead of `;F` |
| d1 | IORB< in the shipped and the rebuilt exe | defect 22 |
| `tests/interactive/image-console.tcl` | runs an IMAGE exe at the terminal and with SYS$INPUT a file | terminal: `49`. File: an RMS-W-FAC loop, the same as the shipped STOIC (defect 25) |

### The limits

| Test | What it does | Result |
|---|---|---|
| b1-datawin | grows the data region 1000 bytes at a time and checks each VARIABLE's address | right up to DEDC9; from DFDCD the VARIABLE gives an address 10000 lower. **Defect 6, data window** |
| b2-bigdata | 10000 bytes of data, then IMAGE | the data ISD becomes 8A pages, and its DZRO's page count underflows to FFF1. `RUN B2`: `SYSTEM-F-VA_IN_USE`. The data limit is 7B pages, F600 bytes (defect 26) |
| b4-dict | sets `DICT_PNTR` to 1FBF0 and defines two words | `D1` works; `D2`'s header crosses 1FC00, into the kernel's code: ACCVIO writing 1FC00, and `DICT_PNTR` is left there. **Defect 6, dictionary** |
| loop (b3-code) | sets `CODE_PNTR` to 2FBF0 and defines two words | `W2` works; `W1`'s code crosses 2FC00, into the fixup page: ACCVIO, then OPCDEC at the same PC forever. **Defect 6, code**, and defect 27 |
| b5 | IMAGE with `SAO$KERNEL` pointing at an empty directory | RMS-W-FNF and a traceback; the line ends and STOIC carries on |
| b6 | shipped STOIC with the rebuilt HEAD0 | IMAGE says nothing; `RUN M1` gives OPCDEC at 20DDC, then "Improperly handled condition" (defect 28) |

The windows come from the 16-bit displacements:

- **data**: a VARIABLE compiles to `MOVAL W^disp(R11)`, so one more than
  7FFF bytes above R11 gets a wrapped address (DATA_ADDRESS and
  I_DISP_TO_R11, `rkernel.mar:1768`, `:1043`);
- **code**: `JSB W^disp(R8)`, R8 = 27C00, reaches 1FC00–2FBFF;
- **dictionary**: the headers sit in the DICTIONARY psect, F800–1FBFF. The
  next psect is the kernel code.

In the shipped exe the dictionary has 1FBFF − 14A5D bytes left (about
45 KB), the code 2FBFF − 25A47 (about 41 KB), and the data region
F600 − 1395 in an IMAGE (about 58 KB). None of them is checked.

## Defects found in Phase 3

The numbers continue `PLAN.md`'s defect checklist.

- **6** (confirmed): no check on the windows, for data (b1), dictionary
  (b4) and code (b3). Data past the window gives wrong addresses silently;
  dictionary and code give a fault.
- **11** (characterized): IMAGE relies on a one-block header, resident ISDs
  of size 10 at the VPNs of the running kernel, and a DZRO after each. Both
  HEAD0s fit. It does not check that HEAD0 belongs to the running kernel
  (28), or that the DZRO is big enough (26).
- **22: rdef's BRANCH compiles an absolute data address.**
  `'BRANCH : .D@ SWAP 7FFFFFFF ,D BRANCH ;` (`rdef:943-944`) makes a word
  that pushes the address the branch cell had when it was defined. In the
  shipped STOIC.EXE, built in 1985 with `USER_DATA` at 7A400, `IORB<`
  pushes 7A891; on V5.5-2 the cell is at CFE91. The first lookup through
  it faults. The branch stays on the vocabulary stack, so every later line
  faults, `;F` included, and STOIC ends only at the end of its input
  (`d.txt`). In the rebuilt exe it pushes 80691, which is right. `FLOAT<`
  is made another way and works in both. `RED<` (`red/err:21`) is made
  like `IORB<`; it has not been tested in the shipped RED.EXE.
- **23: IMAGE inside a LOAD saves the LOAD level.** The child starts with
  `U_IFI` = 1, so its first `;F` at console level reads channel 0, which
  is not open, and loops on RMS-W-ISI (seen while writing c1; c1 shows
  `INCH 1` and avoids the loop). `stoic.cre` and `red.cre` run IMAGE from
  the console, so the shipped exes are not affected.
- **24: a console read error that persists loops forever.** I_READLINE's
  error goes through SYSERR to ABORT and back to `top_loop`, which reads
  again. Defects 23 and 25 end this way.
- **25: the console is opened by `$CREATE`, PUT only.** `_WOPEN_NCR`
  (`rms.mar:297-304`, called at `rkernel.mar:415-419`) creates SYS$INPUT
  with no GET access. A terminal or DCL data lines (process-permanent
  files) work; `DEFINE/USER SYS$INPUT file` makes STOIC create a new,
  empty version of the file and loop on RMS-W-FAC. The shipped STOIC does
  the same as an IMAGE exe (`tests/interactive/image-console.log`).
- **26: FIX_DZRO does not check for underflow** (`image:79-84`). Data
  beyond 7B pages wraps the DZRO's page count, and the exe fails with
  VA_IN_USE. A dictionary or code region that outgrew its DZRO would do the
  same, but the windows (6) stop them first.
- **27: a fault in the middle of MOVC3 leaves FPD set, and STOIC loops.**
  The handler (`rkernel.mar:472-484`) changes the signal PC to ABORT but
  keeps the PSL. When the fault came in the middle of an instruction that
  can be interrupted, such as the `MOVC3` that copies a definition's code
  (`rkernel.mar:835`), PSL&lt;FPD&gt; is still set (PSL 0BC00000), and the first
  instruction at ABORT faults with OPCDEC, again and again. Defect 4's
  loop is the same thing (PSL 0BC00001 in `tests/interactive/compbuf.log`).
- **28: IMAGE uses whatever HEAD0 `SAO$KERNEL` names.** With a HEAD0 from
  another build, IMAGE writes the exe without complaint, and it fails at
  START (b6). A missing HEAD0 is reported and harmless (b5).
- **29: rdef's `I_DATE_ERROR` is never installed** (`rdef:1497`), so its
  message is dead code. Minor.

Also noted, not defects:

- If IMAGE finds fewer or more than three regions, it says so after the
  file is written (`image:188`).
- IMAGE marks the resident sections no-write in every form.

## Not done

- **ANALYZE/IMAGE and `DIRECTORY/FULL` of T1 and R1.** The header fields
  were read with IMAGE's own words instead (`imgutil.sto`), and the BADISD
  is explained by the flags they show.
- **A different IOSEGMENT and a run under `/DEBUG`.** HEAD0 must be linked
  without the debugger (`image:76-77`). Neither was tried.

## install.com

`install.com` copies `RED.EXE` to `SYS$SYSTEM:STOIC.EXE` and installs it
with the V3 INSTALL syntax `STOIC/WRITE/SHARE/HEAD`. On V5 that would be

    $ INSTALL ADD SYS$SYSTEM:STOIC.EXE /OPEN/HEADER_RESIDENT

following IMAGE's own advice, "If installing in system, use /OPEN/HEAD
switches only": since the V4 fix the image has writable demand-zero
sections, and `/WRITE/SHARE` was for the read-only images of the earlier
form. It was **not run**: it writes outside `[.WORK]` and needs
privileges.
