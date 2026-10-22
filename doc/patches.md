# Patches: the Phase 6 build

Phase 6 fixed the defects in [`defects.md`](defects.md) in a copy of the
sources. This page lists each patch: its defect, what changed, the test
that shows it, and what behaves differently from the shipped exes. The
manuals are not patched. Where they are wrong, [`errata.md`](errata.md)
gives the corrections.

- **Sources:** `patched/` here, a full copy of the VMS tree, and
  `DUA1:[USERS.CLAUDE.WORK.PATCHED...]` on the VAX. `saostoic-text/` and
  `[.SAOSTOIC...]` are unchanged. `git log -- patched/` has one commit for
  each early fix (Batch A), then one commit for each batch.
- **Build:** `tools/patched-push`, then `tools/patched-build.com`
  ([`build.md`](build.md), "The patched build"). It makes the kernel,
  HEAD0, STOIC.EXE, RED.EXE and REDHIREZ.EXE.
- **Tests:**
  - `tools/patched-suite` runs the suite against `tests/patched/`.
  - `tools/patched-suite --fix` runs one test for each defect in
    `tests/fix/`. With `--shipped` it shows the defect on the shipped
    exes.
  - `tests/interactive/patched/` and `tests/red/patched/` hold the
    interactive checks and RED scripts run against the patched build.

## Status

**Fixed and tested:** 44 of the 49 defects (43–49 were added on
2026-10-22). **Documented** in
`errata.md`, with no code change: 13, 35 and 36. **Closed**, with a
stated reason: 11 and 21.

On the final build (2026-10-22):

- the 18 suite tests pass against `tests/patched/`;
- the 38 `tests/fix/` tests pass;
- the RED scripts r0–r11 match their shipped results, apart from the
  differences listed below;
- r12-bounds, which the shipped RED cannot run, gives the screens in
  `tests/red/patched/r12-bounds.scr`: the comparisons in expressions, TF,
  the buffer and register limits, and nesting to 24 levels (49);
- the interactive checks in `tests/interactive/patched/` give what the
  fixes predict. Every CTRL/C aborts (`ctrlc`, `ctrlc3`). NLEN keeps its
  value after TYI (`tty`). `compbuf` stops with "Compile buffer full",
  where the shipped exe looped on OPCDEC; its next line then faults on an
  empty stack, as an empty-stack DUP does on either exe. `image-console`
  uses the shipped HEAD0, so the patched IMAGE refuses it (28).

## The patches

