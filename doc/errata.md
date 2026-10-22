# Errata for the STOIC and RED manuals

This lists each place where a manual disagrees with the code, with the
correction. The manuals themselves (`saostoic-text/stoic/stoic.mem` and
`saostoic-text/red/red.mem`) are left as they are. The evidence for each
entry is in [`language.md`](language.md) ("Differences from stoic.mem"),
[`red.md`](red.md) and [`defects.md`](defects.md); this page gathers it in
manual order.

The **Patched build** column says what the Phase 6 build
(`[.WORK.PATCHED...]`, see `defects.md`) does:

- *as corrected*: the patched build keeps the code's behaviour, so the
  correction stands;
- *now as the manual*: a fix made the code agree with the manual, so the
  entry applies only to the shipped exes;
- *changed*: a fix changed the behaviour, but not to the manual's.

The cmpfix build ([`cmpfix.md`](cmpfix.md)) is the patched build with the
comparison words as in the manual; the two rows where it differs say so.

Line numbers are those of the Unix-text copies. Rows without one
correct something the manual implies rather than states.

## stoic.mem (June 1980)

`stoic.mem` describes an earlier and partly PDP-11 STOIC. A, the top of
stack, and B, the item below it, are as the manual uses them.

| Where | The manual says | Correction | Patched build | Defect, evidence |
|---|---|---|---|---|
| 103-104 | an integer literal may have a leading `+` | `+5` is an undefined word; only `-` is a sign | as corrected | `tests/11-errors.con` |
| 109 | integer literals must be in range | out-of-range literals wrap mod 2³² without an error | changed: "Number too large", a compile error | 5; `tests/06-numio` "BIG" |
| 521 | `MOD` is the remainder of B/A | the dividend is unsigned: `-7 3 MOD` is 0 and `-7 2 MOD` is 1 | now as the manual: `-7 3 MOD` is −1 | 12; `tests/01-arith` |
| 521 | `/MOD`: signed, by implication from MOD | the dividend is unsigned: `-42 6 I=` prints `967254` | now as the manual (signed); `I=` and `<#>` still print unsigned | 12; `tests/06-numio` |
| 567, and LT, GE, LE | `GT` gives −1 if B is greater than A | the reverse: −1 if **A** is greater than B, so `1 2 GT` is −1. Every use in the sources expects this. CP/M STOIC does what the manual says, so the VAX words are the opposite of CP/M's (see below) | as corrected; cmpfix: now as the manual | 13; `tests/02-compare`, `rdef:487-497`, `cpm-compare.md` |
| 855 | prints the number, signed | a negative number prints as `-`, three NULs, then the digits | now as the manual | 14; `tests/01-arith` |
| 881, 937, 2067, 2289-2297 | `FILL`, `0FILL`, `MVBYTES`, `OCTAL`, `ERR` | not in the exe; `MOVE_BYTES` exists | as corrected | `doc/data/stoic-inventory.txt` |
| 1263 | `MAX` is `DDUP GT IF DROP ELSE UNDER THEN` | that is CP/M STOIC's MAX. With the VAX sense of GT it keeps the smaller value; rdef's MAX swaps the branches | as corrected; cmpfix: now as the manual | 13; `rdef:654-658` |
| 1627 | `J'` and `K'` exist | not defined; only `I'` | as corrected | `doc/data/stoic-inventory.txt` |
| 1634-1636 | inside `( )`, I runs from n down to 1 | I runs from 0 up to n − 1 | as corrected | `tests/04-control` "PAREN"; `rdef:711` |
| 1669-1670 | `5 0 DO I = LOOP` prints `1 2 3 4` | prints `0 1 2 3 4` (a typo) | as corrected | `tests/04-control` "DO" |
| 1825-1834 | `%` starts a comment only as a separate word, and a separate `%` ends it | any word that **starts** with `%` opens a comment, which ends at the next `%`, wherever it is | as corrected | `rkernel.mar:1511-1517` |
| 2063 | CTRL/C invokes ABORT | only the first CTRL/C in a session works | now as the manual: every CTRL/C aborts | 2; `tests/interactive/ctrlc3.tcl` |
| 2235-2237 | `ARRAY` takes its length in 16-bit words and zeroes the array | the length is in longwords, and ARRAY stores nothing | as corrected | `rdef:930-934`; `tests/05-define` "ARRAY GAP", `tests/lang/L4-FORGET.con` |
| 2433 | `() NAME` pushes the parameter field | it pushes the code address | as corrected | `rdef:567-577` |
| 3145 | the kernel has two vocabularies, `STOIC<` and `ASSEMBLER<` | also `TTIO<` and `FLOAT<`; rdef adds `IORB<` | as corrected | `rkernel.mar:1873-1895`; `rdef:948` |
| 3183-3185 | popping the last vocabulary gives VOCABULARY STACK EMPTY | `>` has no check; after it every line faults | now as the manual: "Vocabulary stack empty." | 40; `tests/lang/L3-POP.con` |
| Appendix A | the loop stack holds index, low, high | it holds the count (limit − I), the start and the limit | as corrected | `rdef:670-676`, `711-719` |
| (files) | a missing file is an error | LOAD or OPEN of a missing file exits STOIC | now as the manual: an error message, and the line ends | 7; `tests/11-errors.con` |
| (strings) | `""` is an empty string, by implication | `""` runs on to the next quote; there is no empty string literal | as corrected | `tests/07-strings` "EMPTY" |

