# Building and running cmpfix

This directory holds the sources of **cmpfix**, a fixed and extended SAO
STOIC for VAX/VMS. It is the 1985 SAO STOIC, by Roger Hauck and Jonathan
Mark, with these changes:

- **Defects fixed.** 46 of the 50 defects found in testing are fixed
  (`../doc/defects.md`, `../doc/patches.md`). For example, a missing LOAD
  file no longer ends STOIC, every CTRL/C works, and the compile buffer
  and the code and data windows are checked.
- **More room.** Code may lie anywhere from 2FE00 to 6FF2D hex, and the
  dictionary is 128 KB. A fresh STOIC.EXE has about 231 KB of code space
  and 105 KB of dictionary space free, and RED.EXE about 205 KB and 94 KB.
- **Comparisons as documented.** `GT`, `LT`, `GE`, `LE`, their `_IF`
  forms, the float `.GT` … forms and `DGE` mean what the manual
  (`stoic/stoic.mem`) and CP/M STOIC say: `B A GT` is true when B > A. The
  1985 VAX exes have them the other way round (`../doc/cmpfix.md`).
- **The console keeps its case.** The 1985 STOIC uppercases every line
  typed at the terminal. cmpfix passes it on as typed, so strings keep
  their lowercase letters, and STOIC's own words must be typed in
  uppercase (`../doc/cmpfix.md`, "Console case").

This guide builds STOIC.EXE, RED.EXE and REDHIREZ.EXE from these text
files alone. No binaries are needed: the build assembles the kernel and
links it, and STOIC then builds itself.

## What you need

- VAX/VMS with the MACRO-32 assembler and the linker. The guide was tested
  on VAX/VMS V5.5-2H4 on a SIMH MicroVAX 3900, on 22 October 2026, and
  has not been tried on other versions.
- About 1800 blocks of disk space: the sources, the object files and the
  exes.
- No privileges. Nothing is installed, and no system logical name is
  changed.

## 1. Make the directories

Choose a top directory and make three subdirectories in it, named exactly
KERNEL, STOIC and RED. The build finds them by these names relative to the
top directory.

```
$ CREATE/DIRECTORY [.CMPFIX]
$ CREATE/DIRECTORY [.CMPFIX.KERNEL]
$ CREATE/DIRECTORY [.CMPFIX.STOIC]
$ CREATE/DIRECTORY [.CMPFIX.RED]
```

## 2. Copy the sources

Copy these 34 files from this directory to the same places in the VMS
tree:

| VMS directory | Files |
|---|---|
| top | `ASSIGN.COM` `STOBUILD.COM` |
| `[.KERNEL]` | `DTINIT.MAR` `CRTL.MAR` `CONTROLC.MAR` `SS.MAR` `RMS.MAR` `TYIO.MAR` `TTIO.MAR` `RKERNEL.MAR` `EXTEND.MAR` `KERMAC.COM` `KERLINK.COM` `RKERNEL.OPT` |
| `[.STOIC]` | `RDEF.` `IMAGE.` `FLOAT.` `OBUF.` `VT100.` `STOIC.CRE` |
| `[.RED]` | `ERR.` `DYNA.` `E.` `WINDOW.` `EDV.` `EB.` `COMMAND.` `IMMED.` `CLI.` `CLIHIREZ.` `KBD.` `RED.` `RED.CRE` `HIREZ.CRE` |

Three things matter:

