# tools/

These scripts drive the SIMH VAX (192.168.2.20, account CLAUDE) without
anyone typing at it. They are adapted from Peaseblossom's tools.

- The password is read from `~/.netrc-claude-vax` (`$VAX_NETRC`) by the Tcl
  code itself. It never appears on a command line and is never printed.
- Every file they write on the VAX goes in `DUA1:[USERS.CLAUDE.WORK...]`.
- A flock lock (`vax-lock.sh`) makes sure only one run uses the VAX at a
  time.

| File | What it does |
|---|---|
| `stoic-run [-x exe] [-r exe] [-f file]... [-m] file...` | Runs each file in a fresh STOIC and prints STOIC's output, without the banner. A `.sto` is LOADed; a `.con` is typed as console lines (a compile error there ends only its line, so error tests are `.con`); a `.dcl` is DCL commands, for command tails (no apostrophes), with `STOIC` the `-x` exe and `RED` and `CALC` the `-r` one. The defaults are the shipped `[.SAOSTOIC.STOIC]STOIC.EXE` and `[.SAOSTOIC.RED]RED.EXE`. On the VAX, `-` in a name becomes `_`. `*.TMP` files a test makes are deleted afterwards. |
| `stoic-suite [-x exe] [-r exe] [-d dir] [-e dir] [-F dir] [--update] [name...]` | Runs `../tests/*.sto`, `*.con` and `*.dcl` (and copies `../tests/files/*`) in one VAX job and diffs each against its `.expected`. A bare name is looked for as `.sto`, then `.con`, then `.dcl`. `--update` records the output instead; review it before you commit. `-d` takes the tests from another directory, and `-e` keeps the `.expected` files in another, and `-F` copies the files in another directory in place of `../tests/files/`. `STOIC_SUITE_SED`, if set, is a sed script applied to each output first. |
| `vax-interact [-o dir] check.tcl...` | Interactive checks over a fresh telnet session (not the user's pane): each Tcl check drives STOIC with `stoic`, `line`, `keys` (CTRL/C is `\003`), `settle` and `await`, and its transcript goes to `dir/check.log` (default `../tests/interactive`). A check that leaves STOIC running is ended with CTRL/Y and STOP. |
| `vax-do [-o dir] [-get NAME]... [-p word] [-keep] [-t file] proc.com [file...]` | Uploads the files, runs `@PROC/OUTPUT=VAXDO.LOG` in `[.WORK]` over telnet, fetches the log and the `-get` files, deletes them all there, and reports `$STATUS`. `-t` saves what went to the terminal. A `.exe` or `.zip` goes either way in binary mode, anything else in ASCII. |
| `vax-do.exp`, `vax-interact.exp`, `vax-login.tcl`, `vax-ftp.tcl`, `vax-lock.sh` | The parts behind `vax-do` and `vax-interact`: the expect driver, the login, active-mode FTP, and the lock. |
| `red-drive [-o dir] script.tcl...` | Runs RED over a fresh telnet session in a raw pty (24×80 VT100) and sends each script's keys: `red file`, `cmd "text"` (a command line, `~` sent as LF, `\027` for ^W), `k key...` (named keys such as `ret`, `kp-`, `pf1`, `^B`), `snap name`, plus `line`, `settle` and `await`. It records SHOW TERMINAL before and after and writes `dir/script.raw` and `.scr` (default `../tests/red`). RED is the shipped one unless `STOIC_RED` names another. |
| `red-screens [-a] file.raw`, `red-show file.raw...` | Replay a `.raw` through pyte and print the screen at each snap; `-a` marks reverse, bold, underline and blink. `red-show` prints only the non-blank rows. |
| `ana-summary file...` | Cuts `ANALYZE/IMAGE` listings down to the header block count, transfer address, link date and one line per ISD, for comparing images. |
| `word-index [--list \| --md]` | Runs locally, with no VAX. It indexes every word of STOIC.EXE from the kernel `header` macros and the definitions in rdef, image, float, obuf and vt100, and cross-checks the list against `doc/data/stoic-inventory.txt`. With no option it prints the counts and the mismatches; `--list` prints one word per line; `--md` prints `doc/words.md`. |
| `setup-work.com` | Run once with `vax-do`. It BACKUPs `[.SAOSTOIC...]` to `[.WORK.SAOSTOIC...]` and creates `[.WORK.TESTS]`. It does nothing if the copy already exists. |
| `setup-patched.com` | Phase 6. Run once with `vax-do`. It BACKUPs `[.SAOSTOIC...]` to `[.WORK.PATCHED...]`, the tree the patched sources are built in. P1 names another tree, such as `CURRENT`. |
| `patched-push [-n] [file...]` | Phase 6. Copies each file under `../patched/` that differs from `../saostoic-text/` (or the ones named) by ASCII FTP, in one session, to its place in `[.WORK.PATCHED...]`. `-n` only lists them. With `STOIC_TREE=current` it copies `../current/` to `[.WORK.CURRENT...]`. |
| `patched-build.com` | Phase 6. Run with `vax-do -t`. It builds `[.WORK.PATCHED]` with `STOBUILD MAC` and `HIREZ.CRE`, keeps three versions of each built file, and lists the exes. P1 `LINK` skips the assembly; P2 names another tree, such as `CURRENT`. |
| `patched-suite [--fix] [--shipped] [--update] [name...]` | Phase 6. Runs the suite against the patched STOIC.EXE and RED.EXE and compares with `../tests/patched/`. With `--fix` it runs the defect tests `../tests/fix/` instead, against `fix/patched/`, or with `--shipped` against the shipped exes and `fix/shipped/`. REVISION's date is masked. `--cmp` runs the boundary tests `../tests/cmp/` against `cmp/patched/`. With `STOIC_TREE=current` it runs the current exes and compares with `../tests/current/` and `fix/current/` (`--cmp` still with `cmp/patched/`); the helpers in `tests/files/` and the tests are first swapped with `cmp-swap`, apart from those that test the comparison words (`../doc/current.md`). |
| `cmp-swap [-n] file...` | Phase 8. Runs locally. Swaps GT with LT and GE with LE (with their `_IF` and `.` forms) where they are words of code, not in comments, strings or `'NAME`s, and lists each change. It swapped the uses in `../current/`; the definitions were changed by hand. `-n` only lists. |
| `make-dist [name]` | Runs locally. Makes the release source zip, `../build/dist/saostoic-current-src.zip`, from the commit HEAD: `../current/`, the documents listed in `../doc/dist.md` and `LICENSE-UNKNOWN.md`, under `saostoic/`. |
| `dist-exe.com` | Run with `vax-do -o ../build/dist -get SAOSTOIC-CURRENT-EXE.ZIP`. Zips HEAD0, STOIC, RED and REDHIREZ from `[.WORK.CURRENT...]` with `ZIP "-V"`, as the release exe zip, and deletes its staging directory. |
| `patched-assign.com` | Like `work-assign.com`, for `[.WORK.PATCHED...]`. |
| `work-assign.com` | Points `SAO$KERNEL`, `SAO$STOIC` and `SAO$RED` at the scratch copy, and defines `STOIC`, `RED` and `CALC`. `stoic-run` sends it on every run. |

## Where the output comes from

- STOIC writes to SYS$COMMAND, so its output is taken from the telnet
  session, not from `VAXDO.LOG`.
- Batch is no use: every TYO is a separate record there (defect 8).
- Test input is sent to STOIC as data lines of the procedure, so DCL never
  sees the `'` of `'FILE.STO LOAD`.
- LOAD does not uppercase its input, so write test files in uppercase.
- The procedure runs with `SET NOON`: a STOIC that exits through LIB$STOP
  (a missing LOAD file) must not end it. DCL then skips that STOIC's
  remaining data lines (SKPDAT).
- NULs in the output are shown as `^@`; `=` writes three before the digits
  of a negative number.

## Examples

    tools/stoic-run tests/00-smoke.sto
    tools/stoic-suite
    tools/stoic-suite --update 03-control
    tools/stoic-run -x 'DUA1:[USERS.CLAUDE.WORK.SAOSTOIC.STOIC]STOIC.EXE' t.sto
