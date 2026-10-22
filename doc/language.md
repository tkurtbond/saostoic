# The STOIC language as implemented

This is Phase 5 of `PLAN.md`. It describes SAO STOIC for VAX/VMS as the
shipped `STOIC.EXE` and its sources actually behave: syntax, literals,
radix, definitions, control structures, vocabularies (branches), strings,
the loop stack and the in-line assembler. The last section lists where the
manual, `stoic.mem`, is wrong or out of date.

Related documents:

- [`kernel.md`](kernel.md): registers, dictionary headers, memory layout.
- [`words.md`](words.md): the reference for each word.
- [`defects.md`](defects.md): the defects cited here by `PLAN.md` number.
- [`float.md`](float.md): the float stack and float words.

Source paths are under `saostoic-text/`, so `kernel/rkernel.mar:450` means
`saostoic-text/kernel/rkernel.mar`, line 450, and `rdef:520` means
`saostoic-text/stoic/rdef`. Tests are in `tests/`; each `NN-name.sto` (or
`.con`, `.dcl`) has its recorded VAX output in `NN-name.expected`.
Numbers are decimal unless they say otherwise.

## How a line runs

STOIC has no interpreter state. The outer loop compiles each line into a
buffer and then runs it (`kernel/rkernel.mar:450-467`):

1. Reset the compile-buffer pointer and `CHECK`, the nesting depth.
2. Read a line. At end of file, run `;F` and read again.
3. Compile the line.
4. If `CHECK` is not 0, read and compile another line into the same buffer.
5. When `CHECK` is 0, append an RSB and jump into the buffer
   (`EXECUTE`, `kernel/rkernel.mar:802-806`).

Consequences:

| Fact | Evidence |
|---|---|
| A whole line is compiled before any of it runs. So `HEX`, `DECIMAL`, a branch such as `TV<`, or a new definition takes effect from the **next** line. | `HEX 10 DECIMAL =` prints `10`, not 16 (`06-numio`, "SAME LINE"); `08-vocab` "SAME LINE"/"INSIDE" |
| Only IMMEDIATE words run at compile time. | `kernel/rkernel.mar:1011-1050`; `05-define` "IMMEDIATE" prints `<IMM>` before the line runs |
| A structure left open (`CHECK` > 0) makes the following lines part of the same unit. Nothing runs until it closes. | `04-control` "MULTILINE" |
| The prompt shows `CHECK` as one digit (`0>`, `1>`, ...). | `kernel/rkernel.mar:1457-1458` |
| Code compiled at the console is thrown away after its line runs, including string literals in it. | `kernel/rkernel.mar:450-452`; `11-errors.con` (an unclosed `"ABC` then `MSG` on the next line gives ACCVIO in TYPE); a closed `"HELLO"` then `COUNT =` on the next line gives 33, not 5 (`tests/lang/L1-LANG.con` C11) |
| A compile error (an undefined word) discards the whole line, and in a LOAD file ends every LOAD under way. A run-time error ends only its line. | `kernel/rkernel.mar:616-621`, `1393`; `11-errors.con`, `06-numio` (the `xy` line ends the file) |

## Lexical syntax

`WORD` (`kernel/rkernel.mar:1490-1542`) splits a line into words:

- Blanks, tabs and form feeds separate words (1494-1499). A word ends at a
  space or tab (1520-1525).
- **String words.** If a word starts with `"`, WORD skips the run of
  quotes, scans to the next `"`, and skips the run of quotes there
  (1503-1509). Spaces inside are kept. The word can end directly before
  more text: `"EF"MSG` is two words (`07-strings`, "ADJOIN").
- **Comments.** A word that starts with `%` starts a comment. WORD scans
  to the next `%`, skips the run of `%` there, and carries on (1511-1517).
  If there is no second `%`, the rest of the line is ignored.
  `1 % COMMENT % 2 + =` and `1 %X% 2 + =` both print 3 (`tests/lang/L1-LANG.con` C1, C2).
- Console input is uppercased by RMS; LOAD files are not. The dictionary
  is case-sensitive, so source files must be in uppercase. A lowercase
  word in a LOAD file usually compiles as a junk float (defect 1).