- **Copy them as text**, so that VMS stores them as variable-length
  records. With FTP, use ASCII mode (`ascii`, or curl's `--use-ascii`); in
  binary mode VMS stores them as fixed 512-byte records.
- **A file with no type needs a trailing dot** on VMS: `stoic/rdef` here is
  `RDEF.` there, and `red/e` is `E.`.
- The VMS names are case-insensitive, so `rdef` and `RDEF.` are the same
  file. The contents are not: keep them as they are, in uppercase.

The other files here are not needed to build:

- the manuals: `stoic/stoic.mem` (STOIC) and `red/red.mem` (RED), with
  `stoic/stoic.rno`, `red/red.hlp`, `red/redmanual.tab` and
  `red/rednews.txt`;
- `kernel/ss.src`, a listing that will not assemble;
- `kernel/rkernel.map`, the link map of the 1985 build;
- old or unused sources: `stoic/rdefold`, `red/windowold`, `red/etype`,
  `stoic/aipsplot`, `stoic/dupi`, `stoic/rem`, `kernel/foo.*`,
  `kernel/dker.com`, `kernel/list.com`, `kernel/txa2.lis`.

For example, with curl from a Unix host, where `vax` is the VMS host, the
`.netrc` file has your login, and the top directory is `[.CMPFIX]` in your
login directory:

```sh
cd cmpfix
for f in assign.com stobuild.com kernel/*.mar kernel/kermac.com \
         kernel/kerlink.com kernel/rkernel.opt \
         stoic/rdef stoic/image stoic/float stoic/obuf stoic/vt100 \
         stoic/stoic.cre \
         red/err red/dyna red/e red/window red/edv red/eb red/command \
         red/immed red/cli red/clihirez red/kbd red/red red/red.cre \
         red/hirez.cre; do
  case $f in kernel/foo.mar) continue ;; esac
  d=$(dirname $f | tr a-z A-Z); n=$(basename $f | tr a-z A-Z)
  case $n in *.*) ;; *) n=$n. ;; esac
  case $d in .) dir=%5B.CMPFIX%5D ;; *) dir=%5B.CMPFIX.$d%5D ;; esac
  set -- "$@" -T $f "ftp://vax/$dir/$n"
done
curl -sS --netrc -P - --use-ascii "$@"
```

The brackets are written `%5B` and `%5D`. `-P -` selects active mode,
which UCX FTP needs.

`aaareadme.doc` is the 1985 distribution's own guide. It is not needed to
build, but its sections 2 to 4 describe the same steps, and section 3.5
tells what to do if RED gives "quota exceeded" (the OBUF size and the
SYSGEN parameter MAXBUF). Its section 3, INSTALL, has not been tested with
cmpfix.

## 3. Build

Set your default to the top directory and run STOBUILD with `MAC`, which
assembles the kernel first:

```
$ SET DEFAULT [.CMPFIX]
$ @STOBUILD MAC
```

STOBUILD:

1. runs `ASSIGN.COM`, which defines the logical names SAO$KERNEL,
   SAO$STOIC and SAO$RED for the three subdirectories (in the process
   table) and the symbol `STOIC`;
2. in SAO$KERNEL, assembles the nine `.MAR` files (`KERMAC.COM`), links
   `RKERNEL.EXE` and copies it to `HEAD0.EXE` (`KERLINK.COM`);
3. in SAO$STOIC, runs RKERNEL, LOADs RDEF, IMAGE, FLOAT, OBUF and VT100,
   and writes `STOIC.EXE` with IMAGE (`STOIC.CRE`);
4. in SAO$RED, runs that STOIC.EXE, LOADs the eleven RED modules and
   writes `RED.EXE` (`RED.CRE`).

It leaves your default in SAO$RED. The assembler and linker print
nothing. STOIC prints what it loads:

```
Welcome to the STOIC kernel.
Loading RDEF
Loading IMAGE
Loading FLOAT
Loading OBUF
Loading VT100
[Creating STOIC.EXE]
Creating writable image
If installing in system, use /OPEN/HEAD switches only
Welcome to STOIC
Loading ERR
...
Loading RED
[Creating RED.EXE]
Creating writable image
If installing in system, use /OPEN/HEAD switches only
```

STOBUILD's last line suggests `@ORANGE.CRE`, for a terminal called the
INFOTON. That file was never distributed; ignore it.

For **REDHIREZ.EXE**, RED for the Selanar HiREZ terminal, run one more
procedure from SAO$RED:

```
$ @HIREZ.CRE
```

The result:

| File | Size (blocks) |
|---|---|
| `[.KERNEL]RKERNEL.EXE`, `HEAD0.EXE` | 44 each |
| `[.STOIC]STOIC.EXE` | 110 |
| `[.RED]RED.EXE`, `REDHIREZ.EXE` | 189 each |

`STOBUILD` without `MAC` relinks the existing object files and rebuilds
the exes, which is enough after a change to the STOIC or RED sources.

**Keep `[.KERNEL]HEAD0.EXE`.** IMAGE reads it each time it writes an exe,
through the logical name SAO$KERNEL, and refuses to work with a HEAD0
from another build.

## 4. Define the commands

Put these in your `LOGIN.COM`, with your own directory:

```
$ ASSIGN DUA1:[USERS.ME.CMPFIX.KERNEL] SAO$KERNEL
$ ASSIGN DUA1:[USERS.ME.CMPFIX.STOIC]  SAO$STOIC
$ ASSIGN DUA1:[USERS.ME.CMPFIX.RED]    SAO$RED
$ STOIC :== $SAO$STOIC:STOIC
$ RED   :== $SAO$RED:RED RED
$ CALC  :== $SAO$RED:RED FLODEF
```

SAO$KERNEL is needed only by IMAGE, and SAO$RED only by the two symbols
that use it.

## 5. Run

**STOIC.** The rest of the DCL command line is run as one STOIC line, and
`;F` at console level returns to DCL. The default radix is hex.

```
$ STOIC DECIMAL 2 3 + = CR ;F
 5
$ STOIC DECIMAL 1 2 GT = 2 1 GT = CR ;F
 0 -1
```

With no command tail, STOIC reads lines from the terminal until `;F` (or
CTRL/Z). To load a file of STOIC source:

```
'MYPROG.STO LOAD
```

STOIC's words are in uppercase, and the dictionary is case-sensitive.
Neither the terminal's lines nor a LOAD file's are uppercased, so type the
words in uppercase and write STOIC source files in uppercase. A lowercase
word is undefined, and in a LOAD file the compile error ends the LOAD.
Strings keep their case:

```
0> "Hello, World" MSG CR
Hello, World

0> decimal 1 2 + = cr
decimal
undefined error compiling...  decimal  ...in line
decimal 1 2 + = cr
```

**RED.** `RED file` edits a file on a VT100 or compatible terminal;
`H` on RED's command line leaves it. RED's manual is `red/red.mem`.

**CALC** is STOIC with the float words and decimal radix. `.=` prints
the top of the float stack, and `;F` returns to DCL:

```
$ CALC 2. 10. .^ .= CR ;F
 1024.000000000000
$ CALC 2. .SQRT 2. ./ .ASIN 4. .* .= CR ;F
 3.141592653589793
```

## Where to read more

- `stoic/stoic.mem`, the 1985 STOIC manual, and `../doc/errata.md`, its
  corrections. Those for defect 13 do not apply to cmpfix.
- `../doc/README.md`, the documentation of SAO STOIC and its tests: the
  language, the kernel, the word list, IMAGE, RED and the build.
- `../doc/patches.md`, every fix in cmpfix and in the patched tree it is
  based on, and `../doc/cmpfix.md`, the comparison change.

## How this guide was tested

On 22 October 2026 the 34 files listed above, and no others, were copied
by ASCII FTP into an empty tree, `[.WORK.CMPFRESH...]`, on VAX/VMS
V5.5-2H4. `@STOBUILD MAC` and `@HIREZ.CRE` ran there with no messages and
printed the lines above, and the exes had the sizes given. With these
exes, the regression suite (`../tests/`, 18 tests, among them CALC through
the command tail) gave exactly the output recorded for cmpfix in
`../tests/cmpfix/`, and the RED screen tests r0 and r1 drew the same
screens as `../tests/red/cmpfix/`. The examples in step 5 printed what is
shown there. The tree took 1773 blocks.

The console change (`kernel/rkernel.mar:1228`) was made after that test.
The tree it was made in, `[.WORK.CMPFIX...]`, then built with the same
output and sizes, and the suite, the defect tests, the interactive checks
and the RED tests gave the results recorded in `../doc/cmpfix.md`.
