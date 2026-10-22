# The current tree

`current/` (on the VAX `[.WORK.CURRENT...]`) is the tree under
development. It was made in Phase 8 under the name cmpfix, and renamed
later. It is the patched tree (`patches.md`) with two more changes:

- The words that compare two values mean what `stoic.mem` and CP/M STOIC
  say they mean. `B A GT` is true when B > A. In the shipped and patched
  STOIC it is true when A > B (defect 13, `cpm-compare.md`). Code written
  from the manual, or brought from another STOIC, runs unchanged
  here.
- The console is not uppercased (see "Console case" below). A line typed
  at the terminal reaches STOIC as it is typed, as a LOAD file's lines
  always have.

The exes are `DUA1:[USERS.CLAUDE.WORK.CURRENT.STOIC]STOIC.EXE` and
`[.WORK.CURRENT.RED]RED.EXE`.

## What changed

| Words | Before (VAX) | current (manual, CP/M) |
|---|---|---|
| `GT` `LT` `GE` `LE` | `B A GT` true when A > B | true when B > A |
| `GT_IF` `LT_IF` `GE_IF` `LE_IF` | the same sense as GT … | the same sense as the new GT … |
| `.GT` `.LT` `.GE` `.LE` and their `_IF` forms | A > B | B > A |
| `DGE` | A ≥ B (quadwords) | B ≥ A |
| `MIN`, `MAX` | the CP/M words with the branches swapped | the CP/M words (`stoic.mem:1263`) |

`EQ`, `NE`, the zero tests (`EQZ` … `LEZ` and their `_IF` forms), `-` and
`/` are the same on both systems and did not change.

### The definitions

Each definition keeps its compare and changes only its branch condition
(`current/stoic/rdef:491-497`, `507-510`; `current/stoic/float:91-94`,
`99-102`):

| Word | Before | current |
|---|---|---|
| `GT` | `BGTR` | `BLSS` |
| `LT` | `BLSS` | `BGTR` |
| `GE` | `BGEQ` | `BLEQ` |
| `LE` | `BLEQ` | `BGEQ` |
| `GT_IF` | `BLEQ` | `BGEQ` |
| `LT_IF` | `BGEQ` | `BLEQ` |
| `GE_IF` | `BLSS` | `BGTR` |
| `LE_IF` | `BGTR` | `BLSS` |

The float words change the same way. So the new `LT` compiles to exactly
the code the old `GT` did, and so on for each pair.

### The uses

`tools/cmp-swap` swaps GT with LT and GE with LE, with their `_IF` and `.`
forms, wherever they are words of code in the STOIC and RED sources: not
after a `%` comment word, not in a `"string"`, and not as a `'NAME`. Each
swapped use compiles to the same code as before, so every word in rdef,
image, float, obuf, vt100 and RED keeps its length, its address and its
behaviour. It changed 108 uses in 15 files, including `rdefold` and
`windowold`, which are not built. A search found no comparison word run
by name (`()`, a `'NAME` table, or a string to be compiled).

Many uses now read the natural way: `DUP ASCII a GE OVER ASCII z LE AND`
in RED's `cli` asks whether a character is from a to z.

Three words were then written by hand:

- **MIN and MAX** take the CP/M form, `DDUP LT IF DROP ELSE UNDER THEN` and
  `DDUP GT IF DROP ELSE UNDER THEN`: the same words in another order, so
  the same length. They give the same results as before
  (`tests/cmp/C1-MINMAX`).
- **DGE** keeps its `GE` (`current/stoic/rdef:565`), so it takes the new
  sense: value1 ≥ value2. Nothing in the sources uses it.

The kernel has no comparison words, and the GM variant (`gm/`) has its
own; neither changed. `stoic.mem` needs no change: it describes the
current tree. Its errata for defect 13 (`errata.md`) apply only to the shipped and
patched exes, and say so.

