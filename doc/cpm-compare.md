# Comparison sense: CP/M STOIC against VAX/VMS STOIC

Checked on 2026-10-21 against the CP/M 8080 STOIC (RunCPM, user area 10,
`STOIC.COM`; its source is `STOICBAS.STC`). This settles defect 13.

## Results

Typed at the CP/M STOIC console. The VAX column is `tests/02-compare.expected`
from the shipped `STOIC.EXE`, with `-^@^@^@1` written as −1.

| Word | Inputs | CP/M | VAX |
|---|---|---|---|
| `EQ` | `1 2`, `2 1`, `2 2`, `-1 1` | 0 0 −1 0 | 0 0 −1 0 |
| `NE` | the same | −1 −1 0 −1 | −1 −1 0 −1 |
| `GT` | the same | 0 −1 0 0 | −1 0 0 −1 |
| `LT` | the same | −1 0 0 −1 | 0 −1 0 0 |
| `GE` | the same | 0 −1 −1 0 | −1 0 −1 −1 |
| `LE` | the same | −1 0 −1 −1 | 0 −1 −1 0 |
| `EQZ` `NEZ` `GTZ` `LTZ` `GEZ` `LEZ` | `-1`, `0`, `1` | same as the VAX | |
| `-`, `/` | `1 2 -`, `6 3 /` | −1, 2 | −1, 2 |

The words that compare two values are reversed between the two systems.
The zero comparisons and the arithmetic are the same on both.

- **On CP/M, `B A GT` is true when B > A**, which is what `stoic.mem` says
  for the VAX ("−1 if B greater than A", `stoic/stoic.mem:567`). The GM guide
  says the same (`gm/newstoic.mem:1117`).
- **On the VAX it is true when A > B.**

`-` and `/` are B−A and B/A on both systems, so the VAX reverses only the
comparisons.

## Why, from the sources

- **CP/M** (`STOICBAS.STC`, "SIGNED COMPARISONS"): `'LT CODE< H POP, D POP,
  E A MOV, L SUB, D A MOV, H SBB, -1PUSH JM, ...`. HL gets A, DE gets B, the
  code computes B − A, and it pushes −1 when the result is negative, that is
  when B < A. `MAX` is `DDUP GT IF DROP ELSE UNDER THEN`, which keeps B when
  `GT` is true.
- **VAX** (`stoic/rdef:487-497`): `'GT : CMPL (P)+ (P)+ BGTR ITEFT ;`. VAX
  `CMPL src1,src2` compares src1 with src2, and here src1 is A, the top. So
  `BGTR` branches when A > B. The intended B > A needed the operands the
  other way round, or the opposite branch.
- **The VAX sources were written to match their own code**, not the manual.
  rdef's `MAX` (`rdef:654`) is `DDUP GT IF UNDER ELSE DROP THEN`, commented
  "is value2 greater?". That is the CP/M `MAX` with its branches swapped. The
  `*_IF` forms (`rdef:507-512`) and every other use agree with the code.

The original STOIC meaning, B A GT being B > A, is the one the manuals
describe. In SAO STOIC the comparisons came out reversed when they were
written as `CMPL (P)+ (P)+`, and rdef and RED were then written to fit that,
so in this tree the reversal is consistent everywhere except `stoic.mem`.

One oddity in the CP/M documentation: `KERNEL.DOC` (lines 378–394) describes
`LT` as "IF TOP LESS THAN TOP − 1". That is the VAX behaviour, not what the
CP/M code does. The CP/M code and its own `MAX` and `MIN` use B op A, so
the fault is in that wording, not in the code.
