# PLAN.md: testing and documenting SAO STOIC

This plan is how we test SAO STOIC on the SIMH VAX and document its
design. `AGENTS.md` covers access rules, tree layout and conventions; read it
first. `notes/` holds the design reports this plan is drawn from, and the
claims in them are still unverified.

Each phase lists its goal, its steps, the files it produces, and when it
is done. Phases 0 and 1 come first. Phases 2–4 can run in any order once
Phase 1 passes. Phase 5 is written gradually as results come in.

## Status

| Phase | State |
|---|---|
| 0 Tooling | done (see "Phase 0 outcome"); `tests/00-*` pass |
| 1 Characterize shipped binaries | suite `tests/00`–`15` (18 files) passes; interactive checks in `tests/interactive/`; INVENTORY in `doc/data/`; `tests/README.md`, `doc/defects.md` |
| 2 Rebuild from source | done (see "Phase 2 outcome"; `doc/build.md`) |
| 3 IMAGE | done (see "Phase 3 outcome"; `doc/image.md`, `tests/image/`) |
| 4 RED | done (see "Phase 4 outcome"; `doc/red.md`, `tests/red/`) |
| 5 Documentation | done (see "Phase 5 outcome"; `doc/README.md`, `tests/lang/`) |
| 6 Fixes | in progress: Batches A–H done; decisions taken (all as recommended) |

Update this table as work proceeds.

---

## Phase 0: Tooling

**Goal:** be able to run STOIC tests on the VAX unattended and repeatably,
without typing into the user's tmux pane and without exposing the password.

### Steps

1. **Copy and adapt the Peaseblossom tools** from
   `~/Repos/Oberon/Peaseblossom/tools/` into `tools/`:
   - `vax-login.tcl`:
     - read host, user and password from `~/.netrc-claude-vax`;
     - use `log_user 0` until the prompt appears;
     - set the prompt to a fixed string such as `STOICTEST> `.
   - `vax-ftp.tcl`: active mode, ASCII with CRLF handling, retries with
     backoff, and one session per batch of files.
   - `vax-do` and `vax-do.exp`:
     - upload a `.COM` file;
     - run `@NAME/OUTPUT=VAXDO.LOG` over a fresh telnet login;
     - fetch the log;
     - print `$STATUS` and exit non-zero on failure.
   - `vax-lock.sh`: a flock lock per account, e.g.
     `~/.cache/vax-lock-claude`.
   - Every file they upload, and every log or `.COM` they create, must
     go under `[.WORK...]`, never the login directory: upload to
     `%5B.WORK%5D` paths and `SET DEFAULT [.WORK]` before running anything.
   - Strip anything specific to Peaseblossom: Oberon paths, MACRO assembly
     steps, the VAXASM prompt.
2. **Set up `[.WORK]`.** Write a one-time `tools/setup-work.com` that runs:
   ```
   $ CREATE/DIRECTORY [.WORK]
   $ BACKUP [.SAOSTOIC...]*.*;* [.WORK...]*.*;*
   ```
   Also write `tools/work-assign.com`, which defines `SAO$KERNEL`,
   `SAO$STOIC` and `SAO$RED` as process logicals pointing into `[.WORK...]`,
   and the `STOIC`, `RED` and `CALC` symbols. Every test procedure starts
   with `@[.WORK]WORK-ASSIGN` (or its 39-character-safe equivalent).
3. **Write `tools/stoic-run FILE.STO [EXE]`.** It:
   1. uppercases the test file, because LOAD input is not uppercased;
   2. appends `;F` if the file doesn't already end with it;
   3. uploads the file to `[.WORK.TESTS]`;
   4. generates a `.COM` that runs `$ STOIC 'FILE.STO LOAD` (or `$ RUN` a
      named EXE and feeds the LOAD line as SYS$INPUT data);
   5. runs it through `vax-do`;
   6. prints only the STOIC output, with the DCL echo, the
      "Welcome to STOIC" banner and the login noise removed.
4. **Write `tools/stoic-suite [PATTERN]`.**
   - For each `tests/NN-name.sto`, run `stoic-run` and diff the output
     against `tests/NN-name.expected`.
   - Upload all the files and run all the tests in **one** VAX job
     (concatenated into a single `.COM`), then fetch one log and split it on
     marker lines such as `=== NN-name ===`. This keeps FTP logins to two per
     suite run.
   - Print a PASS/FAIL summary.
   - `--update` rewrites the `.expected` files. Use it only after a human
     has reviewed the output.
5. **Find out how output looks in batch.** The kernel switches TYPE/TYO to
   RMS `$PUT` when SYS$OUTPUT is not a terminal, and the report expects one
   record per TYO (defect 8). Run a short test under `/OUTPUT` and look at
   the log. If output is one character per line, either:
   - `LOAD/L` `obuf` and turn on `BUFFER_ON` in a test prelude, so output
     is buffered into lines; or
   - make `stoic-run` rejoin the records (each record would be one TYO);
   - or drive STOIC over telnet under expect instead of with `/OUTPUT`.

   Record the choice and the reason in this file.

### Phase 0 outcome (2026-10-21)

- **Output goes to the terminal.** STOIC writes to SYS$COMMAND, not
  SYS$OUTPUT, so under `@NAME/OUTPUT=VAXDO.LOG` its output appears in the
  telnet session and not in the log. `vax-do -t <file>` captures what the
  procedure writes to the terminal. All the STOIC tools use that.
- **Batch confirms defect 8.** Under SUBMIT every TYO is its own record:
  `2 3 + =` logs ` ` and `5` as two lines, and CR writes a record holding a
  lone carriage return, then blank records. Batch also echoes the input
  lines. So the tools drive STOIC over telnet, the third choice above, and
  don't use batch.
- **Input comes as data lines.** `stoic-run` doesn't put `'FILE.STO LOAD`
  on the DCL command line, where the quote would start symbol substitution.
  It runs STOIC with no tail and gives it `'FILE.STO LOAD` and `;F` as data
  lines of the procedure (SYS$INPUT). Test files are **not** uppercased, so
  that the lowercase defect stays testable; write tests in uppercase.
- **Each test runs in a fresh STOIC.** One job runs them all, with a
  `WRITE SYS$COMMAND "=== name ==="` marker before each.
- **File names.** VMS V5 names have no hyphens. `01-arith.sto` is
  `01_ARITH.STO` on the VAX.
- **The scratch copy** is `[.WORK.SAOSTOIC...]`, a BACKUP of
  `[.SAOSTOIC...]`, not `[.WORK...]` itself, so the tools' own files don't
  mix with the tree. `work-assign.com` points `SAO$KERNEL`, `SAO$STOIC` and
  `SAO$RED` at it. `stoic-run` runs the shipped
  `[.SAOSTOIC.STOIC]STOIC.EXE` unless given `-x`.
- **A side effect we can't avoid.** UCX writes a `UCX$FTPSERVER.LOG` into
  `SYS$LOGIN` for every FTP session. It is outside `[.WORK]`, so the tools
  leave it alone. The user may want to purge it now and then.

### Produces

`tools/vax-login.tcl`, `tools/vax-ftp.tcl`, `tools/vax-do`,
`tools/vax-do.exp`, `tools/vax-lock.sh`, `tools/stoic-run`,
`tools/stoic-suite`, `tools/setup-work.com`, `tools/work-assign.com`, and a
`tools/README.md`.

### Done when

`tools/stoic-suite` runs a two-test smoke suite end to end, reports PASS, and
the password never appears in output, logs or `ps`.

---

## Phase 1: Characterize the shipped binaries

**Goal:** an executable specification of STOIC as it actually behaves. Each
test file covers one area. The `.expected` output comes from real runs, and
each line is reconciled against the source. A disagreement with the manual
is recorded, not "fixed".