The other fixes are those of the patched tree. One of them has a
comparison of its own: RED's `[` refuses a 25th level (defect 49) with
`C.LOOP_COUNT @ 18 LT_IF` here (`current/red/cli:1511`) where patched
has `18 GT_IF`.

## Console case

The shipped and patched kernels set CVT, as well as PMT, in the ROP of the
console's RAB (`patched/kernel/rkernel.mar:1228`, SETUP_FABS). So RMS has
the terminal driver uppercase each line as it is typed: the echo shows
the uppercase letters, and STOIC never sees lowercase from the terminal.
The current tree sets only PMT (`current/kernel/rkernel.mar:1228`). The
prompt is unchanged.

The dictionary is case-sensitive, so in the current tree:

- the built-in words must be typed in uppercase: `decimal` is undefined;
- `hello` and `HELLO` are two different words;
- strings keep their case: `"Hello, World" MSG` prints `Hello, World`.

`tests/interactive/case.tcl` shows each of these, and that ROP of RAB 0
(`CHANNEL_LIST @ @ 4 + @`) is 40000000 (PMT) in the current tree
(`tests/interactive/current/case.log`). On the patched exe it is 44000000
(PMT+CVT), and every line of the same check reaches STOIC in uppercase
(`tests/interactive/patched/case.log`); the shipped kernel sets the same
bits (`saostoic-text/kernel/rkernel.mar:1099`). The same experiment on the
earlier exe of this tree, clearing and setting CVT in that cell by hand,
gave the same results with CVT clear, and uppercasing again with it set.

LOAD files, channels 1–3, never had CVT, and the tools type their console
lines from a DCL procedure, where CVT has no effect. RED reads its keys
with its own QIOs. So no result of the suite, the defect tests or RED's
scripts changed (see "Testing").

## Building

`current/README.md` is a guide for anyone building the current tree on
their own VAX from its 34 text files. A build that way, in an empty
`[.WORK.CMPFRESH...]`, gave the same build output and exe sizes, and the same regression suite
and RED r0–r1 results, as the build below.