| # | File | Change | Test |
|---|---|---|---|
| 1 | `rkernel.mar` | DIGIT stops at a character above `Z` instead of taking it as a decimal point. A float literal that OTS$CVT_T_D rejects is the compile error "invalid floating-point literal" | F01-LOWER, F01-BADFLT |
| 2 | `rkernel.mar` | I_CTRL_C_HNDLR changes the PC in the AST argument list (16 bytes in) when the frame is the AST's own, so the AST ends through `$ASTEXIT` | `tests/interactive/ctrlc3.tcl` |
| 3 | `rkernel.mar` | the terminal IOSB is a new quadword cell, TT_IOSB, so NLEN keeps `$TRNLOG`'s length | F03-IOSB, F03-TTIOSB |
| 4 | `rkernel.mar` | I_COMPILE refuses a word when less than a line plus 16 bytes is left in the compile buffer ("Compile buffer full"). The buffer stays 400 hex bytes | F04-COMPBUF |
| 5 | `rkernel.mar` | DIGIT accumulates with EMUL and sets U_OVF when the high longword is non-zero. ICOMPILE refuses such an integer ("Number too large") | F05-LITOVF |
| 6 | `rkernel.mar` | I_DISP_TO_R11 checks the CVTLW ("Data out of range"). I_ENTER refuses a definition past K_END ("Code space full.") or one whose header would reach the kernel ("Dictionary full."). Since Phase 7, a call out of `W^` range is compiled with `L^` (see below) | F06-CODE, F06-DATAWIN, F06-DICT |
| 7 | `rkernel.mar` | SYSERR prints the status with `$PUTMSG` and jumps to ABORT, instead of LIB$STOP. The opens and CLOSE go through it, and a missing LOAD file gives back its input-file slot | F07-LOAD |
| 8 | `rms.mar` | in batch, output is collected in `rmsbuf` and `$PUT` a line at a time. `_rmsflush` is called by the handler, by SYSERR, by GET_STRING and by an exit handler | F08-BATCH |
| 9 | `tyio.mar` | the remote line names its output device, checks the `$ASSIGN`, passes R11 as astprm, and `rmast` no longer calls LIB$SIGNAL | F09-REMOTE |
| 10 | `ss.mar` | GETCMD calls LIB$GET_FOREIGN into its own buffer | F10-TAIL, the suite's `.dcl` tests |
| 12 | `rdef` | MOD and `/MOD` sign-extend the dividend, so `-7 3 MOD` is −1. `#` keeps an unsigned EDIV of its own, so `I=` and `<#>` print as before | F12-MOD |
| 14 | `rkernel.mar` | EQ_SGN pushes its `-` with MOVB, not MOVL, so no NULs follow it | F14-EQSGN |
| 15 | `rdef` | DGE compares the low longwords unsigned | F15-DGE |
| 16 | `float` | `.FLIP` moves quadwords | F16-FLIP |
| 17, 18, 19 | `rkernel.mar`, `crtl.mar` | the condition handler prints the condition with `$PUTMSG`, with the true PC and its own severity. A condition raised inside a call (MTH$, LIB$SIGNAL) is unwound to STOIC's frame, and ERROR_PC is set to where STOIC called out. `.SQRT` of a negative number now gives the MTH$ message and returns to the prompt | F17-MTH, F18-SQRT, F19-PC |
| 20 | `rdef` | GETJPI's comment says what it leaves (SYSERR takes the completion code) | (comment only) |
| 22 | `rkernel.mar`, `rdef` | the kernel grows P0 to 400000 before `$EXPREG`ing its regions (`fix_p0`), so USER_DATA is 402200 on any layout. BRANCH compiles a displacement from R11 | F22-BRANCH; `tests/image/` e-pat |
| 23 | `image` | `.IMAGE` refuses when `U_IFI @` is not 0, that is, inside a LOAD | F23-IMAGELOAD |
| 24 | `rkernel.mar` | console read errors are counted in a new cell, CONSOLE_ERRS. The third error in a row ends STOIC; a good read resets the count | F24-CONERR |
| 25 | `rkernel.mar` | the console is opened with `$OPEN` FAC=GET, so `DEFINE/USER SYS$INPUT file` reads console lines from the file | F25-CONFILE |
| 26 | `image` | FIX_DZRO records the region when its growth reaches the DZRO's page count, and `.IMAGE` refuses before FCREATE | F26-DZRO |
| 27 | `rkernel.mar` | the handler clears the PSL's FPD bit before resuming at ABORT | F04-COMPBUF (one ACCVIO and back to the prompt, where the shipped exe loops on OPCDEC) |
| 28 | `image` | KERNEL_MATCH compares HEAD0's code ISD with memory, block by block, and `.IMAGE` refuses on a mismatch | F28-HEAD0 |
| 29 | `rdef` | `I_DATE_ERROR` is installed in DATE_ERROR, and its message ends with CR | F29-DATE |
| 30 | (22) | the fixed data address keeps obuf's `O.BUFSTRT` constant right in RED.EXE | `tests/red/patched/` r0 and the rest; `tests/image/` e-pat |
| 31 | `red/red` | while RED runs, ABORT is RED_ABORT. It restores the terminal and buffering, then jumps to the old ABORT | `tests/red/r10-fault`, `r10b-bufoff` |
| 32 | `red/kbd` | `ASCII 6 RESET_MODE` | the raw logs in `tests/red/patched/` |
| 33 | `red/eb` | C.UP_ARROW is `1+ C.L-`: the start of the previous line from anywhere in the line | `tests/red/r4-keys`, `r11-uptop` |
| 34 | `red/cli`, `red/clihirez` | C.@K and C.@N do `S.CUP FLUSH` after DRAW_DIVIDER | `tests/red/r8-input` |
| 37 | `float` | `.+ROT` and `.-ROT` save their value with MOVQ | F37-ROT |
| 38 | `float` | `16 'F_STRING SVARIABLE` | F38-FSTRING |
| 39 | `rkernel.mar` | FLOAT_TO_STRING checks FS against its base, and the outer loop checks it after each line ("Float stack empty.") | F39-FSUNDER |
| 40 | `rkernel.mar` | `>` refuses to pop the last branch ("Vocabulary stack empty.", as in `stoic.mem`) | F40-POP |
| 41 | `ss.mar` | GETCMD limits the tail to LINE_BUFFER's size. A longer tail gives `%LIB-W-INPSTRTRU` and an empty line | F10-TAIL |
| 42 | `image` | NOCREF reads and writes the header with block I/O, after INIT_FRABS | F42-NOCREF (not run installed: the rules here forbid INSTALL) |
| 43 | `rdef` | BPUSH tests with `GE`, so the low limit is the last byte used | F43-BPUSH |
| 44 | `float` | `.PUT` gives "Floating point output conversion error." at the end of the area | F44-FPUT |
| 45 | `rdef` | BPUSH and `#A` abort with `ABORT @ JMP @(P)+` | F45-ABORT |
| 46 | `rdef` | SEARCH_STRING groups the starting places; every later group is FFFF bytes | F46-SEARCH |
| 47 | `float` | `.SELECT` tests with `.LTZ` | F47-FZERO |
| 48 | `float` | `.#`, `.#>` and `.E#>` use 10 and `ASCII 0`, not RADIX and `#A` | F48-FRADIX |
| 49 | `cli`, `clihirez` | C.[ allows 24 levels (`18 GT_IF`), and CLEAR_L_STACK sets C.LOOP_COUNT to 0 | `tests/red/r12-bounds.tcl` (nest24, nest25, nest33, nest24-search, open30) |

`red/dyna` also changes: D.DISPLINE and D.DISP (the buffer table) print
the buffer origins 8 wide, not 6, since the data region is now at 400000.

### Not fixed

- **11** (IMAGE's assumptions) is covered by 26 and 28, which check the
  two things that can go wrong.
- **21** (pre-V4 IMAGE output gives BADISD): there is nothing to fix in
  the sources. A rebuilt exe runs.
- **13** (the comparison sense), **35** (`` `C `` replies) and **36**
  (smaller RED differences): rdef, RED and every use in the sources
  depend on the code's behaviour, so the manual is corrected instead
  (`errata.md`).

## Behaviour that differs from the shipped exes

The suite expectations in `tests/patched/` differ from the shipped ones
only in these ways:

- **Addresses.** The data region is at 402200 (22). The kernel code is
  longer, so code addresses are higher, and new cells make the data
  section a page longer. RED's buffer table shows origins like 403E8D
  (`tests/red/patched/r3-buffers`).
- **Messages.**
  - Faults print through `$PUTMSG` with their own severity (`-F-` for
    ACCVIO, where the shipped exe said `-W-`) and the true PC (17–19).
  - A missing file prints an RMS message and ends the line, where the
    shipped exe exited (7).
  - New compile errors: "invalid floating-point literal", "Number too
    large", "Compile buffer full", "Data out of range", "Code space full.", "Dictionary full.", "Float stack empty."
    and "Vocabulary stack empty." (1, 4, 5, 6, 39, 40).
- **Values.**
  - `=` has no NULs (14).
  - MOD and `/MOD` are signed (12).
  - DGE (15), `.FLIP` (16), and `.+ROT` and `.-ROT` (37) are right.
- **Order of tests.** `tests/06-numio` runs its HEX FLT and BIG lines
  before the lowercase line, because a compile error now ends the LOAD
  file (1, 5).
- **Batch output** is a record per line (8). **CTRL/C** works every time
  (2). **The console** can be a file (25).
- **RED.** The up arrow (33), the divider after `@K` and `@N` (34), the
  KBD escape (32), and the terminal after a fault (31). Otherwise RED's
  screens are as before, apart from addresses and timestamps.

Phase 6's batch outcomes in `PLAN.md` give the detail of each step.

## Phase 7: the code window

Phase 7 (`PLAN.md`) removes the 64 KB code limit of defect 6.

| File | Change |
|---|---|
| `rkernel.mar`, `crtl.mar`, `ttio.mar`, `ss.mar` | the `header` and `nullhead` macros store the code displacement as a longword |
| `rkernel.mar` | I_JUMP_TO_ME compiles `JSB W^disp(R8)` when the displacement fits in a word and `JSB L^disp(R8)` when not, so "Code out of range" is gone. I_COMPILE reads the displacement with MOVL. I_ENTER writes a longword, counts 16 bytes of header, and checks the code end against K_END |
| `extend.mar` | KERNEL is padded to 40000 bytes and DICTIONARY to 20000, so K_START is 2FE00. K_END is 6FF2D, a page below the psect's end (k_top, 7012D) |
| `rkernel.mar` | the startup remaps the code region to k_top, so the spare page is mapped; "Dictionary full." compares with R8−8200, a page below the kernel code |
| `rdef` | CODE_COUNT and FORGET read a longword displacement |

**Tests:** `tests/fix/F06-CODE` defines words on both sides of R8+8000
and at 5FF00, calls across the boundary both ways, FORGETs a module past
it, and gets "Code space full." at K_END. `tests/image/` group `g` IMAGEs
an exe with code past the old window and runs it. `widen.sto` now places
its new DZRO section after the fixup ISD, since the code ISD reaches VPN
200. The suite, `--fix` and image expectations changed only in addresses
and in IMAGE's DZRO page counts.

The spare pages let IMAGE write an exe whose code or dictionary is
full: rounded up to a page, the region still leaves a page of its
demand-zero section (`tests/big/runfill`).

Room left: about 231 KB of code in STOIC.EXE and 205 KB in RED.EXE. The
dictionary has 105.5 KB and 94 KB (`image.md`).