Run against `[.SAOSTOIC.STOIC]STOIC.EXE` (copied to `[.WORK.STOIC]`). Tests
are in hex unless they start with `DECIMAL`.

### Test files and key cases

| File | Cases (expected results where known) |
|---|---|
| `01-arith.sto` | `3 4 + =` → 7. `7 3 - =` → 4. `6 2 / =` → 3. `7 3 MOD =` → 1. `7 3 /MOD = =` → 1 2 (remainder on top). **`-7 3 MOD =`** → 0 if the high longword of the EDIV dividend is zero (bug), 2 if floored, −1 if signed. `-7 3 /`. `MINUS`, `ABS`, `MAX`, `MIN`, `2* 4* 2/ 4/`, shifts. Products and quotients that overflow. |
| `02-compare.sto` | `EQ NE GT LT GE LE` on (1,2), (2,1) and (2,2), and on negatives. Every `*_IF` form. Truth from odd values: `3 IF`, `2 IF`. Confirm GT is true when the top is greater. |
| `03-stack.sto` | `DROP DUP 2DROP DDUP SWAP OVER 2OVER +ROT -ROT UNDER FLIP UNDROP 2UNDROP`. Use `[[ ]]` (vt100) or a depth word to check the stack depth afterwards. |
| `04-control.sto` | `IF ELSE THEN` nested. `BEGIN … END`. `BEGIN … IF … REPEAT`. `0 5 DO I = LOOP` → 0 1 2 3 4 (DO takes the limit on top; confirm). `+LOOP` with a step of 2 and a negative step. `I J K` in nested loops. `I'`, `LAST_I`, `EXIT`. `5 ( I = )` → 0 1 2 3 4. The 128-byte branch limit: a long IF body should give a compile error (find which). |
| `05-define.sto` | `'SQ : DUP * ; 9 SQ =` → 51. A redefinition calling the old word: `'SQ : SQ 1+ ; 9 SQ =` → 52. A definition spanning several lines (CHECK). CONSTANT, VARIABLE (check the argument order, rdef:925), ARRAY, SVARIABLE, `,D`. Recursion through `()` and EXEC. IMMEDIATE. |
| `06-numio.sto` | `DECIMAL`/`HEX` round trips. Store 24 in `U_RAD` (radix 36) and check `Z =`. `<# # #S #>` and `#PUT`. `I=`. Integer literal overflow (`FFFFFFFFF`). **The DIGIT defect:** a lowercase `foo` in a LOAD file should compile silently as a float, then check the FS depth. `_` and `[` should behave the same way. |
| `07-strings.sto` | `"abc" MSG` and `'abc MSG`. TYPE with COUNT. `.STREQ`. SEARCH_STRING. MOVE_STRING. SUBSTRING. A string containing spaces. A `%` comment in mid-line. |
| `08-vocab.sto` | Create a branch with `'T< BRANCH`. `T< DEFINITIONS`, define a word, `>`, and check that it is no longer visible. MODULE and FORGET. A `>` that pops the last vocabulary (the GM kernel refuses this; check SAO). |
| `09-asm.sto` | A word defined in the in-line assembler, e.g. `ADDL2 (P)+ (P)` with `RSB`, and its result. Displacement modes `B^(P)` and `@B^(P)`. `'DUPI LOAD` and `"abc" TEST` → 61 62 63. |
| `10-files.sto` | LOAD nested to depth 3 (files `10a`–`10c`). A 4th level should give "Input file table overflow". A compile error in the innermost file, followed by LOAD_RESET back to the console. LIST of a file. Writing and reading a file with FRAB words (WOPEN/PUT/CLOSE, OPEN/GET). |
| `11-errors.sto` | Each of these, followed by `1 =` to prove recovery: DROP on an empty stack, repeated past the moat; `1 0 /`; `0 @`; an undefined word; OPEN of a missing file (expect STOIC to exit through LIB$STOP: defect 7). Check `CHECK` and the stack after each. |
| `12-float.sto` | `FLOAT< 7 I->F .=`. `2.5 F->I =`. `.+ .- .* ./` (`1. 4. ./ .=` → 0.25). **`2. 3. .^ .=`** → 8 (9 means the operands are reversed). `.SQRT .SIN .COS .ATAN .LOG .EXP .LOG10`. The `.=` format. `F=` and `E=`. `.<# .# .#>`. A float literal in hex radix (expected to be read as decimal). A bad float. |
| `13-calc.com` | `$ CALC 2. .SQRT 2. ./ .ASIN 4. .* .= CR ;F` → about 3.141592653589793. Also `$ STOIC` with an empty tail → banner. |
| `14-save.sto` | Define words, then `'T.SAV SAVE`. In a fresh run, `'T.SAV XLOAD` and check that the words work. After the Phase 2 relink, XLOAD should fail with a date error. |
| `15-sys.sto` | `GETTIM`/`ASCTIM`, `SHOW_TIME`, `GETJPI` (PID), `TRNLOG SYS$LOGIN`, `INVENTORY` (save the output for `words.md`), `REVISION`, `WHERE` and `WHAT`. |

### Interactive checks

Do these in tmux window 2, or in an expect script over a fresh telnet
session. Record the transcripts in `tests/interactive/`.

- The prompt shows the nesting depth during a multi-line definition.
- ^C during `BEGIN 0 END`, then ^C again during a second loop (defect 2).
  Also a `$SETIMR` AST after a ^C abort.
- ^Z at the prompt exits cleanly to DCL.
- `GETMODE`/`SETMODE` round trip. `TYI`. `TYPE_TYI`. `IO_CTRL_C` after a
  ^C during a read.
- A very long multi-line definition should overflow the compile buffer and
  ACCVIO (defect 4). Check that CHECK is reset afterwards.

### Produces

`tests/*.sto`, `tests/*.expected`, `tests/interactive/*.log`, and a
`tests/README.md` that explains how to run them and how each expected value
was justified.

### Done when

Every area above has a test. `stoic-suite` passes against the shipped
`STOIC.EXE`. Every surprise is logged in `doc/defects.md` or in the
"differences from the manual" list for `doc/language.md`.

---

## Phase 2: Rebuild from source

**Goal:** show that the sources in this tree reproduce the shipped
binaries on V5.5-2, and record what has to change if they don't.

### Steps

1. In `[.WORK]`, run `@WORK-ASSIGN` and then `@STOBUILD MAC` under
   `/OUTPUT=BUILD.LOG`. Fetch the log.
2. Sort every MACRO and LINK diagnostic into one of three groups: expected
   (`UNIVERSAL=START`), harmless, or blocking. Fix blocking problems in the
   `[.WORK]` copy only, and mirror each fix into a local `patched/` tree,
   one change per file, explained in `doc/build.md`.
3. Compare the new `RKERNEL.MAP` with the shipped `saostoic-text/kernel/
   rkernel.map`: psect sizes and the addresses of `k_start`, the dictionary
   and DATINIT.
4. Run `ANALYZE/IMAGE` on the shipped and the rebuilt RKERNEL, STOIC and
   RED images. Compare the header block count, the ISD list (VPN, page
   count, flags, VBN) and the transfer address.
5. Run the Phase 1 suite against the rebuilt `STOIC.EXE`. The output must
   be identical. The only expected differences are REVISION and DATE.
6. Rebuild `REDHIREZ.EXE` with `hirez.cre` to check that variant.

### Produces

`build/BUILD.LOG`, `build/analyze-*.txt`, `doc/build.md`, and `patched/` if
anything needed changing.

### Done when

There is a clean rebuild, the suite passes against it, and the ANALYZE
comparison is documented.

### Phase 2 outcome (2026-10-21)

- `@STOBUILD MAC` and `@HIREZ.CRE` ran in `[.WORK.SAOSTOIC]` with no
  MACRO or LINK diagnostics and no source changes; `patched/` is not needed.