For each word, `I_COMPILE` (`kernel/rkernel.mar:595-624`):

1. looks it up in the dictionary and, if found, acts on its attribute;
2. otherwise tries it as a literal (integer, float, then string);
3. otherwise prints `undefined error compiling... NAME ...in line`.

Lookup comes before literals. So a word can shadow a number: rdef defines
`1`, `2` and `-1` as IMMEDIATE words that compile short in-line code
(`rdef:615-617`). After `HEX 'AB : 99 ;`, `AB` gives 99, not AB hex
(`tests/lang/L1-LANG.con` C9).

## Literals

| Kind | Form | Compiles to | Source |
|---|---|---|---|
| integer | optional leading `-`, then digits below the radix | `MOVL #n,-(R10)` | `kernel/rkernel.mar:682-701`, `730-761` |
| float | digits with a `.` (and optional `E`) | `MOVD #d,-(R7)` | `kernel/rkernel.mar:630-701`; see [`float.md`](float.md) |
| string | `"text"` or `'text` | the counted string in line, after a JSB that pushes its address | `kernel/rkernel.mar:705-723`, `765-786` |

Integer rules, all from tests:

| Rule | Evidence |
|---|---|
| Only a leading `-` is a sign. `+5` is undefined. | `kernel/rkernel.mar:730-741`; `11-errors.con` |
| Digits are 0-9 then A-Z, each below the radix. Leading zeros are fine: `007` is 7, `-0` is 0. | `kernel/rkernel.mar:630-667`; `06-numio` "LEADING" |
| Overflow wraps mod 2³² with no error (defect 5): `4294967296` is 0, `4294967297` is 1, `99999999999` is 1215752191. | `kernel/rkernel.mar:745-761`; `06-numio` "BIG", "HEX BIG" |
| `ASCII X` (IMMEDIATE) compiles the code of the first character of the next word: `ASCII A` is 65. | `rdef:1148-1152`; `06-numio` "ASCII" |

Float rules:

| Rule | Evidence |
|---|---|
| A float's digits are checked against the current radix but the number is always read as decimal. In HEX, `1.8` is 1.8 and `1.E3` is 1000. `1.E30` can be typed only in HEX, where `E` is a digit. | `06-numio` "HEX FLT"; defect 5 |
| Any character above `Z` counts as a decimal point (defect 1). So lowercase `x`, `1x5`, `2_5` and `7[` all compile as 0.0. | `kernel/rkernel.mar:630-667`; `06-numio` "LOWER" |

String rules (`SLITERAL`, `kernel/rkernel.mar:765-786`):

- A word that starts with `"` loses its first and last characters. One
  that starts with `'` loses its first character. The `'` form ends at the
  next space or tab.
- So `""AB"` is `"AB`, `"CD""` is `CD"`, and `""` is **not** empty: it
  runs on to the next quote on the line (`07-strings`, "QUOTES", "EMPTY").
- A string literal pushes one address, that of a 16-bit count followed by
  the text. `COUNT` turns it into address and length
  (`kernel/rkernel.mar:1545-1548`; `07-strings` "COUNT").

## Radix

- The default radix is **hex**: `dlrte U_RAD,16` (`kernel/rkernel.mar:2017`);
  `06-numio` "DEFAULT" prints 10 in hex.
- `RADIX` pushes the address of the radix cell (`rdef:249`). `DECIMAL` and
  `HEX` store 10 and 16 (`rdef:1347-1353`). Any radix can be stored:
  `8 RADIX !` makes `777` read as 511, and `2 RADIX !` makes `1011` read
  as 11 (`06-numio` "OCTAL", "BINARY"). There is no `OCTAL` word.
- The same radix is used for output. `255 HEX =` prints `FF`; `-1 =`
  prints `-1`, not `FFFFFFFF` (`06-numio` "HEX OUT").
- rdef itself is written in hex (`A RADIX !` at `rdef:1348`). Assembler
  operands such as `B^(P) n` are read in the current radix, so code
  written for hex must be loaded in hex (`09-asm`, DUPI).

## Truth and comparisons

