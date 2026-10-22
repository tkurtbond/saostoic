# AGENTS.md — SAO STOIC for VAX/VMS

This tree holds SAO STOIC, a FORTH-like language for VAX/VMS written by Roger
Hauck and Jonathan Mark at the Smithsonian Astrophysical Observatory
(1980–85), together with RED, a screen editor written in STOIC, and an older
GM Research variant of the kernel. The goal of the work here is to **test the
system on a real (SIMH) VAX and document its design**.

## Tree layout

| Path | What it is |
|---|---|
| `saostoic-text/` | Clean Unix-text copies of all 69 VMS text files, fetched from the VAX by ASCII FTP. Names are lowercased, and files with no type lose the trailing dot (`stoic/rdef`, `red/cli`). `.EXE`, `.OBJ`, `.BAK` and `.DIR` files were not fetched. **Read this tree.** |
| `saostoic-text/kernel/` | MACRO-32 kernel: `rkernel.mar` (compiler, dictionary, outer loop), `rms.mar`, `tyio.mar`, `ss.mar`, `ttio.mar`, `crtl.mar`, `controlc.mar`, `dtinit.mar`, `extend.mar`, the build `.com` files, `rkernel.opt` and `rkernel.map`. `ss.src` is a listing, not source; it will not assemble. |
| `saostoic-text/stoic/` | The STOIC layer: `rdef` (the standard word set), `image`, `float`, `obuf`, `vt100`, `stoic.cre`, and the manual `stoic.mem`/`stoic.rno`. |
| `saostoic-text/red/` | RED: `err dyna e window edv eb command immed cli kbd red`, `red.cre`, `hirez.cre`, `red.mem`. |
| `saostoic-text/gm/` | GM variant: `kernel.mar`, `ss.mar`, `float.sto`, and `newstoic.mem` (the GM "Detailed Guide to VAX/VMS STOIC", 19 May 1982). |
| `doc/` | The verified documentation (Phase 5). Start at `doc/README.md`; `doc/defects.md` lists all 49 defects, `doc/patches.md` the Phase 6 fixes and `doc/errata.md` the manual corrections. |
| `patched/` | The Phase 6 sources: a full copy of the VMS tree with the fixes. On the VAX it is `[.WORK.PATCHED...]`. |
| `cmpfix/` | Phase 8: `patched/` with the comparison words as in the manual and CP/M STOIC (defect 13), and every use swapped by `tools/cmp-swap`. On the VAX it is `[.WORK.CMPFIX...]`; see `doc/cmpfix.md`. |
| `notes/` | The first design drafts (`kernel-design.md`, `stoic-level-design.md`), written from reading the code. Historical: `doc/` supersedes them. |

The authoritative copy of every file, binaries included, is on the VAX in
`DUA1:[USERS.CLAUDE.SAOSTOIC...]`.

The tree is under git. The original Unix extraction (`saostoic/`, with broken
binaries and record-length bytes mixed into its text files) has been deleted;
fetch any file that is missing here from the VAX.

## The VAX

- SIMH `microvax3900` at **192.168.2.20**, running VAX/VMS V5.5-2H4 with UCX TCP/IP.
- Account **CLAUDE**, home `DUA1:[USERS.CLAUDE]`. STOIC is in
  `[.SAOSTOIC]`, with subdirectories `KERNEL`, `STOIC`, `RED` and `GM`.
- Credentials are in `~/.netrc-claude-vax` (netrc format).

### Rules

1. **Never display the password.** Don't `cat` the netrc file, don't
   echo it, don't put it on a command line where `ps` or a log could show it,
   and don't type it into tmux. Tools must read it from the netrc file
   themselves: `curl --netrc-file`, or expect with `log_user 0` during login.
2. **Write only inside `DUA1:[USERS.CLAUDE.WORK...]`.** Create every new
   file there, binaries included. Do not write anywhere else (including
   `[.SAOSTOIC]` and the rest of `[USERS.CLAUDE]`), `INSTALL` anything, or
   change system logicals or SYSGEN. `install.com` is documentation only.
