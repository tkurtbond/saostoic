# tests/

Phase 1 of `PLAN.md`: an executable specification of the shipped
`[.SAOSTOIC.STOIC]STOIC.EXE` as it actually behaves on VAX/VMS V5.5-2H4.
Every `.expected` file is the output of a real run. Each value was checked
against the source cited in the test's header comment, and a disagreement
with `stoic.mem` is recorded as it is, not "fixed".

## Running

    tools/stoic-suite                 # all of them, one VAX job; PASS/FAIL each
    tools/stoic-suite 06-numio        # one
    tools/stoic-suite --update 06-numio   # re-record; review the diff first
    tools/stoic-run tests/06-numio.sto    # just show the output
    tools/stoic-suite -x 'DUA1:[USERS.CLAUDE.WORK.SAOSTOIC.STOIC]STOIC.EXE'

The interactive checks are run separately:

    tools/vax-interact tests/interactive/*.tcl

Their transcripts, `tests/interactive/*.log`, are committed as evidence.
They are not diffed, because terminal QIO values (NLEN in `tty`) differ
between runs.

The IMAGE tests of Phase 3 are separate too, because they make exes and
one group never ends by itself:

    tools/vax-do tests/image/SETUP.COM   # once: HEAD0 copies in [.WORK.IMG]
    tests/image/run [group...]           # writes tests/image/results/

Their results are committed and described in `doc/image.md`.

The RED tests of Phase 4 are key scripts for `tools/red-drive`. r6 runs
the shipped RED, which fails (defect 30); the others need the rebuilt one:

    STOIC_RED='DUA1:[USERS.CLAUDE.WORK.SAOSTOIC.RED]RED.EXE' \
        tools/red-drive tests/red/r[0-578]-*.tcl
    tools/red-drive tests/red/r6-ship.tcl

Each writes `tests/red/*.raw` (the session) and `*.scr` (the screens).
They are compared by eye, not diffed, and described in `doc/red.md`.

## Kinds of test

| Kind | How it runs | Use it for |
|---|---|---|
| `.sto` | LOADed by a fresh STOIC | most tests. A compile error ends the rest of the file, and every LOAD under way. |
| `.con` | typed at a fresh STOIC's console | errors: there a compile error ends only its line |
| `.dcl` | DCL commands after `@WORK-ASSIGN` | command tails (`STOIC ...`, `CALC ...`); no apostrophes |
| `interactive/*.tcl` | `tools/vax-interact`, over telnet | CTRL/C, CTRL/Z, TYI and terminal modes, and failures that hang STOIC |

`files/` holds helpers copied with every suite run. `util.sto` gives
`SP@`, `SA` and `[ ... .S` (print the stack, deepest first). `10a`–`10d`
are the nested LOADs of `10-files`.

Rules for writing tests:

- Write in uppercase: LOAD does not uppercase what it reads.
- Put `HEX`, `DECIMAL`, a branch word like `TV<`, or a definition that a
  later word uses on its own line. A line is compiled before it runs.
- Print only what does not change between runs: no PIDs or times.
  Traceback addresses are stable for a given exe.
- A test that writes files names them `*.TMP`; `stoic-run` deletes them.
- Put anything that ends STOIC (LIB$STOP, `.SQRT` of a negative) last.
  DCL skips the remaining input (SKPDAT).

## The tests

The defect numbers are those of `PLAN.md`'s defect checklist.

| Test | Area | Notable results |
|---|---|---|
| `00-smoke` | the tools work | |
| `01-arith` | `+ - * / MOD /MOD`, shifts, `MAX MIN ABS` | `-` and `/` are B−A, B/A; `MOD` and `/MOD` are unsigned (12); `=` NULs (14) |
| `02-compare` | `GT LT EQ`…, the `*_IF` forms, DGE | `GT` is true when the top is greater (13); DGE's low longwords (15) |
| `03-stack` | stack words | |
| `04-control` | IF, BEGIN END, REPEAT, DO LOOP, `+LOOP`, `I J K`, `N ( )`, multi-line structures | |
| `05-define` | `:`, redefinition, CONSTANT, VARIABLE, ARRAY (`count 'name ARRAY`), SVARIABLE, `()`, EXEC, IMMEDIATE | a word is redefined from the line after |
| `06-numio` | radix, `<# # #S #>`, `I=`, literal overflow, DIGIT | literals wrap (5); lowercase junk compiles as 0.0 (1) |
| `07-strings` | string literals and string words | the quote rule (see `AGENTS.md`) |
| `08-vocab` | branches, MODULE, FORGET, DEF? | a branch word takes effect from the next line |
| `09-asm` | the in-line assembler, DUPI | DUPI needs HEX |
| `10-files` | nested LOAD, LIST, WOPEN/PUT/OPEN/GET | LOAD nests 3 deep; a compile error in a nested LOAD ends them all |
| `11-errors.con` | each error, then recovery | stack underflow is caught by the moat; a missing file exits STOIC (7) |
| `12-float` | the float stack and words, `.=` `F=` `E=` formats, overflow | `.FLIP` (16); `.^` is B^A; floats in HEX (5) |
| `12-math` | the MTH$/OTS$ words | errors unreported (17); `.SQRT` of a negative ends STOIC (18) |
| `13-calc.dcl` | command tails, CALC, an empty tail | GETCMD works on V5.5-2H4 (10) |
| `14-save`, `14-xload` | SAVE then XLOAD in a fresh STOIC | round-trips |
| `15-sys` | ASCTIM, REVISION, TRNLOG, GETJPI, WHERE, WHAT | GETJPI leaves only the value (20) |
| `interactive/prompt` | the prompt depth, CTRL/Z | |
| `interactive/ctrlc` | CTRL/C twice, DELAY after an abort | only the first ^C works (2) |
| `interactive/tty` | TYI, TYPE_TYI, IO_CTRL_C, GETMODE/SETMODE | NLEN overwritten by the IOSB (3) |
| `interactive/compbuf` | a definition too long for the compile buffer | no check; STOIC loops on faults (4) |

The full word list of the shipped exe, from INVENTORY, is
`doc/data/stoic-inventory.txt`.
