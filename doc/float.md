# Floating point

This is Phase 5 of `PLAN.md`: the floating-point part of SAO STOIC. The
package is `stoic/float` (Jonathan Mark, 1982), and the kernel's float
support is in `kernel/rkernel.mar` (literals and the FS stack) and
`kernel/crtl.mar` (conversions and the MTH$ and OTS$ calls). Paths are under
`saostoic-text/`. Values are hex unless they say otherwise.

**Result:** floats are VAX D_floating numbers on a stack of their own, FS
(R7). Arithmetic, comparisons and conversions work as the tests below show.
Output goes through FOR$CVT_D_TG and the functions through MTH$ and OTS$.
The known faults are:

- errors from MTH$ and OTS$ are not reported (defect 17);
- `.SQRT` of a negative number ends STOIC (defect 18);
- `.FLIP` loses the low half of each value (defect 16);
- a float literal's text is read as decimal in any radix (defect 5);
- in a LOAD file, a lowercase word can compile as a float (defect 1).

The tests are `tests/12-float.sto`, `tests/12-math.sto`,
`tests/13-calc.dcl` and part of `tests/06-numio.sto`, each with its
`.expected` file.

## The FS stack

| Property | Value | Source |
|---|---|---|
| Register | R7 | `kernel/rkernel.mar:69` |
| Element | D_floating, 8 bytes | `MOVD`, `CVTLD` throughout `stoic/float` |
| Size | 1 page (512 decimal bytes, 64 decimal values) | `fp_stack_size=1`, `kernel/rkernel.mar:78` |
| Allocation | `$EXPREG`'d at startup, with a no-access moat page in front | `kernel/rkernel.mar:292-294`, `kernel/dtinit.mar:11-23` |
| Empty top | the cell `F_STACK_0` | `kernel/rkernel.mar:371`, `:520`, `:1950` |
| Reset | `RESET_REGISTERS` reloads R7 from `F_STACK_0` after every error | `kernel/rkernel.mar:515-521` |

The register dump in the `.SQRT` failure of `12-math.expected` shows R7 at
CE600 (empty), with the loop stack at CE200 and P at CDE00.

The kernel word `F_STACK` pushes the *address* of the `F_STACK_0` cell
(`moval f_stack_0(r11),-(r10)`), where `L_STACK` and `V_STACK` push the
cell's value with `movl` (`kernel/rkernel.mar:1797-1805`). `F_STACK` also
ends in a bare `rsb` where `L_STACK` ends in `rsbx`, which adds `wterm`
(`kernel/rkernel.mar:204-207`). On the VAX, `F_STACK @` gives CE600 (845312
decimal), the empty FS top, so the word is a variable rather than a
value (`tests/lang/F1-FLOAT.con`).

## Float literals

A float literal is compiled by the kernel, so it needs no `FLOAT<`.
`FLOAT<` is needed only for the words that use the values.

| Step | What happens | Source |
|---|---|---|
| DIGIT | `.` sets the decimal-point flag; a second `.` makes the word not a number | `kernel/rkernel.mar:630-667` (`:634-635`, `:645-646`) |
| DIGIT | any character above `Z` is also taken as a decimal point (defect 1) | `kernel/rkernel.mar:643-644` |
| DIGIT | every other character must be a digit of the current radix | `kernel/rkernel.mar:630-667` |
| ICOMPILE | for a float, pushes the word buffer, runs `COUNT` and `STRING_TO_FLOAT` | `kernel/rkernel.mar:694-701` |
| STRING_TO_FLOAT | calls OTS$CVT_T_D on the text, decimal, and does not check its status | `kernel/crtl.mar:105-110` |
| ICOMPILE | compiles `MOVD #d,-(R7)`: bytes 8F 70, the 8-byte value, then 77 | `kernel/rkernel.mar:694-701` |

What follows from this:

- The text is always read as decimal. In HEX, `10.` is 10.0 decimal and
  `1.8` is 1.8 (`06-numio.expected:19`).
- Each character must still be a digit of the radix. So an exponent `E`
  works only in HEX, where E is a digit: in HEX, `1.E3` gives 1000 and
  `2.5E1` gives 25 (`06-numio.expected:19`), and `1.E30` gives
  `0.1000000000000000E+31` (`12-float.expected`, BIG). In DECIMAL, `1.E30`
  is not a number. These are defect 5.
- Because OTS$CVT_T_D's status is ignored, text it rejects compiles as 0.0.
  In a LOAD file, which is not uppercased, the words `x`, `1x5`, `2_5` and
  `7[` each compile silently as 0.0 (`06-numio.expected:18`, defect 1).
  Two such characters make the word undefined (`xy`,
  `06-numio.expected:20-22`).