3. **Never type into the SIMH console window.** Type DCL only into the
   telnet session in **tmux window 2**, which is logged in as CLAUDE. Before
   typing, capture the pane and check that it shows a CLAUDE DCL prompt; if
   it doesn't, stop and ask the user.
4. **Experiment in the scratch copy `[.WORK]`.** Run builds, IMAGE tests and
   anything else that writes files there, never in `[.SAOSTOIC]`. The shipped `STOIC.EXE` and `RED.EXE` are the reference
   binaries.
5. **Be gentle with UCX FTP.** INETACP has crashed under many FTP logins
   (bugcheck SSRVEXCEPT). Batch transfers into one session, avoid running
   sessions in parallel, and keep deletes in one session under about 100.
   If FTP stops answering, tell the user; don't retry in a loop.
   Each FTP login writes a `UCX$FTPSERVER.LOG` in SYS$LOGIN; the user has
   limited it to three versions, so these files no longer pile up.

### FTP

FTP works **only in active mode**. Send text in **ASCII mode**, or VMS
stores it as fixed 512-byte records. URL-encode the directory brackets:

```sh
# fetch
curl -sS --netrc-file ~/.netrc-claude-vax -P - --use-ascii \
  "ftp://192.168.2.20/%5B.SAOSTOIC.STOIC%5D/RDEF."
# list
curl -sS --netrc-file ~/.netrc-claude-vax -P - \
  "ftp://192.168.2.20/%5B.SAOSTOIC.STOIC%5D/"
# upload
curl -sS --netrc-file ~/.netrc-claude-vax -P - --use-ascii \
  -T test.sto "ftp://192.168.2.20/%5B.WORK%5D/TEST.STO"
```

Transfer binaries (`.EXE`) in image mode, without `--use-ascii`.

### Running things

To start, the foreign-command symbol (already defined in the CLAUDE session):

```
$ STOIC :== $DUA1:[USERS.CLAUDE.SAOSTOIC.STOIC]STOIC.EXE
$ STOIC DECIMAL 2 3 + = CR ;F
 5
```

The DCL command tail is compiled and run as one STOIC line, and `;F` at
console level exits to DCL. That makes one-liners easy to script.

For anything longer, put the STOIC source in a file and `'FILE.STO LOAD`
it.

For unattended runs, use `tools/` (see `tools/README.md`):

- `tools/stoic-run [-x exe] [-r exe] [-f file]... file...` runs each file in a
  fresh STOIC on the VAX and prints STOIC's output. A `.sto` is LOADed, a
  `.con` is typed as console lines, and a `.dcl` is DCL commands (for
  command tails; `-r` names the RED behind `RED` and `CALC`).
- `tools/stoic-suite [--update] [name...]` runs `tests/*.sto`, `*.con` and
  `*.dcl` in one job and diffs each against `tests/*.expected`.
- `tools/vax-interact check.tcl...` runs interactive checks (CTRL/C, TYI,
  terminal modes) over a fresh telnet session and logs each to
  `tests/interactive/`.
- `tools/vax-do [-t file] proc.com [file...]` runs any DCL procedure in
  `[.WORK]`.
- `tools/red-drive [-o dir] script.tcl...` drives RED from a key script
  over a fresh telnet session and writes `.raw` and `.scr` (the screens,
  via pyte) to `tests/red/`. Set `STOIC_RED` to the rebuilt RED.EXE.
- `tools/word-index [--list|--md]` indexes every word definition in the
  sources and cross-checks it against INVENTORY; `--md` makes
  `doc/words.md`.
- `tools/patched-push`, `tools/patched-build.com` and
  `tools/patched-suite [--fix] [--shipped]` push, build and test the
  patched tree (`doc/build.md`, "The patched build"). `tests/fix/` has a
  test for each defect. With `STOIC_TREE=cmpfix` they (and
  `tests/image/run`, `tests/big/run`) work on the cmpfix tree instead.