- Any **odd** value is true and any even value false
  (`kernel/rkernel.mar:59-62`). `IF` tests the low bit with `BLBC`
  (`rdef:520-523`). `IF` on 3 2 1 0 −1 −2 gives T F T F T F
  (`02-compare` "IF").
- The comparison words return −1 or 0 (`ITEFT`, `rdef:466-471`).
- **The sense is the reverse of the manual** (defect 13). With A on top
  and B under it, `B A GT` is true when **A > B**. `CMPL (P)+ (P)+`
  compares A with B (`rdef:487-497`).
- **It is also the opposite of CP/M STOIC**, which does what the manual
  says: there `B A GT` is true when B > A. So the VAX `GT` is CP/M's `LT`
  and the VAX `GE` is CP/M's `LE` ([`cpm-compare.md`](cpm-compare.md),
  [`errata.md`](errata.md)).

| Word | True when | `1 2` | `2 1` | `2 2` |
|---|---|---|---|---|
| `GT` | A > B | −1 | 0 | 0 |
| `LT` | A < B | 0 | −1 | 0 |
| `GE` | A ≥ B | −1 | 0 | −1 |
| `LE` | A ≤ B | 0 | −1 | −1 |
| `EQ`, `NE` | as named | | | |

(`02-compare`.) Read `X 5 GT` as "5 is greater than X". The zero tests
(`EQZ NEZ GTZ LTZ GEZ LEZ`, `rdef:473-485`) compare the top with 0 in the
normal way: `GTZ` of −1 0 1 gives 0 0 −1.

- The `*_IF` words (`EQ_IF` ... `LTZ_IF`, `rdef:502-516`) combine a test
  with `IF` and have the same sense as the plain words (`02-compare`).
- `UNDROP` (`rdef:196-199`) backs P up one cell. After a `*_IF` or its
  `ELSE` it gives back the value the test popped: `2 3 TU`, with
  `'TU : EQ_IF 0 ELSE UNDROP THEN ;`, prints 2 (`02-compare` "UNDROP").
- rdef's own words are written for the VAX sense. `MAX` is
  `DDUP GT IF UNDER ELSE DROP THEN` (`rdef:654-658`); see
  [`cpm-compare.md`](cpm-compare.md) for the history.
- `DGE` (quadword compare) is wrong when the high longwords are equal
  (defect 15, `rdef:555-563`, `02-compare` "DGE LOW").

## Arithmetic notes

With A on top and B under it (`rdef:242-277`, `01-arith`):

| Word | Result | Note |
|---|---|---|
| `-` | B − A | `7 3 -` is 4 |
| `/` | B / A, signed, truncated toward 0 | `-7 2 /` is −3 |
| `MOD` | B mod A, **B taken as unsigned** | `-7 2 MOD` is 1, `-7 3 MOD` is 0 (defect 12) |
| `/MOD` | quotient, then remainder on top; B unsigned | `7 3 /MOD = =` prints `1 2` |
| `NOT` | bitwise complement | `5 NOT` is −6 |
| `+`, `*` | wrap mod 2³² | `65536 65536 *` is 0 |

`MOD` and `/MOD` clear the high longword of the `EDIV` dividend
(`rdef:242-244`, `274-277`). `MINUS` and `ABS` of −2147483648 give
−2147483648.

## Definitions

A colon definition puts the name first, as a string:

```
'SQ : DUP * ;
```

- `:` (IMMEDIATE) requires `CHECK` = 0, raises it, and compiles a call to
  `int_colon`. `;` lowers `CHECK`, which must reach 0, and appends RSB
  (`kernel/rkernel.mar:815-854`). So `:` cannot appear inside an open
  structure, and an unbalanced body gives `Syntax Error`
  (`11-errors.con`, `'BAD : 1 IF 2 ;`; `1 IF 'X : 1 ; THEN` gives `Syntax Error`
at the `:`, `tests/lang/L1-LANG.con` C13).
- `int_colon` runs **when the line runs**. It makes the header and copies
  the code into the code region (`kernel/rkernel.mar:829-838`). Therefore:
  - a definition and a use of it on the same line fail: the use is
    compiled before the word exists, so the whole line is undefined
    (`11-errors.con`, `'CNT : ... ; 4 CNT`);
  - inside a redefinition the name still means the old word.
    `'SQ : SQ 1+ ;` makes `9 SQ` give 82 (`05-define` "REDEFINE",
    `08-vocab` "REDEF").