The manual notes that `^` (continue to the next line), the line-feed
repeat and `ADDRESS` are not implemented in VMS STOIC (`stoic.mem:1999`,
`2015`, `845`). That is right: none of them is in the exe.

### The comparison words: the VAX against CP/M STOIC

`GT`, `LT`, `GE` and `LE` on the VAX do the **opposite** of the same words
in CP/M STOIC. CP/M STOIC does what `stoic.mem` says (`stoic.mem:567`), and
so does the GM guide (`gm/newstoic.mem:1117`). Checked on the CP/M 8080
STOIC under RunCPM and against `tests/02-compare` on the VAX
([`cpm-compare.md`](cpm-compare.md)):

| Word | Inputs `1 2`, `2 1`, `2 2`, `-1 1` on CP/M | the same on the VAX |
|---|---|---|
| `B A GT` | 0 −1 0 0: true when B > A | −1 0 0 −1: true when **A > B** |
| `B A LT` | −1 0 0 −1: true when B < A | 0 −1 0 0: true when **A < B** |
| `B A GE` | 0 −1 −1 0: true when B ≥ A | −1 0 −1 −1: true when **A ≥ B** |
| `B A LE` | −1 0 −1 −1: true when B ≤ A | 0 −1 −1 0: true when **A ≤ B** |

- So on the VAX, `GT` means what `LT` means on CP/M, and `GE` what `LE`
  means, and the other way round.
- `EQ`, `NE`, the zero comparisons (`EQZ` … `LEZ`), `-` and `/` are the
  same on both. `-` is B − A and `/` is B / A on both.
- The cause is `'GT : CMPL (P)+ (P)+ BGTR ITEFT ;` (`rdef:487-497`): the
  first operand of `CMPL` is A, the top of stack, so `BGTR` branches when
  A > B. CP/M's `LT` computes B − A and is true when it is negative.
- rdef and RED were written to fit the VAX sense: rdef's MAX
  (`rdef:654-658`) is CP/M's with its branches swapped. The patched
  build therefore keeps it. Code written for CP/M STOIC, or from the
  manual, must swap `GT` with `LT` and `GE` with `LE` (or swap the
  operands) to run on the VAX.
- The cmpfix build ([`cmpfix.md`](cmpfix.md)) has the CP/M sense: its
  `tests/cmpfix/02-compare.expected` gives the CP/M column above, and its
  MAX is CP/M's. There the manual is right, and code from CP/M STOIC runs
  unchanged.

## red.mem

| Where | The manual says | Correction | Patched build | Defect, evidence |
|---|---|---|---|---|
| 1.2 (90-96) | `nTF` is illegal if n < 1 or n > 10 | n is clamped to 1–10: `11TF` gives 10 | as corrected | 36; `cli:817-823`, `tests/red/r2-args` `11tf` |
| 2.0 (155-159) | the up arrow moves to the beginning of the previous line | from the middle of a line it moves to the start of the **current** line; only from the start of a line does it reach the previous one | now as the manual | 33; `eb:65-72`, `tests/red/r4-keys` `up-mid`, `up-bol` |
| 2.0 | (the instant keys) | also: keypad ENTER toggles immediate mode, and ESC S leaves RED for the STOIC prompt, where `REDOUT` resets the terminal and `;F` returns to DCL | as corrected | 36; `kbd:290`, `kbd:330`, `tests/red/r0-smoke`, `r4-keys` |
| 4.4 (486-487) | numbers are in the current input radix | always decimal: `TI`, the set-radix command, says "Command not implemented." | as corrected | 36; `cli:825-827`, `tests/red/r2-args` `ti` |
| 4.4 (571) | `'` is logical NOT | `'` is **postfix**: `0'` is −1, and `'0` is "Invalid command." | as corrected | 36; `tests/red/r2-args` `not` |
| 5.1 | (the insert commands) | also: `n^W` inserts n as a decimal number, and `,` enters INPUT MODE (RETURN starts a line, DELETE rubs out, LF ends the mode) | as corrected | 36; `cli:1094-1099`, `cli:1198`, `tests/red/r3-buffers`, `r7-modes` |
| 5.6 (1200-1219) | three replies: ESC replaces, LF skips, any other key exits | RETURN replaces, like ESC; SPACE exits; any other key rings the bell and waits. The prompt RED draws says so | as corrected | 35; `cli:1217-1220`, `tests/red/r7-modes` `cond-*` |

Appendix A of `red.mem` describes the INFOTON-200 version, whose
`ORANGE.CRE` is not in the tree; it is not checked here.
