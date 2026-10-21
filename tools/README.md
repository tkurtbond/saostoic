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
| `stoic-run [-x exe] [-f file]... [-m] file.sto...` | LOADs each file in a fresh STOIC and prints STOIC's output, without the banner. The default exe is the shipped `[.SAOSTOIC.STOIC]STOIC.EXE`. On the VAX, `-` in a name becomes `_`. |
| `stoic-suite [-x exe] [--update] [name...]` | Runs `../tests/*.sto` (and copies `../tests/files/*`) in one VAX job and diffs each against its `.expected`. `--update` records the output instead; review it before you commit. |
| `vax-do [-o dir] [-get NAME]... [-p word] [-keep] [-t file] proc.com [file...]` | Uploads the files, runs `@PROC/OUTPUT=VAXDO.LOG` in `[.WORK]` over telnet, fetches the log and the `-get` files, deletes them all there, and reports `$STATUS`. `-t` saves what went to the terminal. |
| `vax-do.exp`, `vax-login.tcl`, `vax-ftp.tcl`, `vax-lock.sh` | The parts behind `vax-do`: the expect driver, the login, active-mode FTP, and the lock. |
| `setup-work.com` | Run once with `vax-do`. It BACKUPs `[.SAOSTOIC...]` to `[.WORK.SAOSTOIC...]` and creates `[.WORK.TESTS]`. It does nothing if the copy already exists. |
| `work-assign.com` | Points `SAO$KERNEL`, `SAO$STOIC` and `SAO$RED` at the scratch copy, and defines `STOIC`, `RED` and `CALC`. `stoic-run` sends it on every run. |

## Where the output comes from

- STOIC writes to SYS$COMMAND, so its output is taken from the telnet
  session, not from `VAXDO.LOG`.
- Batch is no use: every TYO is a separate record there (defect 8).
- Test input is sent to STOIC as data lines of the procedure, so DCL never
  sees the `'` of `'FILE.STO LOAD`.
- LOAD does not uppercase its input, so write test files in uppercase.

## Examples

    tools/stoic-run tests/00-smoke.sto
    tools/stoic-suite
    tools/stoic-suite --update 03-control
    tools/stoic-run -x 'DUA1:[USERS.CLAUDE.WORK.SAOSTOIC.STOIC]STOIC.EXE' t.sto