- Definitions may span lines (`05-define` "TWO LINES"). The body,
  including literals, must fit in the compile buffer, which is not checked
  (defect 4).
- `IMMEDIATE`, after the definition, sets the attribute byte of the newest
  word in the CURRENT branch (`rdef:85-88`,
  `kernel/rkernel.mar:932-937`).
- `(:)` and `(;)` are deferred forms of `:` and `;`
  (`kernel/rkernel.mar:863-873`).
- Recursion: the name is not defined while its body is compiled, so a word
  calls itself through a variable that holds its address:
  `() FACT FACTV !`, then `FACTV @ EXEC` in the body (`05-define`
  "RECURSION").

### Defining words

| Form | Makes | Source | Test |
|---|---|---|---|
| `value 'NAME CONSTANT` | a word whose value is fetched at run time (PUSH_THIS_WORD) | `kernel/rkernel.mar:1757-1764` | `05-define`, `08-vocab` |
| `value 'NAME VARIABLE` | a data cell, initialised; the word pushes its address (DISP_TO_R11) | `rdef:925-928` | `05-define` "VARIABLE" |
| `count 'NAME ARRAY` | `count` **longwords**; pushes the address of element 0 | `rdef:930-934` | `05-define` "ARRAY GAP" is 4 |
| `maxlen 'NAME SVARIABLE` | a string variable; pushes the address of its count, max length at −2 | `rdef:936-941` | `05-define` "SVARIABLE" `0 10` |
| `'NAME BRANCH` | a vocabulary | `rdef:943-944` | `08-vocab` |
| `'NAME MODULE` ... `NAME FORGET` | a marker; FORGET removes it and all later words and data | `rdef:1470-1484` | `08-vocab` "MODULE" |

- `,D` appends a longword to the data region and `.D@` gives the next free
  data address (`rdef:886-910`). `.D@ 'HERE0 CONSTANT 5 ,D 6 ,D` works
  (`05-define` "B,D ,D").
- `() NAME` (IMMEDIATE) pushes the code address of NAME, or fails with
  `Lookup failed`. `EXEC` calls the word at an address with `JSB @(P)+`
  (`rdef:567-577`, `1462-1465`; `05-define` "() EXEC" gives 37 for
  `6 () SQ EXEC`). Since a constant's value is fetched from its code at run
  time, `200 () N !` changes the constant N to 200 (`tests/lang/L1-LANG.con` C7).
- `!` is `value address !`; `<-` is `address value <-`
  (`rdef:285-390`; `05-define` "<-").

## Control structures

All are IMMEDIATE words in rdef that compile VAX branches with **byte**
displacements. `TARGET` reserves a displacement byte and `ARCHER` fills it,
giving `Byte-displacement overflow.` if it does not fit
(`rdef:420-445`). An `IF` around 40 lines of `12345678 DROP` gives
`Byte-displacement overflow.` at the `THEN` (`tests/lang/L2-LONGIF.sto`). Each opener raises `CHECK` and each closer lowers it.

| Structure | Behaviour | Source | Test (`04-control`) |
|---|---|---|---|
| `f IF ... THEN` | runs the body if f is odd | `rdef:520-528` | "IF ONLY" |
| `f IF ... ELSE ... THEN` | | `rdef:530-534` | "IF", "NESTED" |
| `BEGIN ... f END` | runs at least once; repeats while f is **false**, stops when true | `rdef:536-545` | "BEGIN END", "BEGIN ONCE" |
| `BEGIN ... f IF ... REPEAT` | while loop; may run zero times; `REPEAT` lowers `CHECK` by 2 | `rdef:547-553` | "REPEAT", "REPEAT 0" |
| `limit start DO ... LOOP` | I runs from start to limit − 1 | `rdef:670-694` | "DO", "DO 3 7", "DO NEG" |
| `limit start DO ... step +LOOP` | adds step to I; stops when I ≥ limit | `rdef:696-704` | "+LOOP 3", "+LOOP 10" |
| `n ( ... )` | runs n times; I runs 0 to n − 1 | `rdef:721-747` | "PAREN", "PAREN NEST" |
| `EXIT` | ends the innermost loop at its next `LOOP`, `+LOOP` or `)` | `rdef:706-709` | "EXIT" |