## The word set

All words are in the `FLOAT<` branch (`stoic/float:4`), except `FLODEF`,
which is in `STOIC<` (`stoic/float:236`). In the stack pictures the top of
FS is on the right. "Inline" means an IMMEDIATE word that compiles its
instruction in place.

### Stack

| Word | Effect | Source | Notes |
|---|---|---|---|
| `.DUP` `.OVER` `.DROP` `.2DROP` | as the integer words | `stoic/float:21-25` | inline |
| `.DDUP` | a b → a b a b | `stoic/float:23` | inline |
| `.SWAP` | a b → b a | `stoic/float:26` | right in `12-float` (STACK) |
| `.+ROT` | a b c → c a b | `stoic/float:28-33` | same order as `+ROT` (`12-float` ROT, `03-stack`); see below |
| `.-ROT` | a b c → b c a | `stoic/float:35-40` | same order as `-ROT`; see below |
| `.UNDER` | a b → b | `stoic/float:42-44` | |
| `.FLIP` | a b c → c b a | `stoic/float:46-48` | moves only the first longword of each value (defect 16) |

`.+ROT` and `.-ROT` each move one value with `MOVL`, not `MOVQ`
(`stoic/float:32`, `:36`, `:39`). That would lose the low half of that
value, like `.FLIP`. The test used 1., 2. and 3., whose low halves are
zero, so it would not show. With 1.1 2.2 3.3, `.+ROT` leaves the moved
3.3 as 3.300000143051147 and `.-ROT` leaves the moved 1.1 as
1.099999928474426; the values that are not moved stay exact
(`tests/lang/F1-FLOAT.con`). This is defect 37.

### Arithmetic and conversion

| Word | Effect | Source |
|---|---|---|
| `.+` `.-` | b+a, b−a | `stoic/float:53-54`, inline |
| `.*` `./` | b×a, b/a | `stoic/float:56-62` |
| `.MINUS` | −a | `stoic/float:64` |
| `.^` | b^a, by OTS$POWDD | `stoic/float:66` |
| `.EFIX` | divides by 10 until the whole part is 0; leaves the count on P and the value, below 1, on FS | `stoic/float:68-78` |
| `I->F` | integer from P to FS, CVTLD | `stoic/float:16` |
| `F->I` | FS to P, CVTDL: truncates toward zero | `stoic/float:17` |

Tested (`12-float.expected`): `I->F` of 7 gives 7.0; `F->I` gives 3 for
3.7 and −3 for −3.7; arithmetic gives 3.75, 6, 12 and 0.25; `.MINUS` gives
−2.5; `2. 10. .^` gives 1024.

### Comparisons

The tests leave a flag on P, −1 or 0, made with ITEFT (`stoic/rdef:466-471`).

| Words | Built from | Source |
|---|---|---|
| `.NEZ .EQZ .GTZ .LEZ .GEZ .LTZ` | TSTD | `stoic/float:82-87` |
| `.NE .EQ .GT .LE .GE .LT` | `CMPD (FS)+ (FS)+` | `stoic/float:89-94` |
| `.xx_IF`, `.xxZ_IF` | the same tests, as IF forms | `stoic/float:96-110` |

The sense is the same as the integer words, which is the reverse of
`stoic.mem` (see AGENTS.md): `1. 2. .GT` gives −1 and `2. 1. .GT` gives 0.
`1. 1. .EQ` and `1. .GTZ` give −1 (`12-float.expected`).

### Variables

| Word | Effect | Source |
|---|---|---|
| `.VARIABLE` | `value 'NAME .VARIABLE` makes an 8-byte variable holding the value | `stoic/float:226-230` |
| `.@` `.!` | fetch to FS, store from FS | `stoic/float:222-223` |
| `.?` | `.@ .=` | `stoic/float:224` |

`12-float` (VAR) makes `FV` with 2.5, prints it, stores 4.5 and prints that.

## Output

### `.=` and `F->S`

`F->S` (`stoic/float:114-117`) converts the top of FS into the string
`F_STRING`. `.=` (`stoic/float:119-122`) types it. `FLOAT_TO_STRING`
(`kernel/crtl.mar:97-103`) calls FOR$CVT_D_TG with 16 decimal fraction
digits. Its status in R0 is not checked.

`.=` writes a 22-character G-format field. Numbers in range print in F form
with four trailing blanks where an exponent would go. Others print in E
form. From `12-float.expected` and `06-numio.expected`:

