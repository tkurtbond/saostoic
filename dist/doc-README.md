# SAO STOIC for VAX/VMS: documentation

These documents come from the SAO STOIC repository,
<https://github.com/tkurtbond/saostoic>, where SAO STOIC was tested on a
SIMH MicroVAX 3900 under VAX/VMS V5.5-2H4 in October 2026. They describe
STOIC and RED as they actually behave, as a companion to the 1985 manuals,
`../stoic/stoic.mem` and `../red/red.mem`.

**Most of them describe the 1985 exes.** The sources in this distribution
differ from those in two ways that matter when you read them:

- **The comparisons are the other way round.** In the 1985 exes, `B A GT`
  is true when A > B, the reverse of the manual. In these sources it is
  true when B > A, as the manual says. Where `language.md`, `words.md` or
  `float.md` describe `GT`, `LT`, `GE`, `LE`, their `_IF` and `.` forms or
  `DGE`, swap them. `current.md` gives the details.
- **46 of the 50 defects are fixed.** `defects.md` describes each one as it
  was in 1985; `patches.md` says which are fixed here and how.

Each claim cites a source line or a test. The source lines are in the
1985 sources (`saostoic-text/` in the repository), and the line numbers
may differ slightly in these sources. The tests (`tests/`) and tools
(`tools/`) are in the repository too, not in this distribution.

## Reading order

| Document | What it covers |
|---|---|
| `current.md` | What these sources change from the 1985 ones: the comparison words, and the console keeping its case. Read it first. |
| `language.md` | The language as a programmer meets it: how a line runs, literals, radix, comparisons, definitions, control structures, the loop stack, branches, strings, the assembler, errors, and the differences from `stoic.mem`. |
| `errata.md` | Corrections to `stoic.mem` and `red.mem`, in manual order. Those for defect 13, the comparisons, do not apply to these sources. |
| `words.md` | Every word in the 1985 STOIC.EXE, by branch, with its kind, stack effect and source line. The addresses are the 1985 exe's. |
| `float.md` | The float stack, float literals, the `FLOAT<` words, output formats, the MTH$ words, float errors and CALC. |
| `red.md` | RED, the screen editor: buffers, the command line, the keypad, the display, and how it differs from `red.mem`. |
| `image.md` | IMAGE, which writes the running STOIC as a new `.EXE` without the linker, and SAVE/XLOAD. |
| `kernel.md` | The MACRO-32 kernel: registers, memory layout, the dictionary, the compiler and the outer loop, I/O, errors and CTRL/C, startup. |
| `defects.md` | The 50 defects found, each with a repro, the cause, the impact and a suggested fix. |
| `patches.md` | The fix for each defect, with its test, and what behaves differently from the 1985 exes. |
| `build.md` | How the 1985 sources were rebuilt on V5.5-2H4. To build these sources, follow `../README.md` instead. |
| `cpm-compare.md` | CP/M STOIC's comparison words, which show that the VAX reversed the intended sense. |