STOIC writes to SYS$COMMAND, the terminal, not SYS$OUTPUT. Under `/OUTPUT`
its output therefore lands in the telnet session, not in the log, and the
tools capture it there with `vax-do -t`. In batch, every TYO becomes a
separate record (defect 8), so don't use batch.

Prefer these over typing into the user's tmux pane. Use the pane only for
interactive checks the user has okayed and wants to watch, such as RED.

## Design in brief

Details and `file:line` citations are in `doc/` (start at `doc/README.md`).

- **Native subroutine threading.** There is no inner interpreter. Each word
  is VAX code ending in RSB. A call compiles to `JSB W^disp(R8)`, an integer
  literal to `MOVL #n,-(R10)`, and a float literal to `MOVD #d,-(R7)`.
- **Line-at-a-time compile-and-go.** Every input line is compiled into a
  2-page buffer, gets an RSB appended, and is then executed. `CHECK` counts
  open structures. While it is non-zero, lines accumulate and the prompt
  shows the depth. There is no STATE variable; only IMMEDIATE words run at
  compile time.
- **Definitions.** The name comes first: `'NAME : body ;`. A definition takes
  effect when its line executes, so inside a redefinition `NAME` still means
  the old word. `obuf` and IMAGE rely on this.
- **Registers.**

  | Register | Use |
  |---|---|
  | R11 | user table and data, biased by 0x8000 |
  | R10 | parameter stack P |
  | R9 | loop stack L |
  | R8 | code base, biased by 0x8000 |
  | R7 | float stack FS, D_floating |
  | SP | return stack |

- **Dictionary.** Headers live in a separate `DICTIONARY` psect. Links are
  offsets, and chains end with `0x7fffffff`. A header records the code
  length and a 16-bit code displacement from R8. Lookup is a linear search
  of the branch (vocabulary) stack: STOIC<, ASSEMBLER<, TTIO<, FLOAT<,
  IORB< and RED<. Lookup attributes are JUMP_TO_ME, IMMEDIATE, COMPILE_BYTE
  (assembler opcodes), PUSH_THIS_WORD (constants, fetched at run time),
  PUSH_VOCAB and DISP_TO_R11 (user variables).
- **Memory.** Stacks, the compile buffer, the channel blocks and the data
  region are `$EXPREG`'d at startup, each with a no-access moat page in
  front. Overflow is caught by ACCVIO, not by checks.
- **Errors.** The condition handler rewrites the signal PC to `ABORT @` and
  resignals as a warning, so faults print a message and return to the
  prompt. rdef sets ABORT to ERROR_TRACE, which prints the line, the word
  and a traceback (WHAT of ERROR_PC, then of the return stack). So every
  message shows ERROR_TRACE's PC; the first traceback line is the real one.
  - A **compile error** (an undefined word) calls LOAD_RESET, which ends
    every LOAD under way. A **run-time error** ends only its line; a LOAD
    file carries on.
  - LOAD or OPEN of a missing file goes through `.errstop` to LIB$STOP, and
    STOIC exits (defect 7).
  - CTRL/C works by patching the AST frame's return PC to ABORT, so only the
    first ^C works (defect 2).
- **Conventions.** The default radix is **hex**. `=` prints with a leading
  space. Any odd value is true; the canonical flags are −1 and 0. `-` and
  `/` compute B−A and B/A, where A is the top of stack.
  - A line is compiled in full before it runs, so `HEX`, `DECIMAL`, a branch
    word like `TV<`, or a definition takes effect from the **next** line.
  - Strings: WORD skips a leading run of `"`, scans to the next `"` and the
    run of quotes there, and SLITERAL drops the first and last characters.
    So `""AB"` is `"AB`, `"CD""` is `CD"`, and `""` is not empty (it runs to
    the next quote). A string pushes one address; `COUNT` gives address and
    count.
  - Float literals take digits of the current radix and are read as decimal:
    `1.E30` works only in HEX.