- DATINIT, DICTIONARY and every ISD that IMAGE writes are the same size as
  the shipped ones. The KERNEL psect is 8 bytes longer, because V5's
  `$ASSIGN_S` passes a fifth argument (one call in CONTROLC, three in
  TYIO); `START` moves from 20DD2 to 20DDA.
- The rebuild links FORRTL, LIBRTL and MTHRTL instead of VMSRTL, so its
  fixup vector (ISD 7) is 2 pages, and the `$EXPREG`'d regions (stacks,
  compile buffer, R11) start 4F800 lower in P0.
- The suite against the rebuilt STOIC and RED differs from the shipped
  run only in those addresses and in REVISION (`build/suite-rebuilt.txt`).
  The expected files stay those of the shipped exe.
- The shipped `REDHIREZ.EXE` (1983) does not run on V5.5-2: BADISD. The
  rebuilt one does.
- The work tree now holds `;2` rebuilt versions over the `;1` shipped
  ones, including `SAO$KERNEL:HEAD0.EXE`; `stoic-run` gained `-r` so that
  `.dcl` tests use the RED they are meant to.

---

## Phase 3: IMAGE

**Goal:** understand IMAGE exactly, and find out where its assumptions
break on V5.5-2.

### Steps

1. `'IMAGE LOAD/L` in a fresh RKERNEL (or use STOIC.EXE, which already
   has it), then `SHOW` and `DISPLAY_ISD`. Check the result against
   `ANALYZE/IMAGE HEAD0.EXE`. Confirm the header is 1 block and that each
   resident ISD is 10 hex bytes, followed by its DZRO ISD.
2. **Round trip.**
   1. Define words, a VARIABLE holding a value, and a string.
   2. `'T1.EXE IMAGE`.
   3. `$ RUN T1.EXE`: the words should work, the variable should keep its
      value, and REVISION should be new.
   4. From T1, define more and run `'T2.EXE IMAGE`. Check T2 in the same
      way.
3. Repeat with `IMAGE_WRT`. Compare `ANALYZE/IMAGE` and `DIR/FULL`
   (record format, attributes) for the two kinds of output.
4. **Try to break it:**
   - a dictionary that has grown by more than the DZRO tail;
   - a relink without copying HEAD0;
   - a different IOSEGMENT;
   - `SAO$KERNEL` pointing elsewhere;
   - running T1 under `/DEBUG`.

   Record which failures give a clear error and which corrupt silently.
5. Decide whether `install.com` is worth translating to V5 `INSTALL ADD`
   syntax. Write it up, but **don't run it**, because that would be outside
   `[.WORK]`.

### Produces

`tests/image/*`, `doc/image.md`.

### Done when

The round trip works at two layers, or the reason it can't is
understood, and the limits are documented.

### Phase 3 outcome (2026-10-21)

- IMAGE works on V5.5-2 with the shipped and the rebuilt STOIC: two layers
  (T1, T2) keep their words, variables and strings and get new revision
  dates. `0 .IMAGE` gives BADISD. `tests/image/run` reruns everything;
  `doc/image.md` has the details.