| Value | `.=` prints |
|---|---|
| 1.5 | ` 1.500000000000000    ` |
| −2.25 | `-2.250000000000000    ` |
| 1000000 | ` 1000000.000000000    ` |
| 0.001 | `0.1000000000000000E-02` |
| 0 | `0.0000000000000000E+00` |
| 1.E30 | `0.1000000000000000E+31` |

Unlike `=`, `.=` adds no space of its own. The F form starts with a
blank or `-` for the sign, but the E form does not, so an E-form value runs
into whatever was printed before it (`06-numio.expected:18`).

`F_STRING` is made with `15 'F_STRING SVARIABLE` (`stoic/float:12`), which
allocates 15 hex (21 decimal) bytes (`stoic/rdef:936-941`). `F->S` sets its
length to 16 hex (22) before conversion (`stoic/float:115`). The 22-byte
output (above) therefore writes one byte past the string. The next thing
compiled after it is `F.EXPADD` (`stoic/float:126`), and `.<#` resets that
before use. On the VAX, `0 F.EXPADD ! 1.5 .= F.EXPADD @ =` gives 32
decimal, a blank, so the stray byte does land in `F.EXPADD`
(`tests/lang/F1-FLOAT.con`). Because `.<#` resets it, no wrong output has
been seen (defect 38).

### Formatted output

| Word | Use | Source |
|---|---|---|
| `F=` | value width places `F=`: fixed point in a field | `stoic/float:209-212` |
| `E=` | value width places `E=`: exponent form in a field | `stoic/float:214-218` |
| `.<#` `.#` `.#>` `.E#>` `>.<` | pictured output, like `<# # #>` | `stoic/float:135-172` |
| `.<#>` | a whole value with 4 fraction digits | `stoic/float:179-188` |
| `.PUT` `.SELECT` | helpers | `stoic/float:130`, `:198` |
| `F.EXPADD` `F.10POWER` `F.WHOLE` | working variables | `stoic/float:126-128` |
| `.ERRCHK` | prints "Floating point output conversion error." and aborts | `stoic/float:192-196` |

Tested (`12-float.expected`):

- `3.14159 8 3 F=` gives `   3.141`, and `-3.14159 8 2 F=` gives
  `   -3.14`. Both truncate; they do not round.
- `12345.6 12 3 E=` gives `1234.560E+01`. The mantissa is not normalized:
  it keeps as many integer digits as the field allows.
- `3.14159 2 3 F=`, where the field is too small, prints "Floating point
  output conversion error." The rest of the line is skipped and the next
  line runs.

## Functions (MTH$ and OTS$)

`kernel/crtl.mar` makes these words with two macros. All are in `FLOAT<`.

| Macro | Code | Words | Source |
|---|---|---|---|
| `math1` | `pushad (r7)+`, `calls #1,G^MTH$Dname`, `movd r0,-(r7)` | `.ACOS .ASIN .ATAN .LOG10 .COS .EXP .COSH .SINH .TANH .LOG .SIN .SQRT .TAN` | `kernel/crtl.mar:75-81`, `:114-126` |
| `math2` | two `movd (r7)+,-(sp)`, `calls #4,G^OTS$name`, `movd r0,-(r7)` | `.POWDD` | `kernel/crtl.mar:85-92`, `:130` |

`.POWDD` raises the second item to the power of the top: b^a. The source
comment says "order of these arguments may be debatable"
(`kernel/crtl.mar:87-89`). `2. 3. .POWDD` gives 8 (`12-math.expected`).

The angles are in radians. Tested values (`12-math.expected`):

| Expression | Result |
|---|---|
| `2. .SQRT`, `16. .SQRT` | 1.414213562373095, 4 |
| `0. .SIN`, `0. .COS` | 0, 1 |
| `1. .ATAN 4. .*`, `1. .ASIN 2. .*` | 3.141592653589793 |
| `1. .ACOS` | 0 |
| `1. .ATAN .TAN` | 1 |
| `1. .EXP`, then `.LOG` | e, 1 |
| `1000. .LOG10` | 3 |
| `0.` `.SINH .COSH .TANH` | 0, 1, 0 |

## Errors

| Case | What happens | Test | Defect |
|---|---|---|---|
| Overflow in arithmetic: `1.E30 1.E30 .*` | `%SYSTEM-W-FLTOVF_F`, a traceback, and the line ends; the next line runs | `12-float` OVERFLOW | message PC is ABORT's (19) |
| `0. .LOG`, `2. .ASIN`, `10. 1000. .^` | no message; a reserved operand is left on FS, and the *next* float word faults with `%SYSTEM-W-ROPRAND` | `12-math` | 17 |
| `-1. .SQRT` | ACCVIO at PC 80000010, "Improperly handled condition", and STOIC exits | `12-math` | 18 |
| Field too small in `F=` | "Floating point output conversion error." | `12-float` | — |

