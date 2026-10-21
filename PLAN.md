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
| 1 Characterize shipped binaries | suite `tests/00`–`15` (18 files) passes; interactive checks in `tests/interactive/`; INVENTORY in `doc/data/`; `tests/README.md`. Left: `doc/defects.md` |
| 2 Rebuild from source | done (see "Phase 2 outcome"; `doc/build.md`) |
| 3 IMAGE | done (see "Phase 3 outcome"; `doc/image.md`, `tests/image/`) |
| 4 RED | done (see "Phase 4 outcome"; `doc/red.md`, `tests/red/`) |
| 5 Documentation | design drafts in `notes/` |

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
| 9 | Remote-line code bugs | source review only, unless a test can be built | open |
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

### Done when

Every document exists. Every claim in it is backed by a source line or a
test. `notes/` is either retired or marked as historical.

---

## Decisions

- The tree is under git, and `saostoic/` has been deleted.
- Nothing is written on the VAX outside `[USERS.CLAUDE.WORK...]`. All new
  binaries, rebuilt or IMAGE-made, go there. `[.SAOSTOIC]` stays as the
  read-only reference.
- Interactive checks run over a fresh telnet session (`tools/vax-interact`);
  the telnet session in tmux window 2 is for checks the user watches.
