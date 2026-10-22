# Defects

This is Phase 5 of `PLAN.md`. It collects the defects found in Phases 1–4.
They were run on 2026-10-21 on VAX/VMS V5.5-2H4.

The numbers are those of `PLAN.md`'s defect checklist and `AGENTS.md`.
- 1–11 were suspected from reading the code before any test.
- 12–20 were found in Phase 1, 21 in Phase 2, 22–29 in Phase 3 (IMAGE),
  and 30–36 in Phase 4 (RED).
- 37–40 were found in Phase 5, while checking the claims in `float.md` and
  `language.md` (`tests/lang/`, output in `tests/lang/phase5.out`).
- 41 was found in Phase 6, while fixing defect 10, and 42 while testing
  the fix for 22.

**Result:** all 42 are confirmed or characterized. Number 9 came from
reading the source; Phase 6 confirmed it with REMSTART on the null device
(`tests/fix/F09-REMOTE.con`).

Each entry gives:
- a minimal repro, in uppercase STOIC with the default hex radix, unless
  it says otherwise;
- the cause, with `file:line`;
- the impact;
- a suggested fix.

Phase 6 fixed 37 of them in `patched/` (never in `saostoic-text/`); the
Status column gives the batch (`PLAN.md`), and [`patches.md`](patches.md)
lists each patch and its test. 13, 35 and 36 are corrected in the manual
instead ([`errata.md`](errata.md)), and 11 and 21 are closed.

## Summary