- `DO` with limit ≤ start, and `(` with n ≤ 0, run nothing
  (`04-control` "DO ZERO", "+LOOP -1", "PAREN 0").
- Structures nest and may be used at the console, outside any
  definition (`04-control` passim; `rdef:1539-1542` uses `IF ... THEN`
  across lines in a LOAD file).
- `DISPATCH` (`rdef:581-602`) compiles a byte compare and call, for case
  tables.

## The loop stack

`DO` and `(` push a three-longword frame on the L stack (R9)
(`rdef:670-676`, `721-732`):

| Offset | Contents |
|---|---|
| 0(L) | count = limit − I (the number of passes left) |
| 4(L) | start (0 for `(`) |
| 8(L) | limit (n for `(`) |

Words that read it (`rdef:706-719`):

| Word | Value | Test (`04-control`) |
|---|---|---|
| `I` | limit − count, the index | "DO" |
| `J`, `K` | the same for the frame 0C and 18 (hex) bytes up | "I J", "I J K" |
| `I'` | start + count − 1, the index running backwards | "I'": 4 3 2 1 0 |
| `LAST_I` | after a loop: limit − count of the frame just popped | "LAST_I": 5 |
| `EXIT` | sets limit = I and count = 1 | "EXIT", "EXIT LAST": 3 |

Consequences of the layout:

- `LOOP` and `)` use `SOBGTR` on the count, so a loop stops when the count
  reaches 0 (`rdef:687-694`).
- `+LOOP` subtracts the step from the count and loops while it is > 0
  (`rdef:696-704`). A step that does not divide the range still stops
  correctly: `10 0 DO ... 3 +LOOP` gives 0 3 6 9. A negative step adds
  to the count, so `3 0 DO I = ... -1 +LOOP` runs on through 0, −1, −2, ...
  until something stops it (`tests/lang/L1-LANG.con` C4).
- After `EXIT`, `I` reads one less than before (limit − count with
  limit = the old I and count = 1) until the next `LOOP`: in
  `5 0 DO I 2 EQ IF EXIT I = THEN LOOP`, the `I =` prints 1 (`tests/lang/L1-LANG.con` C5).
- `(` frames count as a level for `J` and `K` (`04-control`
  "PAREN NEST").
- `MARK`/`RESTORE` and `NOTE`/`RECALL` also use the L stack
  (`rdef:626-641`). Anything left on it between `DO` and `LOOP` shifts
  `I`, `J` and `K`. `tests/files/util.sto` warns not to use its `[ ... .S`
  helpers across a DO.

## Vocabularies (branches)

The dictionary is a set of linked branches. Lookup searches the
vocabulary stack from the top down (`kernel/rkernel.mar:947-981`).
New words go on the branch in `CURRENT`.

| Word | Effect | Source |
|---|---|---|
| `'NAME< BRANCH` | makes a branch; NAME< pushes it on the vocabulary stack **when it runs** | `rdef:943-944`, `kernel/rkernel.mar:1838-1860` |
| `>` | pops the vocabulary stack, with no check; after `> > > >` every line faults in I_LOOKUP (defect 40) | `kernel/rkernel.mar:1862-1865`; `tests/lang/L3-POP.con` |
| `DEFINITIONS` | sets CURRENT to the top branch | `kernel/rkernel.mar:1868-1870` |
| `STOIC<`, `ASSEMBLER<`, `TTIO<`, `FLOAT<` | kernel branches | `kernel/rkernel.mar:1873-1895` |
| `IORB<` | rdef branch for RMS blocks; broken in the shipped exe (defect 22) | `rdef:948` |

The usual pattern, tested in `08-vocab`:

```
'TV< BRANCH
TV< DEFINITIONS
'HIDDEN : 111 = ;
> DEFINITIONS
```

- Because a branch word acts at run time, a word in the branch cannot be
  compiled on the same line as the branch word (`08-vocab` "SAME LINE",
  "INSIDE").