- **Files.** There are 8 RMS channels: 0 console, 1–3 LOAD nesting (a 4th
  level gives "Input file table overflow."), 4 messages, 5 keyed (a plain
  PUT gives RMS-W-RAC; use 1–3 for sequential files), 6 block (SAVE/XLOAD),
  7 UFO/map. End of file in a LOAD file runs
  `;F`. End of file on the console exits STOIC.
- **Startup.** The kernel calls `@USER_INIT`. `rdef` installs DEF_INIT,
  which fetches the DCL command tail with `GETCMD` (an old CLI callback) and
  runs it. That is how `RED file` and `CALC expr` work: `RED` and `FLODEF`
  are IMMEDIATE.
- **Build.**
  1. `stobuild.com [MAC]` runs `assign.com`.
  2. `kermac.com` assembles the kernel (only with `MAC`).
  3. `kerlink.com` links `RKERNEL.EXE` and copies it to `HEAD0.EXE`.
  4. `stoic.cre` runs RKERNEL, LOADs rdef, image, float, obuf and vt100,
     then `'STOIC.EXE IMAGE`.
  5. `red.cre` loads the RED modules on top, then `'RED.EXE IMAGE`.

  `ORANGE.CRE`, the INFOTON variant, is referenced but missing.
- **IMAGE** (`stoic/image`) makes executables without a linker:
  1. It reads VBN 1 of `SAO$KERNEL:HEAD0.EXE`.
  2. It finds the three resident ISDs (data, dictionary, code) by VPN.
  3. It marks them no-write and shrinks the demand-zero ISDs that follow.
  4. It writes the header plus live memory with keyed RMS PUTs.

  It assumes a one-block header, a fixed ISD layout, and a P0 layout
  identical to HEAD0's. VMS V4 broke shareable IMAGE output (BADISD); the
  fix, `IMAGE_WRT`, is built into `image`.
- **RED.** A buffer-gap editor with 10 buffers (X0–X9), a TECO-like command
  line (`cli`), the VT100 keypad (`kbd`), scroll regions (`vt100`) and output
  buffering (`obuf`).
- **GM variant.** An older, simpler design:
  - static memory;
  - headers inline with the code;
  - no float stack;
  - number input through FOR$CNV_IN_*;
  - no SAVE/XLOAD or IMAGE.

## Facts already established on the VAX

- The shipped `STOIC.EXE` runs on V5.5-2H4.
  `STOIC DECIMAL 5 0 DO I = LOOP CR ;F` gives ` 0 1 2 3 4`.
- **Comparisons are the reverse of `stoic.mem`.** `1 2 GT =` gives −1 and
  `2 1 GT =` gives 0. `GT` is true when the *top* of stack is greater. The
  code and every use in the sources agree; the manual is wrong. CP/M STOIC
  (tmux window 4) does what the manual says, so the VAX reversed the
  intended sense: `CMPL (P)+ (P)+` compares A with B (`doc/cpm-compare.md`).
- `1 2 - =` gives −1, so `-` is B−A.
- **MOD treats a negative dividend as unsigned.** `7 2 MOD =` and
  `-7 2 MOD =` both give 1, and `-7 3 MOD =` gives 0: 2³²−7 is divisible
  by 3. The high longword of the EDIV dividend is zero, as the kernel
  report suspected (test `00-mod`).
- STOIC output goes to SYS$COMMAND. Under SUBMIT, every TYO is its own log
  record.
- `/MOD` is unsigned too: `-42 6 I=` prints `967254`. Integer literals wrap
  mod 2³².
- `=` prints a negative number as `-`, three NULs, then the digits.
- `.^` computes B^A: `2. 10. .^` gives 1024. OTS$POWDD agrees.
- SAVE and XLOAD round-trip in the same exe. CALC works through the command
  tail. REVISION of the shipped exe is `9-SEP-1985 21:17:31.34`.