- XLOAD refuses a save file from another exe ("Invalid save file date in
  XLOAD") and ends only that line.
- Defect 6 is confirmed for all three windows, 11 is characterized, and
  defects 22–29 are new. 22 matters most: `IORB<` is unusable in the
  shipped STOIC.EXE on V5.5-2, so the tests push the branch with
  `USER_DATA @ 491 + V_PUSH` (`tests/image/imgutil.sto`).
- Not done: ANALYZE/IMAGE and `DIR/FULL` of the outputs (the header was
  read with IMAGE's own words), a different IOSEGMENT, a run under
  `/DEBUG`. `install.com` is written up in V5 syntax but not run.
- `tools/vax-do.exp` now keeps the head and tail of runaway output and
  stops at its deadline even while the output keeps coming.

---

## Phase 4: RED

**Goal:** confirm that RED works on V5.5-2, and document its command set
from how it behaves.

### Steps

1. Write `tools/red-drive.exp`. It logs in through `vax-login.tcl` with the
   terminal set to VT100 (`SET TERMINAL/DEVICE=VT100`), starts
   `RED [.WORK.TESTS]R1.TXT`, sends keystrokes from a script file, and
   captures the screen.
   - Feed the screen output into a small terminal emulator to get screen
     snapshots, e.g. `tmux` in a detached session or `pyte`.
2. Write scripts for:
   - a new file ("New file");
   - inserting lines;
   - `B` LF;
   - `5L` LF;
   - searching with `S`;
   - deleting;
   - marking, cutting and pasting with the keypad `-` and `,`;
   - `[ ]` iteration;
   - numeric registers;
   - writing the file and exiting;
   - re-opening the file and checking its contents by FTP;
   - `ESC S` back to STOIC;
   - checking that `SHOW TERMINAL` is unchanged afterwards.
3. Check each command in `red/cli` CLI.DISP1 against `red.mem` and mark
   each one: documented and working, undocumented, or broken.

### Produces

`tools/red-drive.exp`, `tests/red/*`, `doc/red.md`.

### Done when

Every documented RED command has been run at least once and its result
recorded.

### Phase 4 outcome (2026-10-21)

- The shipped `RED.EXE` faults with ACCVIO at startup on V5.5-2 (30). obuf
  froze `O.BUFSTRT` as an absolute 1985 data address. The fault leaves the
  terminal changed (31). The rebuilt `RED.EXE` works.
- `tools/red-drive` runs key scripts over telnet in a raw pty, and
  `tools/red-screens` renders the screens with pyte. `tests/red/r0`–`r8`
  have run every command in the manual and every entry in CLI.DISP1.
  `doc/red.md` has a table for each one, with its status and the snapshot
  that shows it.
- SHOW TERMINAL is the same before and after every session that ends
  normally (r0–r5, r7, r8).
- Differences from the manual: the up arrow (33), the replies to `` `C ``
  (35), TF clamping, TI not implemented, and `'` being postfix (36).
  `,` (INPUT MODE), `^W`, keypad ENTER and ESC S are undocumented. `@K`
  and `@N` leave the next insertion drawn on the divider (34). KBD sends
  a malformed `ESC[?^Fl` (32).
- Not done: RED_NOSP, REDCPU, going back into RED after ESC S, files with
  fixed-length records or too big to map, and the INFOTON version
  (`ORANGE.CRE` is missing).

---

## Phase 5: Documentation

**Goal:** design documentation for STOIC in `doc/`, built from verified
facts. Each claim cites the source `file:line` and, where it applies, the
test that shows it. Material moves from `notes/` into `doc/` only once it is
verified.

| Document | Contents | Main sources |
|---|---|---|
| `doc/kernel.md` | Registers. Threading (subroutine-threaded, compile-and-go). The outer loop, CHECK and nesting. Header layout and attributes. The user table. The memory map and moats. Psects and extend.mar. The condition handler and CTRL/C. Terminal and RMS I/O. Channels. LOAD. SS words. | notes/kernel-design.md, rkernel.mar, Phase 1 |
| `doc/language.md` | STOIC as implemented: syntax, literals, radix, definitions, control structures, vocabularies, strings, the loop stack, and the in-line assembler. A **"differences from stoic.mem"** section: comparisons, MOD, … | stoic.mem, rdef, Phase 1 |
| `doc/words.md` | Every word, grouped by branch. For each: its stack effect, its source location, and a test reference. Generate the skeleton with a script that parses `header` macros in the `.mar` files and `'NAME :` definitions in the STOIC sources, then cross-check it against `INVENTORY` output. | all sources |
| `doc/image.md` | IMAGE step by step. The ISD handling. HEAD0. IMAGE vs IMAGE_WRT. BADISD history. SAVE/XLOAD and the DATE check. P0 determinism. V5.5-2 results. | image, rms.mar, Phase 3 |
| `doc/float.md` | The FS stack, D_floating, the word set, the output formats, MTH$ functions, CALC/FLODEF. GM `float.sto` for contrast. | float, crtl.mar, Phase 1 |
| `doc/red.md` | Dynasts and the buffer gap. The module structure and load order. Screen and window model. The command language reference. The keypad map. Terminal setup and restore. | red/*, Phase 4 |
| `doc/gm-variant.md` | GM vs SAO kernel: memory, headers, number input, float, missing features. | gm/*, notes/kernel-design.md §13 |
| `doc/build.md` | How to rebuild on V5.5-2, the build pipeline, and any patches. | Phase 2 |
| `doc/defects.md` | Each confirmed defect with a minimal repro, its cause (file:line), its impact, and a suggested fix. List suspected defects separately until they are confirmed. | Phases 1–4 |
| `doc/README.md` | An overview and reading order. | |

### Defect checklist

Defects suspected from the code, numbered as in `AGENTS.md`, and the tests
that settle them:

| # | Suspected defect | Settled by | Result |
|---|---|---|---|
| 1 | DIGIT: a character above `Z` is taken as a decimal point | 06-numio | **confirmed**: lowercase `x`, `1x5`, `2_5`, `7[` in a LOAD file compile silently as 0.0 (OTS$CVT_T_D's status is not checked) |
| 2 | CTRL/C skips `$ASTEXIT` | interactive `ctrlc` | **confirmed**: I_CTRL_C_HNDLR makes the AST routine return into I_ABORT; a second ^C is echoed but never delivered, a third interrupts like ^Y. DELAY ($SETIMR, $WAITFR) still works |
| 3 | IOSB overwrites the next user-table cell | interactive `tty` | **confirmed**: NLEN (TTCHAN+8, 3F as assembled) is already changed at startup and changes after every terminal QIO |
| 4 | No check on compile-buffer overflow | interactive `compbuf` | **confirmed**: the 17th 90-character line of a definition writes into the moat at CF000; STOIC then loops on OPCDEC faults until stopped (the loop is defect 27: PSL<FPD> is left set) |
| 5 | Integer overflow is not checked; a float in hex is read as decimal | 06-numio, 12-float | **confirmed**: literals wrap mod 2³²; `1.E30` needs HEX (E must be a digit) and is read as decimal |
| 6 | Nothing checks the 16-bit windows | image b1, b3, b4 | **confirmed**: a VARIABLE more than 7FFF above R11 gets an address 10000 too low, silently; a header past 1FBFF ACCVIOs into the kernel code; code past 2FBFF ACCVIOs into the fixup page and loops (27) |
| 7 | LIB$STOP from `.errstop` exits | 10-files, 11-errors | **confirmed**: LOAD or OPEN of a missing file exits STOIC with %RMS-F-FNF |
| 8 | One record per TYO in batch | Phase 0 (SUBMIT log) | **confirmed** |
| 9 | Remote-line code bugs | fix F09-REMOTE (Phase 6) | confirmed: REMSTART on NLA0: gives ACCVIO, REMTYPE then IVCHAN |
| 10 | GETCMD uses the CLI callback | 13-calc | works on V5.5-2H4, including an empty tail |
| 11 | IMAGE header and layout assumptions | Phase 3 | **characterized**: both HEAD0s have a one-block header and the resident/DZRO ISD pairs IMAGE expects, and two-layer IMAGE works with each. Unchecked: that HEAD0 matches the running kernel (28) and that a DZRO is big enough (26). The P0 layout is the same in every generation on one system, but depends on the shareable images linked (4F800 lower in a V5 link), which is what breaks absolute addresses (22) |
| 12 | MOD and /MOD with a negative dividend | 00, 01-arith | **confirmed**: unsigned; `-7 3 MOD` gives 0 |
| 13 | Comparison sense differs from the manual | 02-compare | **confirmed**: `GT` is true when the top of stack is greater; CP/M STOIC has the manual's sense, so the VAX reversed it (`doc/cpm-compare.md`) |
| 14 | `=` writes a negative number as `-`, three NULs, digits | 01, 02 and others | **new**, confirmed: `EQ_SGN` builds the sign with `movl #^a/-/` (a longword) |
| 15 | DGE compares the low longwords signed | 02-compare | **new**, confirmed: `0 0 0 -1 DGE` gives 0, `-1 5 -1 3 DGE` gives −1 |
| 16 | `.FLIP` moves only the first longword of each D_floating value | 12-float | **new**, confirmed: 1.1 becomes 1.0999999… |
| 17 | MTH$ and OTS$ errors are not reported | 12-math | **new**, confirmed: LOG 0, ASIN 2 and a POWDD overflow return a reserved operand, and the next float word faults (ROPRAND) |
| 18 | `.SQRT` of a negative number ends STOIC | 12-math | **new**, confirmed: ACCVIO at PC 80000010, "Improperly handled condition"; the condition handler's $UNWIND path for a signal from deeper than one frame is the suspect |
| 19 | Error messages show ABORT's PC | every error | **new**, confirmed: the handler writes `ABORT @` into the signal PC before the message is printed, and rdef sets ABORT to ERROR_TRACE (`rdef:1426-1440`, code at 23998 in the shipped exe), so every message says PC=00023998. The real PC is in ERROR_PC; ERROR_TRACE's traceback (WHAT of ERROR_PC, then of each return-stack entry) gives it as the first line |
| 20 | GETJPI's comment promises a completion code it does not leave | 15-sys | **new**, confirmed: SYSERR takes the code; only the value is left |
| 21 | IMAGE output from before the V4 fix no longer runs | Phase 2, image a4 | **new**, confirmed: the shipped `REDHIREZ.EXE` (1983, demand-zero ISDs no-write) fails with SYSTEM-F-BADISD on V5.5-2, and so does `0 .IMAGE` output today |
| 22 | rdef's BRANCH compiles an absolute data address | image d1 | **new**, confirmed: `IORB<` in the shipped exe pushes 7A891 (1985's layout); the cell is at CFE91. The lookup faults, the branch stays pushed, and every later line faults. Right in the rebuilt exe. `RED<` is made the same way, untested |
| 23 | IMAGE inside a LOAD saves `U_IFI` | image c1 | **new**, confirmed: the child starts at LOAD level 1; its first `;F` reads unopened channel 0 and loops on RMS-W-ISI (24) |
| 24 | A console read error that persists loops forever | image c1, interactive `image-console` | **new**, confirmed: I_READLINE → SYSERR → ABORT → `top_loop` reads again |
| 25 | The console is opened by `$CREATE` with PUT only | interactive `image-console` | **new**, confirmed: with `DEFINE/USER SYS$INPUT file`, STOIC (shipped or IMAGE) creates an empty new version and loops on RMS-W-FAC. Terminals and DCL data lines work |
| 26 | FIX_DZRO does not check for underflow | image b2 | **new**, confirmed: data over 7B pages makes the DZRO count FFF1; `RUN` gives VA_IN_USE |
| 27 | A fault in the middle of MOVC3 leaves FPD set | image loop (b3), interactive `compbuf` | **new**, confirmed: the handler sends the PC to ABORT but keeps PSL<FPD>, so ABORT's first instruction faults with OPCDEC forever |
| 28 | IMAGE does not check that HEAD0 matches the running kernel | image b6 | **new**, confirmed: shipped STOIC with the rebuilt HEAD0 writes an exe that fails at START with OPCDEC |
| 29 | rdef's `I_DATE_ERROR` is never installed | source (`rdef:1497`), image a7 | **new**, confirmed: XLOAD prints the kernel's message; rdef's is dead code |
| 30 | The shipped `RED.EXE` faults at startup | red r6 | **new**, confirmed: ACCVIO at 7B173, the `O.BUFSTRT` constant obuf froze in 1985 (`.D@ 'O.BUFSTRT CONSTANT`); the data region is now at CFA00. Same class as 22 |
| 31 | After that fault the terminal stays changed and `;F` hangs | red r6 | **new**, confirmed: Device_Type Unknown, No ANSI_CRT, No Wrap; CTRL/Y and STOP were needed. The `;F` hang is unexplained (O.FLAG left on is a guess) |
| 32 | KBD's `6 RESET_MODE` sends `ESC[?^Fl` | red raw logs, `kbd:500` | **new**, confirmed: RESET_MODE wants a character. Harmless on a VT100 |
| 33 | The up arrow from mid-line goes to the start of the same line | red r4 | **new**, confirmed: the manual says the previous line (`eb:65-72`) |
| 34 | After `@K` or `@N`, inserted text is drawn on the divider | red r8 | **new**, confirmed: the buffer is right, as ^R shows |
| 35 | `` `C `` replies differ from the manual | red r7 | **new**, confirmed: RETURN replaces like ESC, SPACE exits, other keys beep and wait |
| 36 | Smaller manual/code differences | red r2, r3, r4, r7 | **new**, confirmed: TF clamps to 1–10, TI is not implemented, `'` is postfix; `,` `^W` ENTER and ESC S are undocumented |
| 37 | `.+ROT`/`.-ROT` move half of one value (MOVL) | lang F1-FLOAT | **new**, confirmed: the moved 3.3 becomes 3.300000143051147 |
| 38 | `F->S` writes one byte past `F_STRING` | lang F1-FLOAT | **new**, confirmed: `F.EXPADD` becomes 20 hex; no wrong output seen |
| 39 | FS underflow not caught | lang F4-FSUNDER | **new**, confirmed: `.DROP .=` prints NULs; the next float literal faults |
| 40 | `>` does not check for an empty branch stack | lang L3-POP | **new**, confirmed: after `> > > >` every line faults in I_LOOKUP |
| 41 | DEF_INIT copies the command tail into the 132-byte LINE_BUFFER unchecked | fix F10-TAIL | **new** (Phase 6), confirmed: a 203-character tail is corrupted (`^@+ECIMAL` undefined) |
| 42 | NOCREF's keyed GET and PUT; no INIT_FRABS | fix F42-NOCREF (patched only) | **new** (Phase 6), confirmed: IFI alone; RAC on an exe made by IMAGE; NEF on a linked exe |

### Done when

Every document exists. Every claim in it is backed by a source line or a
test. `notes/` is either retired or marked as historical.

### Phase 5 outcome (2026-10-21)

- All ten documents exist: `doc/README.md` (overview and reading order),
  `kernel.md`, `language.md` (with "Differences from stoic.mem"),
  `words.md`, `float.md`, `gm-variant.md` and `defects.md`, beside the
  earlier `image.md`, `red.md`, `build.md` and `cpm-compare.md`.
- `words.md` is generated by the new `tools/word-index --md`. Its 964
  global-chain definitions match INVENTORY in order; the 27 crtl.mar words
  are only on the `FLOAT<` branch, which is why INVENTORY misses them.
- Claims the drafts could back only from the source were run on the
  shipped STOIC.EXE (`tests/lang/`, output in `phase5.out` and
  `phase5-kernel.out`). They found defects 37–40 and corrected the
  kernel map (MOAT gives CDC00, inside the P stack).
- Left on source evidence only, and said so in the docs: the prompt digit
  past 9 (`:`), whether SS arguments stay on the stack, the bare
  `$SCHDWK`, defect 9, and all of `gm-variant.md` (GM was not built).
- `notes/` is marked historical.

---

## Phase 6: Fixes

**Goal:** a patched SAO STOIC (kernel, `STOIC.EXE`, `RED.EXE`,
`REDHIREZ.EXE`) that fixes every defect in `doc/defects.md` that can be
fixed. Each fix gets a test, and the doc records where the manual, not the
code, is wrong. The shipped files and the Phase 2 rebuild stay as they are,
as references.

### Setup

1. **Local tree.** `patched/` is a copy of `saostoic-text/kernel`,
   `stoic` and `red`. Commit it unchanged first, so that `git diff` of
   `patched/` against that commit shows every patch. Each fix is its own
   commit, and the message names the defect number.
2. **VAX tree.** `[.WORK.PATCHED]` has `KERNEL`, `STOIC` and `RED`
   subdirectories. `tools/setup-work.com` gets a variant that fills them
   from `[.SAOSTOIC...]`, plus the `.OBJ` files of the unchanged modules.
   Patched files go up by ASCII FTP, one session per batch.
3. **Build.** Build with `@STOBUILD MAC` in `[.WORK.PATCHED]`. ASSIGN.COM
   points the logical names at the current default, so the build writes
   only into that tree. Add `tools/patched-assign.com`, a copy of
   `work-assign.com` that points at `[.WORK.PATCHED...]`. The patched
   STOIC is then `-x DUA1:[USERS.CLAUDE.WORK.PATCHED.STOIC]STOIC.EXE` to
   `stoic-run` and `stoic-suite`.
4. **Expected output.** `tests/*.expected` stays the record of the shipped
   exe. Add `stoic-suite --expected-dir tests/patched`. Then
   `tests/patched/*.expected` starts as a copy of the shipped files, and
   each fix commit changes only the lines that fix is meant to change.
5. **New tests.** Every defect gets a test in `tests/fix/` named by its
   number (`F14-SIGN.con`, `F27-FPD.con`, ...). Interactive defects get a
   `vax-interact` check, and RED defects get a `red-drive` script. Each
   test runs against both exes. On the shipped exe it shows the defect,
   and on the patched one it shows the fix.
6. **Rebuild order.** After any kernel change, rebuild in order: the
   kernel, HEAD0, STOIC.EXE, RED.EXE and REDHIREZ. IMAGE refuses a
   mismatched HEAD0 only once 28 is fixed, so until then always run the
   full `STOBUILD MAC`.

### Batches

Run the batches in this order. After each batch, rebuild, run the whole
suite, run `tests/image/run` and the RED smoke scripts against the patched
build, and commit.

**Batch A: small, local fixes.** These are one to three lines each, and no
other fix depends on them.

| # | Fix | Where |
|---|---|---|
| 14 | `movb #^a/-/,-(r5)` instead of `movl` | `rkernel.mar:1684` |
| 15 | compare the low longwords unsigned (BGEQU) | `rdef:555-563` |
| 16 | `.FLIP` with MOVQ | `float:46-48` |
| 37 | `.+ROT`/`.-ROT` move whole values (MOVQ, or MOVD through R0–R1) | `float:32,36,39` |
| 38 | make `F_STRING` one byte longer | `float:12,115` |
| 20 | correct GETJPI's comment | `rdef:795` |
| 29 | install `I_DATE_ERROR` in DEF_INIT, so XLOAD prints rdef's message | `rdef:1497` |
| 32 | `ASCII 6 RESET_MODE`, not `6 RESET_MODE` | `red/kbd:500` |
| 40 | `>` refuses to pop the last branch (STOIC<) and gives "Branch stack empty" | `rkernel.mar:1862-1865` |
| 1 | DIGIT: after the `Z` test, branch to `not_digit` instead of falling into `found_dp`. Also check the status OTS$CVT_T_D returns, and make a bad float a compile error. | `rkernel.mar:643-644`, `crtl.mar:109` |

Lowercase input in a LOAD file then gives "undefined word". That was the
intent: lowercase never worked as numbers.

**Batch B: the condition handler.** Do this before the bounds checks,
because their tests depend on recovering cleanly from a fault.

| # | Fix |
|---|---|
| 27 | Clear PSL<FPD> in the signal array's PSL slot when the PC is redirected to ABORT (`rkernel.mar:472-484`). |
| 19 | Have the handler print the message itself with `$PUTMSG` from the unmodified signal array, which has the true PC. Then redirect the PC to ABORT and return SS$_CONTINUE. It no longer resignals. ERROR_TRACE's traceback stays as it is. |
| 18 | Diagnose first: run `.SQRT` of a negative number with a traceback of the handler's `$UNWIND` path (`rkernel.mar:480-482`). The likely fix is `$UNWIND_S depadr=..., newpc=ABORT`, so that a signal from inside an MTH$ or OTS$ call unwinds straight to ABORT. |
| 17 | Retest after 18: once the handler deals with a signal from depth, the MTH$ errors (LOG 0, ASIN 2, POWDD overflow) may report themselves. If they still return a reserved operand, add a status or ROPRAND check after each call in `crtl.mar`. |
| 7 | `.errstop` keeps LIB$STOP only for start-up failures. LOAD and OPEN push the status and go through SYSERR, so a missing file gives a message and the prompt (`rms.mar:40-44`). |
| 24 | Count console read errors in a row in I_READLINE. After three, `$EXIT` with the last status. |

**Batch C: bounds checks.**

| # | Fix |
|---|---|
| 4 | Check the compile-buffer pointer in the words that compile code (`rkernel.mar:1011-1057`) against `comp_buf_0 + comp_buf_length` minus a margin for the RSB. On overflow, report "Line too long", clear CHECK and LOAD_RESET. Optionally raise `comp_buf_length`. |
| 6 | Range-check the displacement before each `cvtlw` (`rkernel.mar:1016,1047`, header `890-893`) and before data allocation. Report "Code space full" or "Data space full". |
| 5 | DIGIT accumulates with EMUL into a quadword. If the high longword is ever non-zero, report "Number too large". Values up to FFFFFFFF stay legal, so negative constants written in hex still work. The float-in-hex quirk stays and is documented. |
| 39 | Find out why the moat above FS doesn't catch the underflow, from FS's base and the `$EXPREG` layout. Then either move the base to the end of its block, so the next block's moat faults, or check depth in the float words. |
| 3 | Give the terminal IOSB its own quadword cell at the end of the user table, so no existing offset moves, and point every `iosb=ttchan+2(r11)` there (`tyio.mar:136,154,168,177,185,200,207,269`). |

**Batch D: the console and the terminal.**

| # | Fix |
|---|---|
| 25 | Open SYS$INPUT with `$OPEN` FAC=GET instead of `_WOPEN_NCR`'s `$CREATE` (`rkernel.mar:415-419`, `rms.mar:297-304`). Prompts still go to the terminal. Test with `DEFINE/USER SYS$INPUT file`. |
| 8 | `_rmstyo` buffers characters and does a `$PUT` at CR or when the buffer is full. Flush before each read and at exit (`tyio.mar:105-124`). Test under SUBMIT; this is the one place where batch is the test. |
| 2 | See decision 3. The AST routine changes the interrupted PC in the AST's own argument list (astprm, R0, R1, PC, PSL), not the PC in a call frame. The AST then ends normally through `$ASTEXIT`, and the REI lands in ABORT at normal level. Verify that this list really is the one the REI uses. If it isn't, fall back to a flag: set CTRL_C_FLAG, `$CANCEL` any terminal read, and poll at readline, TYO and DO/LOOP. The interactive `ctrlc` check must pass three ^Cs in a row. |
| 10 | GETCMD uses LIB$GET_FOREIGN (`ss.mar:291-296`). Check an empty tail, `RED file` and `CALC expr`. |
| 9 | Fix from the source: push the status before LIB$SIGNAL, recover R11 in `rmast`, and make the descriptors consistent (`tyio.mar:227,243,262-278`). It can be tested only if the user adds a second SIMH terminal line, so without one it is reviewed, not tested. |

**Batch E: absolute data addresses (22, 30, and the same class).** Words
that freeze a data-region address in a CONSTANT at build time:

- `BRANCH` (`rdef:943`), which makes `IORB<` and `RED<`;
- `STACK` (`rdef:1128`);
- `.VARIABLE` (`float:227`);
- `O.BUFSTRT` and `O.BUFEND` (`obuf:40,42`);
- `D.START` (`red/dyna:123`).

Each one breaks when the P0 layout differs from the build system's. See
decision 4 for the two ways to fix them. Whichever is chosen, the test is
to IMAGE a STOIC and a RED on this system, copy the HEAD0-matched exe into
a layout that differs, and run IORB<, a STACK, a .VARIABLE and RED. A
different layout is made with a link against an extra shareable image,
which is what shifted the rebuild by 4F800.

**Batch F: IMAGE guards.**

| # | Fix |
|---|---|
| 23 | IMAGE refuses to run when U_IFI ≠ 0: "IMAGE must be run from the console". |
| 26 | FIX_DZRO refuses when a region has outgrown its demand-zero section, and names the region (`image:79-84`). |
| 28 | Before writing, IMAGE compares HEAD0's kernel code section, read from the file, with the running kernel, and refuses if they differ. |
| 11 | Covered by 26 and 28. Mark it closed. |
| 21 | No code change. The patched build makes REDHIREZ again, and `doc/image.md` already explains BADISD. |

**Batch G: RED.**

| # | Fix |
|---|---|
| 31 | RED chains its own ABORT, which restores the terminal (as on exit) and then calls the old ABORT. Find the cause of the `;F` hang with a red-drive script before fixing it. Testing needs a fault inside RED; with 30 fixed, provoke one with a deliberate bad `@` command. |
| 34 | After `@K` and `@N`, put the cursor back in the text window, or redraw it. Check with `red-drive` that the screen matches ^R. |
| 33 | See decision 2. |

**Batch H: documentation only.** The manuals in `saostoic-text/` are not
edited. A new `doc/errata.md` lists each place where `stoic.mem` or
`red.mem` disagrees with the code, cross-referenced from `language.md` and
`red.md`:

- 13: the comparison sense;
- 35: the `` `C `` replies;
- 36: TF's clamp, TI missing, `'` being postfix, and the undocumented `,`,
  `^W`, ENTER and ESC S;
- 33, if the code is kept;
- 12, if MOD is kept.

### Phase 6: Decisions

These are for the user to decide before the batch they affect starts.
**Taken 2026-10-21: every recommendation** ("go with the
recommendations"): MOD signed (1b), the up arrow to the previous line
(2a), the AST-argument CTRL/C first (3), a fixed-VA data region plus a
run-time BRANCH (4a), the compile buffer kept at 400 hex bytes with a
check (5), and no shipped-equivalent exe (6).

1. **MOD and `/MOD` with negative numbers (12).** (a) Keep them unsigned
   and document it. (b) Sign-extend the dividend (CVTLQ-style, then
   EDIV), which gives a remainder with the sign of the dividend:
   `-7 3 MOD` = −1. *Recommended: (b).* It is what EDIV and CP/M STOIC
   do, and nothing in rdef or RED depends on the unsigned result. Batch A
   will grep for MOD users to confirm that.
2. **The up arrow in RED (33).** (a) Make the code match the manual:
   previous line. (b) Keep the code and document it. *Recommended: (a).*
3. **CTRL/C (2).** The PC-in-the-AST-argument-list design keeps today's
   behaviour, where ^C interrupts anything, even a loop that does no I/O.
   The flag design is safer but can't break into a tight loop. *Recommended:
   try the AST-argument design first, and fall back to the flag only if
   the test fails.*
4. **Absolute data addresses (Batch E).**
   (a) Make the kernel create the data region at a fixed virtual address
   with `$CRETVA`, as it already does for the code region
   (`rkernel.mar:405`). That fixes every frozen constant at once, the
   shipped STOIC.EXE's included once it is re-IMAGEd, and it makes
   SAVE/XLOAD independent of the P0 layout.
   (b) Change each defining word to compute its address from USER_DATA at
   run time. That is five or more words, plus any user code that does the
   same.
   *Recommended: (a).* Then do (b) for BRANCH only, because a fixed
   address can't help when an old exe is run with a new data base.
5. **Compile-buffer size (4).** Keep 400 hex bytes and only add the check,
   or double it. *Recommended: keep the size and add the check.*
6. **Whether to also patch a "shipped-equivalent" exe.** That would be
   just the fixes needed to run the 1985 STOIC.EXE and RED.EXE unchanged
   on V5.5-2 (22, 30, 31). *Recommended: no.* The patched build replaces
   them, and the shipped files stay as evidence.

### Batch A outcome (2026-10-21)

- Fixed 1, 14, 15, 16, 20, 29, 32, 37, 38 and 40, one commit each. The
  message of 40 is stoic.mem's "Vocabulary stack empty.", not "Branch
  stack empty". A float literal that OTS$CVT_T_D rejects (`1E5.` in hex)
  is now the compile error "invalid floating-point literal".
- `tests/fix/` has F01-LOWER, F01-BADFLT, F14, F15, F16, F29, F37, F38
  and F40. `tools/patched-suite --fix --shipped` shows each defect, and
  `--fix` the fix. F29 SAVEs with the Phase 2 rebuild and XLOADs with the
  exe under test.
- `tests/patched/` changes: `=` without NULs everywhere, DGE LOW, `.FLIP`,
  06-numio's lowercase line (now a compile error), and code addresses 16
  hex higher. 11-errors' first ACCVIO has a junk reason mask and PSL that
  move with the code. 06-numio now runs HEX FLT before the lowercase line,
  which ends the file in the patched build.
- `patched-push` uses absolute directories: in one FTP session each CWD
  is from the last, so only the first directory's files had gone up.
- Not yet checked on the VAX: 32 (the KBD escape) waits for the RED
  scripts of Batch G; RED.EXE builds and loads.

### Batch B outcome (2026-10-21)

- Fixed 7, 12, 17, 18, 19 and 24, and 27 in the code. Defect 12 has its
  own commit; the kernel's error handling is one commit, because the
  handler, SYSERR and the opens are one change.
- The handler prints the condition with `$PUTMSG`, with the true PC and
  its own severity (`-F-` for ACCVIO, where the shipped exe said `-W-`).
  A condition from inside a call (MTH$, LIB$SIGNAL) is unwound to
  STOIC's frame with ABORT as the new PC, and ERROR_PC is set to where
  STOIC called out (for MTH$, the CRTL stub). `.SQRT` of a negative
  number, LOG 0, ASIN 2 and POWDD overflow now give the MTH$ message and
  return to the prompt.
- SYSERR no longer calls LIB$SIGNAL. It prints the status with
  `$PUTMSG` (its vector padded with zero FAO arguments, so an SS$ status
  no longer prints stack junk) and jumps to ABORT. The opens and CLOSE
  go through it; LOAD gives back its input-file index when the open
  fails. A missing file in a LOAD file ends that line only.
- MOD and `/MOD` are signed: `-7 3 MOD` gives −1. `#` keeps an unsigned
  EDIV of its own, so `I=` and `<#>` print as before. In the sources only
  float's `/MOD` (on ABS values) and `#` used `/MOD`.
- The console read-error count is a new user-table cell, CONSOLE_ERRS,
  after RMBUF, which is also a new word. F24 (`DEFINE/USER SYS$INPUT`) now gives
  three RMS-F-FAC messages and exits. It has no shipped result, because
  the shipped exe loops; `patched-suite --fix --shipped` skips it.
- The kernel grew past a page boundary, so the `$EXPREG`'d regions are
  200 hex higher than after Batch A.
- 27 (FPD) was checked in Batch C: on the Batch B build, F04-COMPBUF's
  overflow into the moat gave one ACCVIO with PSL=0BC00001 and STOIC went
  back to the prompt, where the shipped exe loops on OPCDEC.

### Batch C outcome (2026-10-21)

- Fixed 3, 4, 5, 6 and 39. Tests: `tests/fix/` F03-IOSB, F03-TTIOSB,
  F04-COMPBUF, F05-LITOVF, F06-DATAWIN, F06-CODE, F06-DICT and
  F39-FSUNDER; the ones the shipped exe survives have a shipped result.
- 4: I_COMPILE refuses a word when fewer than a line plus 16 bytes are
  left in the compile buffer ("Compile buffer full", a compile error).
  The buffer stays 400 hex bytes.
- 5: DIGIT accumulates with EMUL, corrected for the signed multiply, and
  sets a new cell, U_OVF, when the high longword is non-zero. ICOMPILE
  refuses such an integer ("Number too large"); a float literal of any
  length still converts. DIGIT now reads the character with MOVZBL: the
  MOVB relied on R2's upper bytes being zero, which EMUL no longer leaves.
  `tests/06-numio` moved its BIG lines after HEX FLT, since the compile
  error now ends the file; `HEX 123456789` (36 bits) is also refused.
- 6: I_JUMP_TO_ME and I_DISP_TO_R11 test V after their CVTLW ("Code out
  of range", "Data out of range"). I_ENTER refuses a definition whose code
  would end past R8+8000 ("Code space full.") or whose header would run
  into the kernel code at R8-8000 ("Dictionary full."), before linking it.
- 39: the moat works; FOR$CVT_D_TG hid the ACCVIO, so `.=` printed NULs.
  FLOAT_TO_STRING now checks FS against its base, and the outer loop
  checks it after each line ("Float stack empty."; ABORT resets FS).
  FATAL is now global, for crtl.mar.
- 3: the terminal IOSB is a new quadword cell, TT_IOSB, after U_OVF.
  NLEN keeps $TRNLOG's length; in the shipped exe it holds IOSB bytes
  that depend on the terminal's last I/O, so F03 tests NLEN < 40.
- `tests/image/imgutil.sto`: IORB<< uses IORB<'s own address when it is
  in the current data region, since the new cells moved the cell from
  USER_DATA+491 in the patched exe. a-pat is unchanged apart from
  addresses and dates.

### Batch D outcome (2026-10-21)

- Fixed 25, 8, 2, 10 and 9, and found and fixed 41. Tests: `tests/fix/`
  F25-CONFILE, F08-BATCH, F10-TAIL and F09-REMOTE, and the interactive
  check `tests/interactive/ctrlc3.tcl`. F08, F09 and F10 have a shipped
  result; F25 does not, since the shipped exe loops for ever.
- 25: the console is opened with `_open` (`$OPEN` FAC=GET), so
  `DEFINE/USER SYS$INPUT file` reads console lines from the file.
  F24-CONERR now gives `%RMS-F-FNF` (twice) and exits, as a missing file
  should, in place of the RMS-W-FAC loop.
- 8: `_rmstype` and `_rmstyo` (the batch output path) collect a line in
  `rmsbuf` (132 bytes) and `$PUT` it at CR, at a lone LF or when it is
  full; the LF after a CR is dropped. `_rmsflush` puts a partial line; it
  is called by the condition handler, SYSERR and GET_STRING, and by an
  exit handler that OUTINIT declares (`_rmsexh`). Under SUBMIT, F08 gives
  whole lines (`QQA  3`); the shipped exe writes one record per character.
- 2: decision 3's first choice works. I_CTRL_C_HNDLR finds the frame it
  is to patch; when that is the AST's own CALLG frame it changes the PC in
  the AST argument list (16 bytes into it) instead of the frame's return
  PC, so the AST ends through `$ASTEXIT` and the REI lands in ABORT at
  normal level. ctrlc3 aborts three `BEGIN 0 END` loops, a DELAY and a
  prompt in a row; no flag was needed.
- 10: GETCMD calls LIB$GET_FOREIGN into its own 256-byte buffer, limited
  to LINE_BUFFER's size. An empty tail, `RED file` and `CALC expr` work
  (the suite's `.dcl` tests).
- 41 (new): DEF_INIT (`rdef:1516-1520`) moves the tail into LINE_BUFFER,
  132 bytes (`rkernel.mar:80`), without a check; a longer tail overwrites
  what follows. Fixed in GETCMD: a tail longer than LINE_BUFFER gives
  `%LIB-W-INPSTRTRU` and an empty line.
- 9: the remote line now names its output device correctly, checks the
  output `$ASSIGN`, passes R11 to the ASTs as astprm, and `rmast` no longer
  calls LIB$SIGNAL (the handler would unwind out of the AST); a read error
  stops the listener and leaves the status in RMICHAN's IOSB. F09 runs
  REMSTART on NLA0: (no second terminal line needed): REMTYPE works and the
  read ends with ENDOFFILE (870). The shipped exe gives ACCVIO and IVCHAN.
- The new cells and buffers make the data section one page longer; the
  suite diffs were addresses only, and a-pat is unchanged apart from
  addresses and dates.

### Batch E outcome (2026-10-21)

- Fixed 22 and 30, and with them STACK, `.VARIABLE` and `D.START`, by
  decision 4a.
  - `fix_p0` in the kernel's startup grows P0 to end at 400000 before
    the regions are `$EXPREG`'d (it fails with VASFULL if P0 is already
    past that). So USER_DATA is 402200 on any layout that leaves room.
  - BRANCH compiles the cell's displacement from R11, and I_PUSH_VOCAB
    adds R11 at run time (`addl3 r11,@#disp,-(r10)`). This is the run-time
    half of 4a.
  - RED's `D.DISP` shows buffer origins with 8 digits (`red/dyna`), as
    they are now above 400000.
- The planned layout test, a link against an extra shareable, does not
  work: the fixup-vector section always follows the last cluster, so a pad
  moves the fixups as well. Instead, `tests/image/widen.sto` adds a 512-page
  (200 hex) demand-zero ISD after the fixup ISD of an exe made by IMAGE,
  which moves its shareables and regions 40000 higher (`doc/image.md`,
  "Moving the shareables"). e-new shows the defects in the unpatched
  rebuild: O.BUFSTRT is off by −4F28D, the STACK overflows, and the
  `.VARIABLE` reads garbage. e-pat runs both exes at 402200 with
  everything right.
- `tests/fix/F22-BRANCH.con` defines and uses a branch (shipped: a cell
  at −5516F; patched: 629).
- The suites, `tests/fix/` and image groups a-pat and d differ from
  before only in addresses. RED r0–r8 give the same screens apart from
  addresses, dates and r3's wider `D.DISP`.
- r7's ^C differed in one run: the ^C landed while the 9-second loop was
  still running, and RED said "Command aborted." (`cli:1645`) in place of
  redrawing. Both kernels do both, depending only on timing, so the new
  `tests/red/r9-ctrlc.tcl` sends one ^C during a loop and one after it.
  The rebuilt and patched REDs give the same screens.
- 42 (new): NOCREF never worked. It omits INIT_FRABS (IFI), and its keyed
  GET fails on an exe made by IMAGE (variable-length records, RAC) and its
  keyed PUT on a linked one (NEF). `tests/fix/F42-NOCREF.dcl`, patched
  only, as it needs `IORB<`. Left for Batch F.

### Batch F outcome (2026-10-21)

- Fixed 23, 26 and 28 in `patched/stoic/image`, as planned:
  - 23: `.IMAGE` refuses when `U_IFI @` ≠ 0.
  - 26: FIX_DZRO records the region (`DATA_REGION` etc. set REGION) when
    its growth is ≥ the DZRO's page count, and `.IMAGE` refuses after
    SCHEDULE_WRITES, before FCREATE.
  - 28: KERNEL_MATCH compares HEAD0's code ISD (the one at CODE_0) with
    memory block by block. No such ISD counts as a mismatch, as the
    rebuilt HEAD0's code is at VPN FE and the patched kernel's at FF.
  - Messages and branches are factored into small words: string literals
    inside IF bodies gave "Byte-displacement overflow."
- Closed 11 (covered by 26 and 28) and 21 (no change).
- Fixed 42: NOCREF uses block I/O. The NOCREF'd exe needs INSTALL
  (NOTINSTALL), which the rules here forbid, so it was not run installed.
- `.IMAGE` drops the condition codes of its FCLOSEs.
- New tests `tests/fix/F23-IMAGELOAD.dcl`, `F26-DZRO.dcl` and
  `F28-HEAD0.dcl`; F42 rewritten. F28 includes a control (rebuilt STOIC,
  patched `image`, rebuilt HEAD0) that is written.
- The build makes all three exes; the suites, `tests/fix/` and image
  groups a-pat and e-pat differ only in addresses and sizes.

### Batch G outcome (2026-10-21)

- Fixed 31 in `patched/red/red`: while RED runs, ABORT is RED_ABORT. It
  restores the terminal without RESTORE_VT100's screen-clearing `ESC c`,
  turns buffering off, restores the CTRL/C handler, and jumps to the old
  ABORT, so the traceback is unchanged. The `;F` hang was 30's (fixed in
  Batch E): after a fault inside the rebuilt RED, `;F` works, but the
  terminal stays Unknown and CR stays buffered.
- Fixed 32 (`ASCII 6 RESET_MODE`, `kbd`), 33 (C.UP_ARROW is `1+ C.L-`,
  `eb`) and 34 (`S.CUP FLUSH` after the divider in C.@K and C.@N, `cli`
  and `clihirez`).
- New red-drive scripts `tests/red/r10-fault`, `r10b-bufoff` and
  `r11-uptop`; results with the patched RED are in `tests/red/patched/`.
- Regression: r0–r5 and r7–r9 against the patched RED. r0, r1, r2, r7
  and r9 match the shipped-run screens. r3 differs only in buffer
  addresses (the data region is now near 400000), r5 in timestamps, r4
  in the up-arrow rows (33) and r8 in the divider (34).

### Batch H outcome (2026-10-21)

- `doc/errata.md` lists the corrections to `stoic.mem` (20 rows, from
  `language.md`'s table) and `red.mem` (7 rows: 33, 35 and 36's items),
  in manual order. A column says whether the patched build keeps the
  code's behaviour or now does what the manual says (12, 14, 2, 7, 40,
  33) or changes it otherwise (5).
- A section sets the VAX comparison words against CP/M STOIC's: `GT`, `LT`,
  `GE` and `LE` do the opposite on the VAX, and code from CP/M or the
  manual has to swap them.
- Cross-referenced from `language.md`, `red.md` and `README.md`.

### Produces

- `patched/`: the sources, each fix a separate commit.
- On the VAX, `[.WORK.PATCHED...]`: the patched kernel, HEAD0, STOIC.EXE,
  RED.EXE and REDHIREZ.EXE.
- `tests/fix/` and `tests/patched/*.expected`.
- `doc/patches.md`: each patch with its defect, diff summary, test and any
  change in behaviour.
- `doc/errata.md`.
- A "Status" column in `doc/defects.md` (fixed, documented, won't fix),
  and a "Patched build" section in `doc/build.md`.

### Done when

- Every one of the 40 defects is fixed and tested, documented in
  `doc/errata.md`, or (only 9, 11 and 21) closed with a stated reason.
- The full suite, `tests/image/run`, the interactive checks and the RED
  scripts pass against the patched build. Their only differences from the
  shipped output are those listed in `doc/patches.md`.
- `tests/fix/` shows each defect on the shipped exe and its fix on the
  patched one.
- AGENTS.md's defect summary says which defects are fixed in the patched
  build.

---

## Decisions

- The tree is under git, and `saostoic/` has been deleted.
- Nothing is written on the VAX outside `[USERS.CLAUDE.WORK...]`. All new
  binaries, rebuilt or IMAGE-made, go there. `[.SAOSTOIC]` stays as the
  read-only reference.
- Interactive checks run over a fresh telnet session (`tools/vax-interact`);
  the telnet session in tmux window 2 is for checks the user watches.