- rdef's `BRANCH` compiles the absolute address of the branch cell into
  the new word, so branches made before an IMAGE point at the old data
  region in the child (defect 22).
- `FORGET` resets CURRENT's chain to what it was at the `MODULE`
  (`rdef:1475-1484`). The manual's advice to use one MODULE per
  `DEFINITIONS` switch follows from this.
- `FORGET` takes the header of a `MODULE` word, and it sets `.D` from the
  longword after the constant in that word's code (`rdef:1487`). Given
  the header of a colon word (from `I_LOOKUP`), it sets `.D` from that
  word's code, and the next IMAGE refuses: "the data region has outgrown
  its demand-zero section" (`tests/big/fill1-load.con`, which therefore
  saves and restores `.D` around such a FORGET).

## Strings

A string is the address of a 16-bit count followed by the text. A string
variable (`SVARIABLE`) has its maximum length in the 16-bit word before
the count (`rdef:936-941`).

| Word | Stack | Note | Source | Test (`07-strings`) |
|---|---|---|---|---|
| `COUNT` | str → addr len | | `kernel/rkernel.mar:1545-1548` | "COUNT" |
| `MSG` | str → | `COUNT TYPE` | `kernel/rkernel.mar:1573-1576` | |
| `TYPE` | addr len → | | | "TYPE" |
| `MOVE_STRING` | str svar → | truncates at the maximum | `rdef:1270-1279` | "MOVE"; `05-define` "TOO LONG" |
| `STRAP` | str svar → | appends; truncates | `rdef:1258-1268` | "STRAP" |
| `STAB` | char svar → | appends a byte; does nothing when full | `rdef:1247-1256` | "STAB", "STAB FULL" |
| `.STREQ` | a1 n1 a2 n2 → f | | `rdef:1239-1243` | "STREQ" |
| `(SUBSTRING)` | pat n src n → ... | rest of the source and −1, or 0 0 | `rdef:1283-1289` | "SUBSTR", "NOSUB" |
| `SEARCH_STRING` | pat n src n → pat n rest n f | | `rdef:1209-1235` | "SEARCH" |
| `CRET LFEED BLANK` | → 13 10 32 | constants | `rdef:1302-1306` | "CONSTS" |

A string literal typed at the console lives in the compile buffer and is
gone when the next line is compiled (see "How a line runs"). Keep strings
needed later in a `SVARIABLE`, or define them inside a word.

## Number output

| Word | Effect | Source | Test (`06-numio`) |
|---|---|---|---|
| `=` | prints a space and the signed number in the radix | `kernel/rkernel.mar:1655-1690` | passim |
| `?` | `@ =` | `rdef:300` | |
| `<# # #S #> #PUT` | pictured conversion, right to left | `rdef:1154-1183` | "PARTIAL", "#S HEX" |
| `<#>` | signed number → addr len | `rdef:1185-1191` | "<#>", "MININT" |
| `n w I=` | n right-justified in w columns | `rdef:1192-1196` | "I=" |

- `=` writes a negative number as `-`, three NULs, then the digits
  (defect 14). `-3 =` sends `-^@^@^@3` (`01-arith`, `04-control`
  "DO NEG"). `<#> TYPE` does not have this fault.
- `I=` prints a space for each leading zero, so `0 3 I=` is all spaces,
  and keeps only the low w digits: `123456 3 I=` prints `456`. It treats
  its number as unsigned: `-42 6 I=` prints `967254` (`06-numio` "I=",
  "I= NEG").

## The in-line assembler

`ASSEMBLER<` makes the assembler words visible (`rdef:29-79`). Each one is
an `AC` word with the COMPILE_BYTE attribute: compiling it appends one
byte to the compile buffer (`kernel/rkernel.mar:923-929`, `1011-1050`).
There is no syntax checking; the programmer writes the VAX instruction
byte by byte in VAX order, opcode first, then operands, source before
destination.