FS overflow and underflow are not checked in the code
(`tests/lang/F3-FSOVER.con`, `F4-FSUNDER.con`):
- **Overflow** is caught by the moat page. A loop that pushes 70 hex
  values faults with an ACCVIO write at CE3F8, below the FS page. The error
  resets FS, and the next line's float words work.
- **Underflow** is not caught, because the page above the FS base is
  readable. `.DROP .=` on an empty FS prints 22 NULs with no message. The
  next line that compiles a float literal then faults (ACCVIO at CE608 in
  ICOMPILE), since the conversion uses the FS above its top. That error
  resets FS. This is defect 39.

## CALC and FLODEF

`FLODEF` is `'FLODEF : FLOAT< DECIMAL ; IMMEDIATE` (`stoic/float:236`). It
is in `STOIC<`. Because it is IMMEDIATE, it runs while the line is
compiled, so the rest of the same line is compiled with `FLOAT<` pushed and
the radix DECIMAL.

That makes a calculator out of a DCL command tail (see AGENTS.md,
Startup). `aaareadme.doc` defines it as `$ CALC :== $SAO$RED:RED FLODEF`
(`aaareadme.doc:18`, described at `:21-27`), or with STOIC in place of RED
(`:39`). `tools/stoic-run` sets `CALC` the same way (`tools/stoic-run:89`).

Tested on the shipped `RED.EXE` (`13-calc.expected`):

```
$ CALC 2. .SQRT 2. ./ .ASIN 4. .* .= CR ;F
 3.141592653589793
$ CALC 1. .ATAN 4. .* .= CR ;F
 3.141592653589793
```

## The GM float package, for contrast

The GM variant (`gm/`, see `doc/gm-variant.md`) has a smaller float
package, `gm/float.sto` (Wiitanen, 17.XII.81). It has not been run.

| | SAO `stoic/float` | GM `gm/float.sto` |
|---|---|---|
| Format | D_floating, 8 bytes | F_floating, 4 bytes (`gm/float.sto:5-14`; `gm/newstoic.mem:333`) |
| Stack | its own, FS (R7) | the parameter stack P |
| Branch | `FLOAT<` | `FLOATING_POINT<` (`gm/float.sto:17-18`) |
| Arithmetic | `.+ .- .* ./ .MINUS` | `+. -. *. /. MINUS.`, all inline (`gm/float.sto:21-33`) |
| Conversion | `I->F`, `F->I` | `FLOAT` (CVTLF), `FIX` (CVTFL) (`gm/float.sto:36`, `:39`) |
| Tests | `.GT` and so on, CMPD | `.GT.` and so on, CMPF (`gm/float.sto:49-71`), with `_IF.` forms (`:76-90`) |
| Extra | | `MAX. MIN. ABS.` (`gm/float.sto:94-98`) |
| Functions | MTH$ and OTS$POWDD | none |
| Literals | kernel, any radix, text read as decimal | kernel, DECIMAL only, by FOR$CNV_IN_DEFG |
| Output | `.=`, 22 characters, 16 fraction digits | `#F` and `=.`, G format, 6 digits (`gm/kernel.mar:1352-1377`, `gm/float.sto:45`) |

In GM, only the first longword of a float literal's converted value is
pushed (`gm/kernel.mar:619-620`). The first longword of a D_floating has
the F_floating layout, so the result is a single-precision value either
way.

## Source observations checked on the VAX

The four observations the first draft left open were run with
`tools/stoic-run` on the shipped STOIC.EXE (`tests/lang/F1-FLOAT.con`,
`F3-FSOVER.con`, `F4-FSUNDER.con`; output in `tests/lang/phase5.out`):
`.+ROT` and `.-ROT` lose the low half of the moved value (defect 37),
`F->S` overruns into `F.EXPADD` (defect 38), `F_STACK` pushes the cell
address, and FS underflow is not caught (defect 39). The same run confirmed
`.<#>` (4 fraction digits: `1.5000`, `-2.2500`), `.EFIX` (`1234.5` gives 4
and 0.12345), an unnormalized `E=` (`.001 12 3 E=` gives `.001E+00`),
`1.2.3` as undefined, `1.A` in hex as 0.0, and `.SQRT` as undefined without
`FLOAT<`.
