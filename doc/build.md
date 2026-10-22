# Building SAO STOIC from source on VAX/VMS V5.5-2H4

Phase 2 of `PLAN.md`, run on 2026-10-21. The sources in
`[.SAOSTOIC...]` rebuild the shipped kernel, `STOIC.EXE`, `RED.EXE` and
`REDHIREZ.EXE` on V5.5-2H4 with **no changes and no diagnostics**. The
rebuilt STOIC behaves the same as the shipped one; only addresses differ.
The rebuild needed no changes. The Phase 6 fixes are built separately: see
"The patched build" at the end.

The evidence is in `build/`:

| File | What it is |
|---|---|
| `BUILD.COM` | the procedure that was run (with `tools/vax-do`, in `[.WORK]`) |
| `BUILD.LOG` | its `/OUTPUT` log: every DCL, MACRO and LINK line |
| `build-terminal.txt` | what STOIC wrote to the terminal during the build |
| `rkernel-rebuilt.map` | the new `RKERNEL.MAP`; the shipped one is `saostoic-text/kernel/rkernel.map` |
| `analyze-ship-*.txt`, `analyze-new-*.txt` | `ANALYZE/IMAGE` of the shipped and the rebuilt images |
| `analyze-summary.txt` | the same, cut down by `tools/ana-summary` to the header and ISD list |
| `suite-rebuilt.txt` | the Phase 1 suite run against the rebuilt STOIC and RED |
| `analyze-shipped.com`, `compare-objects.com`, `hirez.dcl` | the other procedures used here |

## How to build

In a copy of the tree (here `[.WORK.SAOSTOIC]`, made by
`tools/setup-work.com`):

    $ SET DEFAULT [.WORK.SAOSTOIC]
    $ @STOBUILD MAC          ! MAC: assemble too; without it, only link
    $ SET DEFAULT SAO$RED
    $ @HIREZ.CRE             ! optional: REDHIREZ.EXE

`STOBUILD.COM` runs `ASSIGN.COM`, which points `SAO$KERNEL`, `SAO$STOIC`
and `SAO$RED` at the subdirectories of the *current default directory*.
So the build writes into whatever copy you start it in, and nothing
outside it. Then it:

1. runs `KERMAC.COM`, which assembles the nine kernel modules
   (`DTINIT CRTL CONTROLC SS RMS TYIO TTIO RKERNEL EXTEND`);
2. runs `KERLINK.COM`, which links `RKERNEL.EXE` with `RKERNEL.OPT` and
   copies it to `HEAD0.EXE`, the header prototype IMAGE reads;
3. runs `STOIC.CRE`, which runs RKERNEL, LOADs `RDEF IMAGE FLOAT OBUF
   VT100` and writes `STOIC.EXE` with `IMAGE`;
4. runs `RED.CRE`, which runs that STOIC, LOADs the eleven RED modules and
   writes `RED.EXE`.

Its closing suggestion, `@ORANGE.CRE`, refers to a file that is not in the
tree.

The whole build took under a minute on the SIMH MicroVAX 3900. STOIC
prints its progress to the terminal, not to the log: "Loading RDEF" and so
on, then "Creating writable image" and "If installing in system, use
/OPEN/HEAD switches only" from IMAGE (`build-terminal.txt`).

The `.MAR` sources are dated 1982–85 and every shipped `.OBJ` is newer
than its source, so the shipped objects were made from these sources.

## Diagnostics

None. MACRO V5.4-3 assembled all nine modules and LINK V05-13 linked them
without a single message, not even about `UNIVERSAL=START` in an
executable image (`BUILD.LOG`).

## Kernel: shipped and rebuilt

The shipped kernel was assembled by VAX-11 MACRO V03-00 (`CONTROLC`,
`TYIO` and most others on 5 April 1984; `RMS` and `RKERNEL` on 4 September
1985) and linked by LINK V03-05 on 4 September 1985. The psect bases are
the same: DATINIT at 200, DICTIONARY (`DICT_START`) at F800, KERNEL
(`K_START`) at 1FC00. DATINIT and DICTIONARY are the same length, and so is
every module's contribution except two:

| Module (KERNEL psect) | Shipped | Rebuilt | Why |
|---|---|---|---|
| CONTROLC | FA | FC | one `$ASSIGN_S` (`controlc.mar:59`) |
| TYIO | 3C3 | 3C9 | three `$ASSIGN_S` (`tyio.mar:96, 236, 252`) |