| Group | Words | Source |
|---|---|---|
| registers | `R0`-`R6`, `FS` (R7), `R8`, `L` (R9), `P` (R10), `SP` | `rdef:33-35` |
| modes | `(P)`, `-(P)`, `(P)+`, `@(P)+`, `(L)`, `-(L)`, `(L)+`, `(SP)`, `-(SP)`, `(SP)+`, `(PC)+`, `@#`, `[R0]`, and the same for R0-R5 and FS | `rdef:31-46` |
| opcodes | `MOVL ADDL2 SUBL3 CMPL TSTL BLBC SOBGTR EDIV MOVC3 RSB JSB` and others | `rdef:49-76` |
| operand words | `B^(P) n`, `@B^(P) n`, `B^(FS) n`, `B^(SP) n`, `S^ n`, postfix `B^ n` and `W^ n` (turn the previous `(X)` into a displacement mode) | `rdef:106-143` |
| branches | `(TARGET)`, `(ARCHER)`, `(CMARK)` inside code; `ITEFT` after a conditional branch pushes −1 or 0 | `rdef:420-445`, `466-471` |
| in-line expansion | `INLINE< ... >INLINE` in an IMMEDIATE word copies the bytes into its caller | `rdef:447-457`, `kernel/rkernel.mar:1053-1060` |

Examples from `09-asm` (all give the expected results):

```
ASSEMBLER<
'ADD2 : ADDL2 (P)+ (P) ;
'SECOND : MOVL B^(P) 4 -(P) ;
'FIVE : MOVL S^ 5 R0 MOVL R0 -(P) ;
'MYLTZ : TSTL (P)+ BLSS ITEFT ;
'INC : INLINE< INCL (P) >INLINE ; IMMEDIATE
'DEREF : MOVL @B^(P) 0 (P) ;
>
```

- `;` appends the RSB. A STOIC word used inside assembler code still
  compiles its normal `JSB`.
- Numeric operands are read in the current radix (`rdef:106-143` call
  `ILITERAL`), so DUPI must be loaded in HEX (`09-asm`).
- `S^` does not check that its operand fits in 6 bits (`rdef:126-129`).
- The opcode words exist only while `ASSEMBLER<` is on the vocabulary
  stack: outside it `'ADDL2 COUNT I_LOOKUP` gives 0 (`09-asm` "LAST").
- Because a branch acts at run time, `ASSEMBLER<` must be on a line
  before the code that uses it (see "Vocabularies").

## Errors, briefly

Details are in [`kernel.md`](kernel.md) and [`defects.md`](defects.md).

| Error | Effect | Evidence |
|---|---|---|
| undefined word | `undefined error compiling... X ...in line`, line discarded, all LOADs ended | `11-errors.con`, `10-files` |
| unbalanced structure | `Syntax Error error compiling... ;` | `11-errors.con` |
| fault (ACCVIO, INTDIV, FLTOVF ...) | message, line and traceback; the line ends; the stack is emptied | `11-errors.con` ("SP difference" 0), `12-float` |
| stack underflow | not checked; the next access in the moat page faults | `11-errors.con` (`DROP DROP DROP`) |
| LOAD or OPEN of a missing file | `RMS-F-FNF`, STOIC exits (defect 7) | `11-errors.con` |
| 4th nested LOAD | `Input file table overflow.` | `10-files` |

Every message shows ABORT's PC; the first traceback line is the real one
(defect 19). Only the first CTRL/C works (defect 2).

## Differences from stoic.mem

`stoic.mem` (June 1980, `saostoic-text/stoic/stoic.mem`) describes an
earlier and partly PDP-11 STOIC. Where the shipped exe differs (the
corrections, and which ones the patched build changes, are in
[`errata.md`](errata.md)):