| # | Defect | Area | Impact | Status |
|---|---|---|---|---|
| 1 | DIGIT takes any character above `Z` as a decimal point | kernel | silent wrong code | fixed (A) |
| 2 | Only the first CTRL/C works | kernel | interactive | fixed (D) |
| 3 | The terminal IOSB overwrites NLEN | kernel | minor | fixed (C) |
| 4 | No compile-buffer overflow check | kernel | hang | fixed (C) |
| 5 | Integer literals wrap; a float in hex is read as decimal | kernel | silent wrong value | fixed (C); the float rule is documented (`float.md`) |
| 6 | No check on the 16-bit windows | kernel | silent wrong address, or a hang | fixed (C) |
| 7 | A missing LOAD or OPEN file exits STOIC | kernel | exit | fixed (B) |
| 8 | One record per TYO in batch | kernel | output | fixed (D) |
| 9 | Remote-line code | kernel | REMSTART faults, REMTYPE fails | fixed (D) |
| 10 | GETCMD uses the obsolete CLI callback | kernel | works; fragile | fixed (D) |
| 11 | IMAGE's header and layout assumptions | IMAGE | characterized | closed (F): covered by 26 and 28 |
| 12 | MOD and /MOD are unsigned | rdef | wrong value | fixed (B) |
| 13 | Comparisons are the reverse of the manual | rdef | documentation | documented (errata) |
| 14 | `=` writes NULs in negative numbers | kernel | output | fixed (A) |
| 15 | DGE compares the low longwords signed | rdef | wrong value | fixed (A) |
| 16 | `.FLIP` moves half of each value | float | wrong value | fixed (A) |
| 17 | MTH$ and OTS$ errors are not reported | float | later fault | fixed (B) |
| 18 | `.SQRT` of a negative ends STOIC | kernel, float | exit | fixed (B) |
| 19 | Every message shows ABORT's PC | kernel, rdef | confusing | fixed (B) |
| 20 | GETJPI leaves no completion code | rdef | documentation | fixed (A) |
| 21 | Pre-V4 IMAGE output gives BADISD | IMAGE | old exes | closed (F): no change needed |
| 22 | BRANCH compiles an absolute address | rdef | `IORB<` unusable in shipped exe | fixed (E) |
| 23 | IMAGE in a LOAD saves the LOAD level | IMAGE | loop | fixed (F) |
| 24 | A persistent console read error loops | kernel | loop | fixed (B) |
| 25 | The console is opened PUT-only | kernel | no file input | fixed (D) |
| 26 | FIX_DZRO underflows | IMAGE | exe fails | fixed (F) |
| 27 | A fault in MOVC3 leaves FPD set | kernel | loop | fixed (B) |
| 28 | IMAGE does not check HEAD0 | IMAGE | exe fails | fixed (F) |
| 29 | `I_DATE_ERROR` is never installed | rdef | dead code | fixed (A) |
| 30 | The shipped RED.EXE faults at startup | obuf | RED unusable | fixed (E) |
| 31 | After that fault the terminal is changed and `;F` hangs | RED | terminal | fixed (G) |
| 32 | KBD sends `ESC[?^Fl` | RED | harmless | fixed (A) |
| 33 | The up arrow differs from the manual | RED | documentation | fixed (G) |
| 34 | `@K` and `@N` leave the next insert drawn on the divider | RED | display | fixed (G) |
| 35 | `` `C `` replies differ from the manual | RED | documentation | documented (errata) |
| 36 | Smaller RED manual/code differences | RED | documentation | documented (errata) |
| 37 | `.+ROT` and `.-ROT` move half of one value | float | wrong value | fixed (A) |
| 38 | `F->S` writes one byte past `F_STRING` | float | harmless so far | fixed (A) |
| 39 | FS underflow is not caught | kernel, float | later fault | fixed (C) |
| 40 | `>` does not check for an empty branch stack | kernel | console unusable | fixed (A) |
| 41 | DEF_INIT copies a long command tail past LINE_BUFFER | rdef/kernel | corrupted tail, overwritten data | fixed (D) |
| 42 | NOCREF cannot read or write an exe header | image | NOCREF unusable | fixed (F) |

## Kernel and rdef

### 1. DIGIT takes any character above `Z` as a decimal point

- **Repro:** in a LOAD file, `1x5 .=`, `2_5 .=` and `7[ .=` each compile
  without an error and print `0.0000000000000000E+00` (`tests/06-numio`).
- **Cause:** DIGIT (`rkernel.mar:630-667`) subtracts the bias for `Z`+1.
  When the result is not negative, it falls through into `found_dp`
  (`rkernel.mar:643-644`). So every character above `Z` counts as a `.`,
  and the word becomes a float literal. OTS$CVT_T_D's status is not
  checked (`crtl.mar:109`).
- **Impact:** console input is uppercased, but LOAD files are not. A
  lowercase or misspelt word in a LOAD file compiles silently as a
  constant.
- **Fix:** after the `Z` test, branch to `not_digit`, not to `found_dp`.
  Check the status of the conversion.

### 2. Only the first CTRL/C works

- **Repro:** `tests/interactive/ctrlc.tcl`. A first ^C stops a loop. A
  second one is echoed but never delivered. A third interrupts like ^Y.
- **Cause:** The ^C AST calls `here_on_ctrl_c` (`controlc.mar:85-90`),
  which calls the kernel's `here_on_ctrl_c` (`rkernel.mar:1727-1735`),
  which calls I_CTRL_C_HNDLR (`rkernel.mar:1737-1748`).
  - I_CTRL_C_HNDLR finds STOIC's frame and writes `i_abort` over its
    return PC.
  - The AST routine never returns through the AST dispatcher, so the
    process stays at AST level. The re-enable at `controlc.mar:90` (`brb
    CKTERM`) is never reached either.
- **Impact:** one ^C per session. DELAY ($SETIMR, $WAITFR) still works.
- **Fix:** in the AST, set CTRL_C_FLAG only. Let the outer loop or the
  next TYO poll it and call ABORT at normal level. KBD in RED already polls
  the flag this way (`red/kbd:484-487`).

### 3. The terminal IOSB overwrites NLEN

- **Repro:** `tests/interactive/tty.tcl`. NLEN (TTCHAN+8, 3F as
  assembled) has already changed at startup, and it changes after every
  terminal QIO.
- **Cause:** every terminal QIO uses `iosb=ttchan+2(r11)`
  (`tyio.mar:136`, 154, 168, 177, 185, 200, 207, 269). That IOSB is a
  quadword, which covers TTCHAN+2 to TTCHAN+9.
- **Impact:** none seen. NLEN is the length cell of a name descriptor, and
  the code sets it to 63 before each $TRNLOG that uses it (`tyio.mar:88`,
  228).
- **Fix:** give the IOSB a quadword cell of its own.

### 4. The compile buffer has no overflow check

- **Repro:** `tests/interactive/compbuf.tcl`. The 17th 90-character line
  of one definition writes into the moat at CF000. STOIC then loops on
  OPCDEC until it is stopped.
- **Cause:** the buffer is `comp_buf_length` = 400 (hex) bytes
  (`rkernel.mar:81`). The words that compile into it advance
  `comp_buf_pntr` without a limit (`rkernel.mar:1011-1057`).
- **Impact:** the ACCVIO itself would be recovered from. But the fault is
  inside the MOVC3 that copies the code, so defect 27 turns it into an
  endless loop.
- **Fix:** check `comp_buf_pntr` against the end of the buffer in each
  compiling word, or once per line. Fix 27 as well.

### 5. Integer literals wrap; a float in hex is read as decimal

- **Repro:** `tests/06-numio`, `tests/12-float`. Literals wrap mod 2³².
  `1.E30` works only in HEX, because `E` must be a digit of the radix.
  It is then read as a decimal number.
- **Cause:** DIGIT's `mull2`/`addl2` (`rkernel.mar:662-663`) don't check
  for overflow. Floats are converted by OTS$CVT_T_D, which reads decimal
  (`crtl.mar:109`).
- **Impact:** a wrong constant, silently.
- **Fix:** check the V bit after `mull2`/`addl2`. Document the float
  rule, or convert floats in decimal regardless of the radix.

### 6. Nothing checks the 16-bit windows

- **Repro:** `tests/image/` b1, b3, b4 (`doc/image.md`).
  - b1: a VARIABLE more than 7FFF above R11 gets an address 10000 too low.
  - b4: a header past 1FBFF gives ACCVIO.
  - b3: code past 2FBFF gives ACCVIO into the fixup page, then loops (27).
- **Cause:** calls and user-table references are compiled as 16-bit
  displacements with `cvtlw`, which truncates silently
  (`rkernel.mar:1016`, 1047). Each header holds a 16-bit code
  displacement (`rkernel.mar:890-893`).
- **Impact:** big applications fail silently or hang.
- **Fix:** check the range when compiling, and say "Code space full" or
  "Data space full". Phase 6 did that. Phase 7 removed the code limit
  instead: a call out of `W^` range compiles as `JSB L^disp(R8)`, headers
  hold a longword displacement, and the code region runs to K_END
  (`doc/patches.md`, "Phase 7").

### 7. A missing LOAD or OPEN file exits STOIC

- **Repro:** `'NOSUCH.STO LOAD` (`tests/10-files`, `11-errors`). STOIC
  exits with `%RMS-F-FNF`.
- **Cause:** the `.errstop` macro calls LIB$STOP (`rkernel.mar:84-88`,
  `rms.mar:40-44`). LIB$STOP cannot continue. The condition handler
  changes the PC to ABORT and resignals (`rkernel.mar:472-484`), but VMS
  will not continue after LIB$STOP.
- **Impact:** a typo in a file name ends the session, and any unsaved
  definitions are lost.
- **Fix:** use LIB$SIGNAL, or return the status for SYSERR to report.

### 8. In batch, every TYO is its own record

- **Repro:** run STOIC under SUBMIT (Phase 0). The log has one character
  per line.
- **Cause:** for a non-terminal, `outinit` (`tyio.mar:105-124`) points
  TYO and TYPE at `_rmstyo` and `_rmstype`, which $PUT one record per
  call.
- **Impact:** batch logs can't be read. The tools avoid batch.
- **Fix:** buffer TYO output until CR, as obuf does for RED.

### 9. The remote-line code

This came from reading the source; nothing in rdef or RED calls REMSTART
or REMTYPE (`rkernel.mar:1476-1486`). Phase 6 confirmed it without a
second terminal line, using the null device: `"NLA0:" "NLA0:" REMSTART`
gives ACCVIO at virtual address 03C00000 in REMSTART, and REMTYPE then
gives IVCHAN (`tests/fix/F09-REMOTE.con`, `tests/fix/shipped/`).

- `_remstart` builds the output name descriptor with `@nstore`
  (`tyio.mar:243`), but the input one with `nstore` (`tyio.mar:227`). One
  of them is wrong.
- `rmast` (`tyio.mar:262`) calls LIB$SIGNAL with an argument count of 1
  without pushing an argument (`tyio.mar:264`, 271, 278).
- `rmast` uses R11 at AST level without setting it. The kernel's own ^C
  routine recovers R11 first (`rkernel.mar:1729`).

**Fix:** if the feature is wanted, push the status before LIB$SIGNAL,
recover R11 as the ^C routine does, and make the descriptors consistent.

### 10. GETCMD uses the obsolete CLI callback

- **Repro:** `tests/13-calc.dcl`. It works on V5.5-2H4, including an
  empty tail.
- **Cause:** GETCMD calls `@cli$a_utilserv(ap)` (`ss.mar:291-296`), the
  CLI callback of VMS V1–V3.
- **Impact:** none on V5.5-2. It may fail on a later VMS.
- **Fix:** LIB$GET_FOREIGN.

### 12. MOD and /MOD are unsigned

- **Repro:** `-7 2 MOD =` gives 1, and `-7 3 MOD =` gives 0, because
  2³²−7 is divisible by 3 (`tests/00-mod`, `01-arith`).
- **Cause:** `'MOD : MOVQ (P)+ R0 CLRL R2 EDIV R0 R1 R1 -(P) ;`
  (`rdef:242-244`) and `/MOD` (`rdef:274-277`). The dividend's high
  longword is zero, not the sign extension of the low one.
- **Impact:** wrong results for a negative dividend.
- **Fix:** sign-extend the dividend (`ASHQ`, or `CVTLQ`-style code with
  `MNEGL`/`SBWC`) before EDIV.

### 13. Comparisons are the reverse of the manual

- **Repro:** `1 2 GT =` gives −1 (`tests/02-compare`).
- **Cause:** `'GT : CMPL (P)+ (P)+ BGTR ITEFT ;` (`rdef:489`, and GE and
  LT at 493 and 495). The CMPL compares A, the top of stack, with B. CP/M
  STOIC does what `stoic.mem` says (`doc/cpm-compare.md`).
- **Impact:** none for code written for the VAX: every use in the sources
  expects this sense. Code from other STOICs, or written from the manual,
  goes wrong.
- **Fix:** correct the manual. Changing the words would break the sources.

### 14. `=` writes a negative number as `-`, three NULs, then the digits

- **Repro:** `-1 =` (`tests/01-arith`, `02-compare`). `tools/stoic-run`
  shows the NULs as `^@`.
- **Cause:** EQ_SGN pushes the sign onto its string with
  `movl #^a/-/,-(r5)` (`rkernel.mar:1684`). That is a longword, so the
  `-` is followed by three zero bytes.
- **Impact:** invisible on a terminal, but they get into files and logs.
- **Fix:** `movb`.

### 15. DGE compares the low longwords signed

- **Repro:** `0 0 0 -1 DGE =` gives 0. `-1 5 -1 3 DGE =` gives −1
  (`tests/02-compare`).
- **Cause:** when the high longwords are equal, DGE compares the low ones
  with GE (`rdef:555-563`), which is signed. A quadword's low half is
  unsigned.
- **Fix:** compare the low longwords unsigned (`BGEQU`).

### 16. `.FLIP` moves only the first longword of each value

- **Repro:** `tests/12-float`. After `.FLIP`, 1.1 becomes 1.0999999….
- **Cause:** `MOVL (FS) R0 MOVL (FS) B^ 10 (FS) MOVL R0 (FS) B^ 10`
  (`float:46-48`). A D_floating value is a quadword.
- **Fix:** MOVQ.

### 17. MTH$ and OTS$ errors are not reported

- **Repro:** `tests/12-math`. LOG of 0, ASIN of 2 and a POWDD overflow
  return a reserved operand. The next float word faults with ROPRAND.
- **Cause:** the float words call the MTH$ routines without checking for
  an error (see `doc/float.md`).
- **Impact:** the error appears later, in another word.
- **Fix:** check the result, or enable the MTH$ signals and catch them.

### 18. `.SQRT` of a negative number ends STOIC

- **Repro:** `-1. .SQRT .=` (`tests/12-math`): ACCVIO at PC 80000010,
  then "Improperly handled condition".
- **Cause:** MTH$DSQRT signals from deeper than one frame. The condition
  handler then calls `$UNWIND` (`rkernel.mar:480-482`) and resignals, and
  that path fails. This is the suspected cause; it has not been traced.
- **Fix:** test the argument before the call, and look into the
  handler's unwind path.

### 19. Every error message shows ABORT's PC

- **Repro:** any run-time error. The message says PC=00023998.
- **Cause:** the handler writes `ABORT @` into the signal PC before VMS
  prints the message (`rkernel.mar:478`). rdef sets ABORT to ERROR_TRACE
  (`rdef:1426-1440`).
- **Impact:** confusing. The real PC is in ERROR_PC, and ERROR_TRACE's
  traceback shows it as the first line.
- **Fix:** print ERROR_PC in ERROR_TRACE's first line, and say so.

### 20. GETJPI's comment promises a completion code it doesn't leave

- **Repro:** `tests/15-sys`.
- **Cause:** the comment says "completion code, value or pointer"
  (`rdef:795`). SYSERR takes the code, and only the value is left.
- **Fix:** correct the comment.

### 24. A persistent console read error loops forever

- **Repro:** `tests/image/` c1 and `tests/interactive/image-console.tcl`.
- **Cause:** I_READLINE (`rkernel.mar:1456`) reports the error through
  SYSERR. SYSERR calls ABORT, and ABORT goes back to `top_loop`
  (`rkernel.mar:486-489`), which reads again (`rkernel.mar:450-467`).
- **Impact:** an endless loop of messages. Defects 23 and 25 end this way.
- **Fix:** count the errors in a row on channel 0, and exit after a few.

### 25. The console is opened by `$CREATE`, PUT only

- **Repro:** `DEFINE/USER SYS$INPUT file` before STOIC.
  `tests/interactive/image-console.tcl` shows that STOIC creates an empty
  new version of the file and loops on RMS-W-FAC.
- **Cause:** startup opens SYS$INPUT with `_WOPEN_NCR`
  (`rkernel.mar:415-419`), which sets PUT, clears GET, and calls `$CREATE`
  (`rms.mar:297-304`). A terminal or DCL data lines work, because they
  are process-permanent files.
- **Fix:** open SYS$INPUT with `$OPEN` and GET access.

### 27. A fault in the middle of MOVC3 leaves FPD set

- **Repro:** defect 4's test, or `tests/image/` b3.
- **Cause:** the handler changes the signal PC to ABORT but keeps the PSL
  (`rkernel.mar:472-484`). When the fault came in the middle of an
  instruction that can be interrupted, such as the MOVC3 that copies a
  definition (`rkernel.mar:835`), PSL<FPD> is still set. ABORT's first
  instruction then faults with OPCDEC, forever.
- **Fix:** clear PSL<FPD> in the signal array's PSL as well as changing
  the PC.

### 29. rdef's `I_DATE_ERROR` is never installed

- **Repro:** XLOAD a save file from another exe (`tests/image/` a7). The
  kernel's message appears, not rdef's.
- **Cause:** `rdef:1497` defines it, and nothing stores it in the user
  table.
- **Fix:** install it in DEF_INIT, or delete it.

## IMAGE, SAVE and XLOAD

`doc/image.md` has the details and the tests.

### 11. IMAGE's header and layout assumptions (characterized)

- IMAGE relies on three things:
  - a one-block header;
  - resident ISDs at the VPNs of the running kernel;
  - a DZRO section after each of them.
- Both HEAD0s, the shipped one and the rebuilt one, fit.
- What it does not check is defects 26 and 28.
- The P0 layout is the same in every generation on one system. It does
  depend on the shareable images linked: a V5 link puts the regions 4F800
  lower. That is what breaks the absolute addresses of 22 and 30.
- **Closed in Phase 6 (Batch F).** The patched IMAGE checks the two things
  that can go wrong: the DZRO sizes (26) and HEAD0 itself (28). The
  one-block header and the ISD layout are those of every HEAD0 this
  kernel's link produces, and a HEAD0 that differs fails 28's check.

### 21. IMAGE output from before the V4 fix no longer runs

- **Repro:** `RUN [.SAOSTOIC.RED]REDHIREZ.EXE`, or the output of
  `0 .IMAGE`. Both give `SYSTEM-F-BADISD`.
- **Cause:** the demand-zero ISDs are marked no-write. IMAGE_WRT, the V4
  fix, is built into `image` (`doc/image.md`).
- **Fix:** rebuild with the current `image`, as Phase 2 did for
  REDHIREZ.
- **Closed in Phase 6 (Batch F)** with no code change: the patched build
  makes REDHIREZ.EXE again with IMAGE_WRT.

### 22. rdef's BRANCH compiles an absolute data address

- **Repro:** `IORB<` in the shipped STOIC.EXE (`tests/image/` d1). After
  it, every line faults.
- **Cause:** `'BRANCH : .D@ SWAP 7FFFFFFF ,D BRANCH ;` (`rdef:943-944`)
  makes a word that pushes the address its cell had at definition time.
  - That was 7A891 in 1985. The cell is at CFE91 today.
  - The rebuilt exe is right, because it was built on this system.
- **Impact:** `IORB<` can't be used in the shipped exe. Use
  `USER_DATA @ 491 + V_PUSH` (`tests/image/imgutil.sto`).
- **Fix:** store the cell as an offset from USER_DATA and add it at run
  time, as DISP_TO_R11 does for user variables.
- **Fixed in Phase 6 (Batch E).** BRANCH compiles the cell's displacement
  from R11, and the kernel's I_PUSH_VOCAB adds R11 at run time
  (`addl3 r11,@#disp,-(r10)`). The patched kernel also puts the data
  region at a fixed address, 402200 (decision 4). `tests/fix/F22-BRANCH.con`
  defines and uses a branch; the shipped exe gives `IORB< -5516F`, a cell
  below USER_DATA, and the patched one `IORB< 629`.

### 23. IMAGE inside a LOAD saves the LOAD level

- **Repro:** `tests/image/` c1.
- **Cause:** IMAGE writes the data region as it is, including `U_IFI`.
  The child exe starts at LOAD level 1, and its first `;F` reads channel 0,
  which is not open, and loops (24).
- **Fix:** clear `U_IFI` in the image copy, or refuse IMAGE in a LOAD.
- **Fixed in Phase 6 (Batch F).** `.IMAGE` refuses when `U_IFI @` is not
  0: "IMAGE must be run from the console" (`tests/fix/F23-IMAGELOAD.dcl`).

### 26. FIX_DZRO does not check for underflow

- **Repro:** `tests/image/` b2 (10000 bytes of data). The DZRO count
  becomes FFF1, and `RUN` gives VA_IN_USE.
- **Cause:** `image:79-84` subtracts without a check.
- **Fix:** refuse to IMAGE when a region has outgrown its DZRO.
- **Fixed in Phase 6 (Batch F).** FIX_DZRO records the region when the
  growth is at least the DZRO's page count, and `.IMAGE` then refuses:
  "IMAGE: the data region has outgrown its demand-zero section in HEAD0"
  (`tests/fix/F26-DZRO.dcl`).

### 28. IMAGE does not check that HEAD0 matches the running kernel

- **Repro:** `tests/image/` b6. The shipped STOIC with the rebuilt HEAD0
  writes an exe that fails at START with OPCDEC.
- **Fix:** compare HEAD0's link date or ISDs with the running image.
- **Fixed in Phase 6 (Batch F).** KERNEL_MATCH compares HEAD0's code
  section, block by block, with the running kernel at CODE_0, and
  `.IMAGE` refuses on any difference or if there is no such section:
  "IMAGE: SAO$KERNEL:HEAD0.EXE is not the kernel this STOIC was built on"
  (`tests/fix/F28-HEAD0.dcl`, `doc/image.md`, "The guards").

## RED

`doc/red.md` has the details and the tests (`tests/red/`).

### 30. The shipped `RED.EXE` faults at startup

- **Repro:** `RED file` with the shipped RED.EXE (`tests/red/r6-ship`).
  `%SYSTEM-W-ACCVIO … virtual address=0007B173`, in B! ← TYO ← ESC ←
  ANSI_VT100 ← INIT_VT100 ← .RED ← RED.
- **Cause:** `.D@ 'O.BUFSTRT CONSTANT` and `.D@ 'O.BUFEND CONSTANT`
  (`obuf:40`, 42) freeze absolute addresses in the data region.
  - In the shipped STOIC, `O.BUFSTRT` is 7B173, the 1985 address, but
    `USER_DATA` is now CFA00.
  - BUFFER_ON (`obuf:52-53`) turns on buffering, and the next TYO writes
    to the stale address.
  - The shipped STOIC survives only because buffering is off at its
    console.
- **Impact:** the shipped RED can't be used. Use the rebuilt
  `[.WORK.SAOSTOIC.RED]RED.EXE`.
- **Fix:** as for 22: keep offsets from USER_DATA, or compute the
  addresses at run time.
- **Fixed in Phase 6 (Batch E)** by the fixed data address: the patched
  kernel makes P0 end at 400000 before it `$EXPREG`s its regions
  (`fix_p0`), so USER_DATA is 402200 wherever the shareable images end,
  and `O.BUFSTRT` stays right. `tests/image/` e-pat runs an exe after
  adding 512 pages (200 hex) of demand-zero space below its shareables (WIDEN):
  O.BUFSTRT−USER_DATA stays F0C. e-new does the same with the unpatched
  rebuild: the data region moves to D0200, and the offset becomes −4F28D.

### 31. After the fault in 30, the terminal is changed and `;F` hangs

- **Repro:** `tests/red/r6-ship`.
  - After STOP, SHOW TERMINAL gives Device_Type Unknown, No ANSI_CRT and
    No Wrap.
  - Twice, `;F` at the `0>` prompt gave no output and no DCL prompt.
- **Cause:** E.SET_CHARS has already changed the terminal, and no
  handler restores it. Why `;F` hangs has not been traced. A guess is
  that O.FLAG stays set, so every TYO faults again.
- **Fix:** restore the terminal in ABORT's path while RED is active, and
  fix 30. Recovery: `SET TERMINAL/DEVICE=VT100`.
- **The hang is 30's.** `tests/red/r10-fault` makes a fault inside RED
  (`1/0` on the command line, a DIVL by zero, SS$_INTDIV). With the
  rebuilt, unpatched RED, `;F` returns to DCL, but the terminal is still
  left Unknown, No Wrap and No ANSI_CRT. O.FLAG stays set, so CR at the
  `0>` prompt is buffered and not seen (`r10b-bufoff`: BUFFER_OFF cures
  it). Only the shipped exe's stale O.BUFSTRT makes `;F` hang.
- **Fixed in Phase 6 (Batch G).** `.RED` saves ABORT in RED.OLD_ABORT and
  installs RED_ABORT (`patched/red/red`), and puts the old ABORT back when
  RED exits. RED_ABORT resets the registers, puts the old ABORT back, and
  undoes what RED set up: the scroll region (`18 1 STBM`), the cursor
  (to the bottom row), the numeric keypad, wrap, BUFFER_OFF,
  `E.RESET_CHARS` and the CTRL/C handler. It does not call RESTORE_VT100, whose `ESC c` would
  erase the message. Then it jumps (`JMP @(P)+`) to the old ABORT, so the
  traceback is the same as before. In `tests/red/patched/r10-fault` the
  message and traceback print, `DECIMAL 1 2 + = CR` prints ` 3`, `;F`
  returns to DCL, and SHOW TERMINAL gives VT100, Wrap and ANSI_CRT.

### 32. KBD sends `ESC [ ? ^F l`

- **Repro:** any RED session's raw log (`tests/red/*.raw`).
- **Cause:** `vt100` defines RESET_MODE twice.
  - The first (`vt100:63`) takes a number and types it with `#A`.
  - The second (`vt100:153`) takes a character and types it with TYO.
  - KBD's `6 RESET_MODE` (`red/kbd:500`) gets the second, and sends ^F.
- **Impact:** none on a VT100, which acts on the ^F and ignores the rest.
  Emulators may print the `l` (`tools/red-screens` removes it).
- **Fix:** `ASCII 6 RESET_MODE`.
- **Fixed in Phase 6 (Batch A; checked in Batch G)** that way
  (`patched/red/kbd`). The raw
  logs of the patched RED (`tests/red/patched/r4-keys.raw`, `r8-input.raw`)
  have only `ESC [ ? 6 l`.

### 33. The up arrow differs from the manual

- **Repro:** `tests/red/r4-keys`, snapshots `up-mid` and `up-bol`. From
  mid-line, the up arrow goes to the start of the same line.
- **Cause:** C.UP_ARROW (`red/eb:65-72`) steps back one character and then
  searches back for a CR.
- **Fix:** correct the manual, or step back to the previous line's start
  in all cases.
- **Fixed in Phase 6 (Batch G)** the second way (decision 2): C.UP_ARROW
  is `1+ C.L-`, n+1 CRs back from anywhere in the line. In
  `tests/red/patched/r4-keys.scr`, from row 12 column 4, `up-mid` is at
  11,1 and `up-bol` at 10,1 (the shipped RED: 12,1 and 11,1).

### 34. After `@K` or `@N`, the next insertion is drawn on the divider

- **Repro:** `tests/red/r8-input`. `@K^WI` with `A` typed draws `65` after
  the divider, at column 42. ^R shows that the buffer is right.
- **Cause:** C.@K and C.@N redraw the divider with its prompt and leave
  the terminal cursor there. RED's display code assumes the cursor is
  still in the text window.
- **Fix:** put the cursor back (or force a redraw) after the prompt.
- **Fixed in Phase 6 (Batch G).** After DRAW_DIVIDER, C.@K and C.@N do
  `S.CUP FLUSH` (`SROW D@ CUP`, `window:55`) in `patched/red/cli` and
  `clihirez`. In `tests/red/patched/r8-input.scr` the divider stays clean,
  and 65, 25 and −123 are drawn on their own lines in the text window.

### 35. `` `C `` replies differ from the manual

- **Repro:** `tests/red/r7-modes`, `cond-*` snapshots.
- **Cause:** the code (`red/cli:1217-1220`) treats RETURN like ESC and
  exits only on SPACE. Any other key rings the bell. The manual (5.6)
  says any other key exits. The prompt RED draws matches the code.
- **Fix:** correct the manual.

### 36. Smaller differences between the RED manual and the code

- `TF` clamps out-of-range values to 1–10 (`red/cli:817-823`) instead of
  rejecting them.
- `TI` ("set radix") says "Command not implemented." (`red/cli:825-827`),
  so arguments are always decimal.
- `'` (NOT) is postfix.
- `,` (INPUT MODE), `^W`, keypad ENTER and ESC S work, but the manual does
  not mention them.

**Fix:** correct the manual.

## Found in Phase 5

### 37. `.+ROT` and `.-ROT` move only half of one value

- **Repro:** `FLOAT< DECIMAL`, then `1.1 2.2 3.3 .+ROT .= .= .=` prints
  2.2, 1.1 and 3.300000143051147; `.-ROT` prints 1.099999928474426 first
  (`tests/lang/F1-FLOAT.con`).
- **Cause:** each word sets one value aside in R0 with MOVQ or MOVL and
  puts it back with `MOVL R0 ...` (`float:32`, `:36`, `:39`). A D_floating
  value is a quadword, so its low longword is lost.
- **Impact:** the moved value loses its low 32 bits of fraction, as with
  `.FLIP` (16). Values like 1. and 2. are exact either way, which is why
  `12-float` did not show it.
- **Fix:** MOVQ, with R0–R1 for the saved value.

### 38. `F->S` writes one byte past `F_STRING`

- **Repro:** `FLOAT< DECIMAL`, then `0 F.EXPADD ! 1.5 .= F.EXPADD @ =`
  gives 32 (a blank), not 0 (`tests/lang/F1-FLOAT.con`).
- **Cause:** `15 'F_STRING SVARIABLE` allocates 15 hex bytes (`float:12`),
  but `F->S` sets the length to 16 hex (`float:115`), and the conversion
  fills it.
- **Impact:** the last blank lands in `F.EXPADD` (`float:126`). `.<#`
  resets that before use, so no wrong output has been seen.
- **Fix:** `16 'F_STRING SVARIABLE`.

### 39. Float-stack underflow is not caught

- **Repro:** `FLOAT< DECIMAL`, then `.DROP .=` on an empty FS prints 22
  NULs and no message. The next line with a float literal faults with
  ACCVIO at CE608 in ICOMPILE (`tests/lang/F4-FSUNDER.con`).
- **Cause:** the stacks rely on the moat page below each one
  (see `doc/kernel.md`); nothing guards the other end, and the page above
  the FS base is readable. Float literals are converted on the FS.
- **Impact:** a wrong value, then a fault in a later, correct line. The
  error resets FS. Overflow is caught (ACCVIO at CE3F8,
  `tests/lang/F3-FSOVER.con`).
- **Fix:** a no-access page above each stack base too, or a check in the
  float words.

### 40. `>` does not check for an empty branch stack

- **Repro:** at the console, `> > > >`, then any line. Every later line,
  even `;F`, fails with ACCVIO in I_LOOKUP, so STOIC can only be left with
  CTRL/Y (`tests/lang/L3-POP.con`).
- **Cause:** `>` is just `addl2 #4,vocab_sp(r11)` (`rkernel.mar:1862-1865`).
  The "VOCABULARY STACK EMPTY" message of `stoic.mem` does not exist in the
  source.
- **Impact:** an unbalanced `>` in a LOAD file or at the console leaves
  STOIC unusable.
- **Fix:** compare `vocab_sp` with the stack base and give an error.

## Found in Phase 6

### 41. A long command tail overruns LINE_BUFFER

- **Repro:** a DCL command tail of more than about 130 characters, such as
  `STOIC DECIMAL 0` followed by 45 copies of ` 1 +` and ` = CR ;F`
  (203 characters). The shipped exe reports `^@+ECIMAL` undefined and
  shows a line with NULs spliced into it (`tests/fix/F10-TAIL.dcl`).
- **Cause:** DEF_INIT moves the whole tail from GETCMD into LINE_BUFFER
  with MOVE_BYTES (`rdef:1516-1520`). LINE_BUFFER is 132 bytes
  (`rkernel.mar:80`), and nothing compares the two lengths; GETCMD
  (`ss.mar:291-296`) returns whatever the CLI gives it.
- **Impact:** the bytes past the buffer overwrite the data that follows
  it, and the tail runs corrupted.
- **Fix:** limit the tail to the buffer's size. The patched GETCMD reads it
  with LIB$GET_FOREIGN into its own buffer, limited to LINE_BUFFER's size
  word, and gives `%LIB-W-INPSTRTRU` with an empty line when it is longer.

### 42. NOCREF cannot read or write an exe header

- **Repro:** `tests/fix/F42-NOCREF.dcl`, patched exe only (it needs
  `IORB<`, 22). It runs NOCREF on copies of the patched STOIC.EXE and
  HEAD0.EXE:
  - alone, it gives `%RMS-F-IFI`;
  - after INIT_FRABS, on STOIC.EXE, it gives `%RMS-F-RAC`;
  - after INIT_FRABS, on HEAD0.EXE, it gives `%RMS-F-NEF`.
- **Cause:** NOCREF (`image:225-238`) has three faults.
  - It uses HEAD0_FRAB without calling INIT_FRABS (`image:28-33`), so the
    RAB has no file unless an IMAGE ran first.
  - FRANDOGET and FRANDOPUT (`image:16-26`) do keyed (relative record)
    access. An exe made by IMAGE has variable-length records, because
    IMAGE writes it with `$PUT`s, and RMS allows keyed access to a
    sequential file only with fixed-length records. So the GET fails.
  - A linked exe has fixed 512-byte records, so the GET works, but a
    keyed `$PUT` to a sequential file must add a record at the end of
    file; replacing one needs `$UPDATE`.
- **Impact:** NOCREF, which was meant to clear copy-on-reference in an
  exe's resident ISDs, has never worked on VMS. Nothing else uses
  FRANDOPUT. `.IMAGE` reads HEAD0 with FRANDOGET, which works, as HEAD0 is
  linked.
- **Fix:** open the file for block I/O and read and write VBN 1 with
  FREAD and FWRITE, as `tests/image/widen.sto` does.
- **Fixed in Phase 6 (Batch F)** that way, with INIT_FRABS first.
  `tests/fix/F42-NOCREF.dcl` shows CRF cleared in the resident ISDs of an
  exe made by IMAGE and of a linked one. The result needs INSTALL to run
  (`SYSTEM-F-NOTINSTALL`), as its fixup-vector section becomes a writable
  shareable one; installing was not tried (`doc/image.md`).