The V5 `$ASSIGN_S` macro passes five arguments where the V3 one passed
four: each call has an extra `PUSHL #0` (`DD 00`) and `CALLS #5` in place
of `CALLS #4`. That is 2 bytes a call and 8 in all. Everything in the KERNEL
psect after the first `$ASSIGN_S` moves up by 2, 4 or 8 bytes; `START`, the
transfer address, goes from 20DD2 to 20DDA.

The STOIC word `$ASSIGN` (`ss.mar:179`) is not affected. `SS` makes each
word from the `_G` form (`$ASSIGN_G (R10)`), whose argument list, count
included, is the one on the STOIC stack.

The other differences in the objects change nothing:

- V3 MACRO left a placeholder mode byte for an operand naming an external
  symbol and had the linker fill it in. V5 MACRO writes `9F` (`@#`,
  absolute) itself.
- The psect numbering differs (V3 MACRO also made an empty `. BLANK .`
  psect), and V5 MACRO writes a traceback record.

## Images: shipped and rebuilt

From `analyze-summary.txt`. Every image has a one-block header and the
same ISD layout:

| ISD | Base | What it is |
|---|---|---|
| 1, 2 | 200 | DATINIT, then the demand-zero rest of its 64 KB |
| 3, 4 | F800 | DICTIONARY, then demand-zero |
| 5, 6 | 1FC00 | KERNEL, then demand-zero |
| 7 | 2FC00 | the image activator's fixup vector |
| 8 | 7FFFD800 | user stack, 20 pages |
| 9 on | | shareable images |

IMAGE grows ISDs 1, 3 and 5 by the pages STOIC has filled, marks them
no-write, and shrinks the demand-zero ISD that follows by as many pages
(ISD 1 + ISD 2 is 123 pages in every image). The rebuilt images agree
with the shipped ones page for page in ISDs 1–6:

| Image | ISD 1 | ISD 3 | ISD 5 |
|---|---|---|---|
| RKERNEL | 3 | 16 | 17 |
| STOIC | 10 | 41 | 46 |
| RED | 14 | 62 | 97 |

The differences, the same for RKERNEL, STOIC and RED:

| | Shipped | Rebuilt |
|---|---|---|
| Transfer address | 20DD2 | 20DDA |
| Linker | V03-05, 4-SEP-1985 | V05-13 |
| ISD 7 (fixup vector) | 1 page | 2 pages |
| Shareable images | VMSRTL_001, SCRSHR_001 | FORRTL_001, SCRSHR_001, LIBRTL_001, MTHRTL_001 |

The V3 linker resolved the run-time library through the V3 VMSRTL; the V5
linker resolves the same routines in V5's split libraries. More shareable
images need more fixups, which is ISD 7's extra page.

### REDHIREZ

The shipped `REDHIREZ.EXE` is older than the rest: its kernel was linked
on 8 November 1983 (transfer address 20DA6), and its demand-zero ISDs are
no-write as well as its resident ones. VMS V5.5-2 refuses to run it:

    %DCL-W-ACTIMAGE, error activating image ...REDHIREZ.EXE
    -SYSTEM-F-BADISD, illegal image section descriptor

That is the V4 breakage that `IMAGE_WRT` in `stoic/image` was written to
fix. The rebuilt `REDHIREZ.EXE` is the same as `RED.EXE` (ISD for ISD),
and it runs: `REDHIREZ FLODEF 2. 3. .+ .= CR ;F` prints `5.000…`
(`hirez.dcl`). `CLIHIREZ` differs from `CLI` only in the limits of the
TF command (a 48-line screen).

## The suite against the rebuild

    tools/stoic-suite -x 'DUA1:[USERS.CLAUDE.WORK.SAOSTOIC.STOIC]STOIC.EXE;2' \
                      -r 'DUA1:[USERS.CLAUDE.WORK.SAOSTOIC.RED]RED.EXE;2'

13 of 18 pass unchanged. The other 5 (`10-files`, `11-errors`,
`12-float`, `12-math`, `15-sys`) differ only in numbers that are addresses,
and in REVISION, which is the time IMAGE wrote the exe
(`suite-rebuilt.txt`). With every number of five or more digits replaced by
`N`, the shipped and rebuilt lines are identical. There are two kinds of
address:

