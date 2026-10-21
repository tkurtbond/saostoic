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
| `notes/` | Working design reports: `kernel-design.md` (the MACRO kernel) and `stoic-level-design.md` (rdef, IMAGE, FLOAT, RED). They are drafts written from reading the code. Claims marked unverified must be tested before they go into final docs. |

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

- `tools/stoic-run [-x exe] [-f file]... file.sto...` LOADs each file in a
  fresh STOIC on the VAX and prints STOIC's output.
- `tools/stoic-suite [--update] [name...]` runs `tests/*.sto` in one job and
  diffs each against `tests/*.expected`.
- `tools/vax-do [-t file] proc.com [file...]` runs any DCL procedure in
  `[.WORK]`.

STOIC writes to SYS$COMMAND, the terminal, not SYS$OUTPUT. Under `/OUTPUT`
its output therefore lands in the telnet session, not in the log, and the
tools capture it there with `vax-do -t`. In batch, every TYO becomes a
separate record (defect 8), so don't use batch.

Prefer these over typing into the user's tmux pane. Use the pane only for
interactive checks the user has okayed, such as RED, CTRL/C or terminal
modes.

## Design in brief

Details and `file:line` citations are in `notes/`.

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
- **Errors.** The condition handler rewrites the signal PC to `ABORT` and
  resignals as a warning, so faults print a message and return to the
  prompt. CTRL/C works by patching the AST frame's return PC to ABORT.
- **Conventions.** The default radix is **hex**. `=` prints with a leading
  space. Any odd value is true; the canonical flags are −1 and 0. `-` and
  `/` compute B−A and B/A, where A is the top of stack.
- **Files.** There are 8 RMS channels: 0 console, 1–3 LOAD nesting, 4
  messages, 5 keyed, 6 block, 7 UFO/map. End of file in a LOAD file runs
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
  code and every use in the sources agree; the manual is wrong.
- `1 2 - =` gives −1, so `-` is B−A.
- **MOD treats a negative dividend as unsigned.** `7 2 MOD =` and
  `-7 2 MOD =` both give 1, and `-7 3 MOD =` gives 0: 2³²−7 is divisible
  by 3. The high longword of the EDIV dividend is zero, as the kernel
  report suspected (test `00-mod`).
- STOIC output goes to SYS$COMMAND. Under SUBMIT, every TYO is its own log
  record.

## Known or suspected defects to verify

From reading the code; each needs a test:

1. DIGIT treats any character above `Z` as a decimal point, so lowercase
   undefined words in LOAD files (which are not uppercased) compile silently
   as junk floats (`rkernel.mar:630-667`).
2. The CTRL/C handler bypasses `$ASTEXIT`, which may block later ASTs,
   including a second ^C.
3. The terminal IOSB at `ttchan+2(r11)` overwrites the next user-table cell.
4. The compile buffer has no overflow check.
5. Integer literal overflow is not checked. A float typed in hex radix is
   read as decimal.
6. Nothing checks that code and data stay within the 16-bit displacement
   windows from R8 and R11.
7. `.errstop` uses LIB$STOP, which cannot continue, so it probably exits
   STOIC rather than returning to the prompt.
8. In batch, every TYO becomes its own `$PUT` record. **Confirmed.**
9. `tyio.mar` remote-line code (`_remstart`, `rmast`): bad descriptor,
   LIB$SIGNAL called without an argument.
10. `GETCMD` uses the obsolete CLI callback. It works on 5.5-2 (the command
    tail is executed), but it is fragile.
11. IMAGE's single-block-header and ISD-layout assumptions. SAVE/XLOAD
    depend on a deterministic P0 layout.

## Plan

The detailed test and documentation plan is in **`PLAN.md`**. It has six
phases: 0 tooling, 1 characterizing the shipped binaries, 2 rebuilding from
source, 3 IMAGE, 4 RED and 5 documentation. Keep its status table up to
date.

## Working conventions

- Treat `notes/` as hypotheses and `doc/` as verified results. Don't promote
  a claim from `notes/` to `doc/` until a test or a cited source line backs
  it.
- Put any change to STOIC sources in `[.WORK]` and in a separate `patched/`
  tree here, never in `saostoic-text/` or the reference `[.SAOSTOIC]` files.
- Commit to git as work progresses. Don't commit fetched VAX binaries or
  logs that contain session noise unless they are deliberate test evidence.
- VMS file names and DCL are case-insensitive, and the VAX shows them in
  uppercase. STOIC console input is uppercased by RMS, but **LOAD files are
  not**, so write test files in uppercase.