| # | Manual says | The VAX does | Evidence |
|---|---|---|---|
| 1 | `GT` is "−1 if B greater than A", and so on for `LT GE LE` (`stoic.mem:567`) | the reverse: `B A GT` is true when A > B (defect 13) | `02-compare`; `rdef:487-497` |
| 2 | the `MAX` example `DDUP GT IF DROP ELSE UNDER THEN` (`stoic.mem:1263`) | with the VAX sense that code keeps the smaller value; rdef's `MAX` swaps the branches | `rdef:654-658`; `3 7` gives 3 (`tests/lang/L1-LANG.con` C10) |
| 3 | `MOD` is "remainder of B/A" | B is taken as unsigned: `-7 3 MOD` is 0, `-7 2 MOD` is 1 (defect 12) | `01-arith`; `rdef:242-244` |
| 4 | `/MOD` (implied signed) | unsigned dividend too: `-42 6 I=` prints `967254` | `06-numio` "I= NEG"; `rdef:274-277` |
| 5 | `=` outputs the number, signed | negatives come out as `-`, three NULs, digits (defect 14) | `01-arith`, `02-compare`; `kernel/rkernel.mar:1682-1685` |
| 6 | an integer literal may have a leading `+` (`stoic.mem:103-104`) | `+5` is undefined | `11-errors.con` |
| 7 | integer literals must be in range | out-of-range literals wrap silently (defect 5) | `06-numio` "BIG" |
| 8 | `5 0 DO I = LOOP` prints `1 2 3 4` (`stoic.mem:1669-1670`) | prints `0 1 2 3 4` (a typo in the manual) | `04-control` "DO" |
| 9 | inside `( )`, I runs from n down to 1 (`stoic.mem:1634-1636`) | I runs from 0 up to n − 1 | `04-control` "PAREN"; `rdef:711` |
| 10 | the loop stack holds index, low, high (Appendix A) | it holds count (limit − I), start, limit | `rdef:670-676`, `711-719` |
| 11 | `J'` and `K'` exist (`stoic.mem:1627`) | not defined (only `I'`) | `rdef:715`; `doc/data/stoic-inventory.txt` |
| 12 | `ARRAY` length is in 16-bit words, and it zeroes the array (`stoic.mem:2235-2237`) | length in longwords; ARRAY itself stores nothing | `rdef:930-934`; `05-define` "ARRAY GAP"; an ARRAY made after `FORGET` still holds the forgotten VARIABLE's 7 (`tests/lang/L4-FORGET.con`) |
| 13 | `FILL`, `0FILL`, `MVBYTES`, `OCTAL`, `ERR` (`stoic.mem:881`, `937`, `2067`, `2289-2297`) | not in the exe (`MOVE_BYTES` exists) | `doc/data/stoic-inventory.txt` |
| 14 | `%` is a comment only as a separate word, ended by a separate `%` (`stoic.mem:1825-1834`) | any word that **starts** with `%` opens a comment, which ends at the next `%` anywhere | `kernel/rkernel.mar:1511-1517` |
| 15 | popping the last vocabulary gives `VOCABULARY STACK EMPTY` (`stoic.mem:3183-3185`) | `>` has no check and the message does not exist in the source | `kernel/rkernel.mar:1862-1865`; `tests/lang/L3-POP.con` (defect 40) |
| 16 | `() NAME` pushes the "parameter field" (`stoic.mem:2433`) | pushes the code address | `rdef:567-577` |
| 17 | the kernel has two vocabularies, `STOIC<` and `ASSEMBLER<` (`stoic.mem:3145`) | also `TTIO<` and `FLOAT<`; rdef adds `IORB<` | `kernel/rkernel.mar:1873-1895`; `rdef:948` |
| 18 | `ABORT` is invoked by CTRL/C (`stoic.mem:2063`) | only the first CTRL/C works (defect 2) | `defects.md` |
| 19 | `""` (implied) is an empty string | it runs on to the next quote | `07-strings` "EMPTY" |
| 20 | a missing file is an error | STOIC exits (defect 7) | `11-errors.con` |

What the manual gets right, confirmed by tests:

- `-` is B − A and `/` is B / A (`01-arith`).
- Odd is true (`02-compare` "IF").
- `BEGIN ... END` stops when the flag is true (`04-control`).
- `I'` is high + low − I − 1, and `LAST_I` is the high limit after a loop
  without `EXIT` (`04-control`).
- The LOAD file stack has four levels counting the console
  (`stoic.mem:2567`; `10-files`).
- `'NAME MODULE ... NAME FORGET` (`08-vocab`).

The manual itself notes that `^` (continue to the next line), the
line-feed repeat and `ADDRESS` are not implemented in VMS STOIC
(`stoic.mem:1999`, `2015`, `845`). None of them is in the exe's inventory.