- **Code addresses in the KERNEL psect** (`C=` in tracebacks, fault PCs,
  return addresses into the kernel) are 2, 4 or 8 higher, as the map says.
  Addresses in rdef's code (`ERROR_TRACE` at 23998, for one) are not
  moved: user code starts at the page after the kernel's own
  (`USER_CODE`, `rkernel.mar:1987`), which is 21E00 in both.
- **Addresses in the `$EXPREG`'d regions** (the stacks, the compile
  buffer, the user table R11) are 4F800 lower: the compile buffer is at
  7F400 rather than CEC00, R10 is 7E600 rather than CDE00 and R11 884F9
  rather than D7CF9. `$EXPREG` adds pages at the end of P0, after the
  shareable images the activator mapped, so the regions start wherever
  those end. VMSRTL on V5.5 is a compatibility image that brings more with
  it than the four libraries the rebuild links against directly; that it
  accounts for exactly 4F800 has not been checked.

So the P0 layout above the image depends on which shareable images it was
linked against, and SAVE files (defect 11) are tied to one exe.

## On the VAX afterwards

The build left new versions beside the shipped ones in
`[.WORK.SAOSTOIC...]`: `;1` is the shipped file and `;2` the rebuilt one,
for every `.OBJ`, `RKERNEL.EXE`, `HEAD0.EXE`, `RKERNEL.MAP`, `STOIC.EXE`,
`RED.EXE` and `REDHIREZ.EXE`. Anything that names one of these without a
version now gets the rebuilt one: `SAO$KERNEL:HEAD0.EXE`, which IMAGE
reads, and the `STOIC`, `RED` and `CALC` that `work-assign.com` defines.
`tools/stoic-run` therefore sets `STOIC`, `RED` and `CALC` itself, from `-x`
and `-r`, which default to the shipped binaries in `[.SAOSTOIC...]`.

## The patched build

Phase 6 builds the fixed sources ([`patches.md`](patches.md)) the same way,
in a third copy of the tree, `[.WORK.PATCHED...]`:

1. `tools/vax-do tools/setup-patched.com` BACKUPs `[.SAOSTOIC...]` to
   `[.WORK.PATCHED...]`, once.
2. `tools/patched-push` copies each file under `patched/` that differs
   from `saostoic-text/` there, by ASCII FTP in one session.
3. `tools/vax-do -o build/patched -t build/patched/build-terminal.txt
   tools/patched-build.com` runs `STOBUILD MAC` and `HIREZ.CRE` in
   `[.WORK.PATCHED]`. It keeps three versions of each built file and lists
   the exes. With P1 `LINK`, it skips the assembly.

A good build assembles and links with no messages. Its terminal output
(`build/patched/build-terminal.txt`) loads the five STOIC modules and then
the RED modules twice, once with CLI and once with CLIHIREZ, and shows
"Creating writable image" three times: for STOIC.EXE, RED.EXE and
REDHIREZ.EXE.

The results are in `[.WORK.PATCHED.KERNEL]` (RKERNEL.EXE and HEAD0.EXE),
`[.WORK.PATCHED.STOIC]STOIC.EXE` and `[.WORK.PATCHED.RED]` (RED.EXE and
REDHIREZ.EXE). `tools/patched-assign.com` points `SAO$KERNEL`,
`SAO$STOIC` and `SAO$RED` at them, and defines `STOIC`, `RED` and `CALC`.
`tools/patched-suite` and the `STOIC_EXE` and `STOIC_RED` variables of
`vax-interact` and `red-drive` run tests against them.

The patched build differs from the plain rebuild in how memory is laid
out (defect 22). Before it `$EXPREG`s its regions, the kernel grows P0 to
400000 (`fix_p0`). So USER_DATA is 402200 whatever shareable images the
exe was linked against. This also keeps the addresses that obuf freezes
at load time valid in RED.EXE (defect 30).

Phase 7 pads the patched KERNEL psect to 40000 bytes, not 10000
and the DICTIONARY psect to 20000 (`patched/kernel/extend.mar`). The map
shows DICTIONARY at FA00–2FC46 and KERNEL at 2FE00–7012C, and the images
are a few blocks larger: the extra pages are demand-zero. K_END, where
"Code space full." starts, is a page below the psect's end, at 6FF2D; the
spare page lets IMAGE write an exe whose code is full (`image.md`).