- The shipped exe has 964 words (`doc/data/stoic-inventory.txt`, INVENTORY).
- Phase 1's suite and interactive checks are in `tests/`; what each test
  settled is in the defect checklist in `PLAN.md`.
- **The sources rebuild cleanly on V5.5-2H4** (`doc/build.md`): no
  diagnostics, no changes, and the same sizes for every section IMAGE
  writes. The kernel code is 8 bytes longer (V5's `$ASSIGN_S`), and the
  `$EXPREG`'d regions sit 4F800 lower, because a V5 link uses LIBRTL and
  friends in place of VMSRTL. Otherwise the suite output is the same.
- The shipped `REDHIREZ.EXE` (1983) fails with BADISD; a rebuilt one runs.
- **The work tree holds two versions** of every built file since Phase 2:
  `;1` is the shipped copy and `;2` the rebuild. A spec without a version
  gets the rebuild, including `SAO$KERNEL:HEAD0.EXE` (read by IMAGE) and the
  `STOIC`, `RED` and `CALC` of `work-assign.com`. `tools/stoic-run` sets
  those symbols from `-x` and `-r`, which default to the shipped
  `[.SAOSTOIC...]` binaries.
- **IMAGE works on V5.5-2** (`doc/image.md`, `tests/image/run`), with the
  shipped and the rebuilt STOIC, two layers deep. `0 .IMAGE` gives BADISD.
  A child exe inherits its parent's data region as it is: radix,
  LINE_BUFFER and the LOAD level (so run IMAGE from the console, not from
  a LOAD file). XLOAD refuses a save file made by another exe.
- **`IORB<` is unusable in the shipped STOIC.EXE** (defect 22): it pushes
  the 1985 address of its cell, and after that every line faults. Use
  `USER_DATA @ 491 + V_PUSH` instead (`tests/image/imgutil.sto`).
- STOIC can't read its console from a disk file: with `DEFINE/USER
  SYS$INPUT file` it loops on RMS-W-FAC (defect 25). Use DCL data lines or
  the tools.
- **The shipped `RED.EXE` doesn't run on V5.5-2** (defect 30). It ACCVIOs
  at 7B173 before drawing, because obuf's `O.BUFSTRT` is a constant frozen
  at the 1985 data address. It leaves the terminal as Device_Type Unknown;
  fix that with `SET TERMINAL/DEVICE=VT100`. **Use the rebuilt
  `[.WORK.SAOSTOIC.RED]RED.EXE`.** With it every command in `red.mem`
  works, apart from the differences in `doc/red.md`, and SHOW TERMINAL is
  unchanged after a normal exit.
- In RED, an error message locks the keyboard until RETURN, and a command
  line runs only after two LFs.

## Known or suspected defects

Suspected from reading the code. Results are in `PLAN.md`'s defect
checklist, which also lists defects 12–20, found in Phase 1 (`=` NULs, DGE,
`.FLIP`, unreported MTH$ errors, `.SQRT` of a negative ending STOIC, and
others). Confirmed: 1–8, and 9 in Phase 6; 11 is characterized.
Phase 2 added 21 (the shipped REDHIREZ's BADISD), and Phase 3 added 22–29:
BRANCH's absolute address, IMAGE in a LOAD, endless console-error and FPD
fault loops, the PUT-only console, FIX_DZRO underflow, an unchecked HEAD0,
and rdef's unused I_DATE_ERROR. Phase 4 added 30–36 for RED: the shipped
exe's ACCVIO and the terminal it leaves, a malformed escape, the up arrow,
`@K`/`@N` drawing on the divider, the `` `C `` replies, and smaller
differences from the manual (`doc/red.md`). Phase 5 added 37–40:
`.+ROT`/`.-ROT` losing half a value, `F->S` overrunning `F_STRING`,
unchecked float-stack underflow, and `>` emptying the branch stack.
Phase 6 added 41, a long DCL command tail overrunning LINE_BUFFER, and 42,
NOCREF never working. Each has a repro, cause and fix in `doc/defects.md`.

**Phase 6 fixed 37 of the 42 in the patched build** (`doc/patches.md`):
every one apart from 13, 35 and 36, which are corrected in
`doc/errata.md`, and 11 and 21, which are closed. Defects 43–49, found
later (BPUSH's off-by-one, `.PUT`'s missing limit, BPUSH and `#A`
not aborting, SEARCH_STRING's long groups, `-.000`, float output
in a non-decimal radix, and RED's `[` overrunning the loop stack), are
fixed there too. The list below describes
the shipped exes. The patched exes are
`DUA1:[USERS.CLAUDE.WORK.PATCHED.STOIC]STOIC.EXE` and
`[.WORK.PATCHED.RED]RED.EXE`. Their data region is at 402200 on any
layout, so `IORB<` and RED's obuf work. **Phase 7** raised their code
window: headers hold a longword code displacement, a call out of `W^`
range compiles as `JSB L^disp(R8)`, the dictionary is 128 KB and code
runs from K_START 2FE00 to K_END 6FF2D, with a spare page after it (and
one below the kernel code for the dictionary) so that IMAGE works when
either is full. STOIC.EXE has about 231 KB of code and 105 KB of
dictionary free; RED.EXE about 205 KB and 94 KB. **Phase 8** made
`cmpfix/`, the patched build with `GT` `LT` `GE` `LE` (and their `_IF`,
`.` forms and DGE) as in the manual, so defect 13 is fixed there; its exes
are in `[.WORK.CMPFIX.STOIC]` and `[.WORK.CMPFIX.RED]`.

1. DIGIT treats any character above `Z` as a decimal point, so lowercase
   undefined words in LOAD files (which are not uppercased) compile silently
   as junk floats (`rkernel.mar:630-667`).
2. The CTRL/C handler bypasses `$ASTEXIT`, so the process stays at AST
   level and a second ^C is never delivered.
3. The terminal IOSB at `ttchan+2(r11)` overwrites the next user-table cell.
4. The compile buffer has no overflow check.
5. Integer literal overflow is not checked. A float typed in hex radix is
   read as decimal.
6. Nothing checks that code and data stay within the 16-bit displacement
   windows from R8 and R11.
7. `.errstop` uses LIB$STOP, which cannot continue, so it exits STOIC
   rather than returning to the prompt.
8. In batch, every TYO becomes its own `$PUT` record. **Confirmed.**
9. `tyio.mar` remote-line code (`_remstart`, `rmast`): bad descriptor,
   LIB$SIGNAL called without an argument.
10. `GETCMD` uses the obsolete CLI callback. It works on 5.5-2 (the command
    tail is executed), but it is fragile.
11. IMAGE's single-block-header and ISD-layout assumptions. SAVE/XLOAD
    depend on a deterministic P0 layout. Both hold on one system; IMAGE
    does not check HEAD0 or the size of the demand-zero sections.

## Plan

The detailed test and documentation plan is in **`PLAN.md`**. It has nine
phases: 0 tooling, 1 characterizing the shipped binaries, 2 rebuilding from
source, 3 IMAGE, 4 RED, 5 documentation, 6 fixes (Batches A–H), 7
raising the code window and 8 the comparisons as in the manual (cmpfix). Keep its status table up to date.

## Working conventions

- `doc/` holds verified results; `notes/` is historical. A new claim goes
  into `doc/` only with a test or a cited source line behind it.
- Put any change to STOIC sources in `[.WORK]` and in a separate `patched/`
  tree here, never in `saostoic-text/` or the reference `[.SAOSTOIC]` files.
- Commit to git as work progresses. Don't commit fetched VAX binaries or
  logs that contain session noise unless they are deliberate test evidence.
- VMS file names and DCL are case-insensitive, and the VAX shows them in
  uppercase. STOIC console input is uppercased by RMS, but **LOAD files are
  not**, so write test files in uppercase.
