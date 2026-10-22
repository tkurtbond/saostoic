# SAO STOIC for VAX/VMS

SAO STOIC is a FORTH-like language for VAX/VMS, written by Roger Hauck and
Jonathan Mark at the Smithsonian Astrophysical Observatory (1980–85). RED
is a screen editor for the VT100, written in STOIC. This repository holds
their 1985 sources and those of an older GM Research variant of the kernel.
It also holds the results of testing them on a SIMH MicroVAX 3900 under
VAX/VMS V5.5-2H4: documentation checked against the running system, a test
suite, and fixed versions of the sources.

## If you want to run STOIC

Use **[`cmpfix/`](cmpfix/)**. It is the 1985 STOIC with these changes:

- 45 of the 49 defects found are fixed;
- the code and dictionary have more room;
- the comparison words mean what the manual says they mean.

[`cmpfix/README.md`](cmpfix/README.md) explains how to copy its 34 source
files to a VAX, build STOIC.EXE and RED.EXE (no binaries are needed), and
run STOIC, RED and CALC.

## If you want to read about it

Start at [`doc/README.md`](doc/README.md). It covers:

| Document | Contents |
|---|---|
| [`language.md`](doc/language.md) | The language as a programmer meets it |
| [`kernel.md`](doc/kernel.md) | The MACRO-32 kernel |
| [`words.md`](doc/words.md) | Every word, with its stack effect, source line and a test |
| [`float.md`](doc/float.md) | Floating point and CALC |
| [`image.md`](doc/image.md) | IMAGE, which writes the running STOIC as a new `.EXE` |
| [`red.md`](doc/red.md) | The RED editor |
| [`build.md`](doc/build.md) | Rebuilding from source |
| [`defects.md`](doc/defects.md) | The 49 defects, each with a repro, cause and fix |
| [`errata.md`](doc/errata.md) | Corrections to the manuals |

Each claim in `doc/` cites a source line or a test. The original manuals
are [`saostoic-text/stoic/stoic.mem`](saostoic-text/stoic/stoic.mem) and
[`saostoic-text/red/red.mem`](saostoic-text/red/red.mem).

## The tree

| Path | Contents |
|---|---|
| [`saostoic-text/`](saostoic-text/) | The 1985 sources and manuals, unchanged, as Unix text. |
| [`patched/`](patched/) | The sources with the defects fixed and the code window raised; the comparisons keep the 1985 VAX sense. |
| [`cmpfix/`](cmpfix/) | `patched/` with the comparisons as in the manual. |
| [`doc/`](doc/) | The documentation. |
| [`tests/`](tests/) | The tests and their expected output ([`tests/README.md`](tests/README.md)). |
| [`tools/`](tools/) | Scripts that run the tests on the VAX over FTP and telnet ([`tools/README.md`](tools/README.md)). |
| [`build/`](build/) | Logs, link maps and `ANALYZE/IMAGE` output from rebuilding the 1985 sources and the patched tree; the evidence for [`doc/build.md`](doc/build.md). Not needed to build. |
| [`PLAN.md`](PLAN.md) | The test plan, its phases and results. |
| [`notes/`](notes/) | Early design notes, superseded by `doc/`. |
| [`AGENTS.md`](AGENTS.md) | Instructions for the coding agent that did the work, with a summary of the design. |

The tools assume a particular VAX and account (`AGENTS.md`). The tests and
results show what was run there; they are not set up to run elsewhere
without changes.

## Credits

STOIC and RED are by Roger Hauck and Jonathan Mark of the Smithsonian
Astrophysical Observatory. The original sources carry no copyright or
licence notice. The testing, documentation and fixes here were done in
2026 by T. Kurt Bond with Claude (Anthropic).