Here, the current tree is built like the patched tree (`build.md`, "The
patched build"), in `[.WORK.CURRENT...]`:

1. `tools/vax-do -p CURRENT tools/setup-patched.com` BACKUPs
   `[.SAOSTOIC...]` to `[.WORK.CURRENT...]`, once.
2. `STOIC_TREE=current tools/patched-push` copies each file under
   `current/` that differs from `saostoic-text/`.
3. `tools/vax-do -p MAC -p CURRENT -t build/current/build-terminal.txt
   tools/patched-build.com` assembles, links and builds STOIC.EXE, RED.EXE
   and REDHIREZ.EXE.

The build gives no messages, and the exes are the size of the patched ones.

## Testing

Swapping the uses keeps the code of every word the same, so the current tree must
behave exactly as patched except where a program names a comparison word
itself. Each test set was run on both:

| Tests | Run on the current tree with | Result |
|---|---|---|
| Boundary tests `tests/cmp/` C1–C8: MIN and MAX, number output, MOVE_BYTES, SEARCH_STRING, strings, float output, the VT100 words, WHAT. They use no comparison word, and exercise the rdef, float and vt100 words whose code does | `STOIC_TREE=current tools/patched-suite --cmp` | 8/8 identical to `tests/cmp/patched/` |
| The regression suite `tests/` (18) | `… patched-suite --update`, into `tests/current/` | identical to `tests/patched/` apart from 02-compare and 12-float |
| The defect tests `tests/fix/` (39) | `… patched-suite --fix --update`, into `tests/fix/current/` | identical to `tests/fix/patched/` apart from F15-DGE |
| IMAGE groups a-pat, e-pat, f, g | `STOIC_TREE=current tests/image/run …`, into `tests/image/results/current/` | identical apart from dates and the exes' paths |
| The big application and the code-space fill (`tests/big/`) | `STOIC_TREE=current tests/big/run`, `runfill` | identical to the patched results |
| RED scripts r0–r12 (not r6, which needs the shipped RED) | `STOIC_RED=…CURRENT.RED]RED.EXE tools/red-drive -o tests/red/current …` | identical screens apart from r5's file dates and the `^c` step of r7 (below). r12 checks the 24-level limit of `[` (defect 49) |
| The interactive checks `tests/interactive/*.tcl` | `STOIC_EXE=…CURRENT.STOIC]STOIC.EXE tools/vax-interact -o tests/interactive/current …` | identical to `tests/interactive/patched/` apart from `case`, which shows the console change |

The suite, the defect tests, the RED scripts and the interactive checks
were run again after the console change, with the results above.

r9 interrupts a loop with ^C after 3 s, so where the loop stops can vary
by a step from run to run on either build. So does r7, which interrupts
an endless iteration: after the console change its `^c` screen already
showed "Command aborted.", where the recorded one still showed the loop.
The unchanged patched RED, run again the same day, gave the new screen
too. The patched r9, r10 and r10b
screens were re-recorded for this comparison: r10's word addresses had
been recorded before defect 49's change to CLEAR_L_STACK.

### How the tests run on the current tree

With `STOIC_TREE=current`, `tools/patched-suite` runs the current exes and
first passes the tests through `tools/cmp-swap`, so that a test that only
*uses* a comparison (04-control's REPEAT loop, 05-define's FACT, F03-IOSB)
means what it did on patched. Unswapped, 04-control's
`0 BEGIN DUP 5 GT IF DUP = 1+ REPEAT` never ends on the current tree. The helpers in
`tests/files/` (UTIL.STO's `.S`) and `tests/image/imgutil.sto` are swapped
the same way. Left as they are:

- **02-compare, 12-float and F15-DGE**, which test the comparison words
  themselves: their results are the new ones.
- **F28-HEAD0**, which LOADs the patched IMAGE source into the rebuilt
  (old-sense) STOIC.EXE. Given the current IMAGE source there, its check
  `ISD @ 2+ W@ OVER LE IF` (`current/stoic/image:90`, `GE` in patched)
  would read the wrong way round, and IMAGE would refuse to write the exe.

### The tests that differ

Only the tests of the comparison words give new results, and each is what
the manual says (`stoic.mem:567`):

| Test | patched | current |
|---|---|---|
| 02-compare `GT` on `1 2`, `2 1`, `2 2`, `-1 1` | −1 0 0 −1 | 0 −1 0 0 |
| 02-compare `LT` | 0 −1 0 0 | −1 0 0 −1 |
| 02-compare `GE` | −1 0 −1 −1 | 0 −1 −1 0 |
| 02-compare `LE` | 0 −1 −1 0 | −1 0 −1 −1 |
| 02-compare `GT_IF` … `LE_IF` on `1 2`, `2 1`, `2 2` | 1 0 0, 0 1 0, 1 0 1, 0 1 1 | 0 1 0, 1 0 0, 0 1 1, 1 0 1 |
| 02-compare `DGE`, `DGE LOW` | 0 −1 0, −1 0 | −1 0 −1, 0 −1 |
| 12-float `CMP`: `1. 2. .GT`, `2. 1. .GT`, `1. 1. .EQ`, `1. .GTZ` | −1 0 −1 −1 | 0 −1 −1 −1 |
| F15-DGE, line 1 | −1 0 −1 0 | 0 −1 0 −1 |
| F15-DGE, line 2 | −1 0 −1 0 | −1 −1 0 −1 |

The four rows of 02-compare on the current tree are the CP/M STOIC rows of
`cpm-compare.md`. F15-DGE's second line differs in more than the sign
because its first pair is equal (`0 7 0 7`): B ≥ A and A ≥ B both hold.
F15-DGE's comment gives the right answers for the old sense; on the current tree
the right answers are B ≥ A for each pair, as above.
