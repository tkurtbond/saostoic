# The GM variant of the kernel

This is Phase 5 of `PLAN.md`: a comparison of the GM Research kernel
(`saostoic-text/gm/`) with the SAO kernel (`saostoic-text/kernel/`). Paths
below are under `saostoic-text/`. Values are hex unless they say otherwise;
numbers in MACRO source are decimal unless marked `^X`.

**The GM variant has not been built or run.** Everything here comes from
reading its source and its manual. Nothing in it is backed by a test.

## Origin

`gm/aaareadme.1st` is a letter of 15.I.82 from W. Wiitanen (GM Research) to
Roger Hauck, sent with a tape holding `KERNEL.MAR`, `SS.MAR` and
`FLOAT.STO`. It lists GM's additions (`gm/aaareadme.1st:11-21`):

1. floating-point numbers, in the decimal radix only;
2. octal integers;
3. the local qualifiers `^X`, `^D` and `^O`, as in MACRO;
4. a message when `=` runs on an empty parameter stack;
5. a message when `>` would empty the vocabulary stack;
6. single-precision output in FORTRAN G format.

`SS.MAR` adds `$FAO` and "FOR$CVN_OUT_G" (`gm/aaareadme.1st:23-24`), a
slip for FOR$CNV_OUT_G (`gm/ss.mar:165-169`). The manual is
`gm/newstoic.mem`, "A Detailed Guide to VAX/VMS STOIC", 19 May 1982.

The GM kernel is an older design than SAO's, with GM's changes added. The
added code is marked "New coding, 18.XII.81, W. Wiitanen, GMR"
(`gm/kernel.mar:1300-1304`, `:1497-1502`).

## Summary

| | GM `gm/kernel.mar` | SAO `kernel/rkernel.mar` |
|---|---|---|
| Memory | static, in the `impure` psect | `$EXPREG`'d at startup |
| Moat pages | writable padding | no-access, made with `$DELTVA` |
| Headers | inline, just before the code | in a separate `dictionary` psect |
| Links | absolute addresses; chains end with 0 | offsets; chains end with 7FFFFFFF |
| R8 | the label `dictionary`, unbiased | `k_start+8000` |
| R11 | `user_table`, unbiased | user table +8000 |
| Float stack | none (`f_stack_size` is set but unused) | FS, R7 |
| Floats | F_floating on P, decimal only | D_floating on FS, any radix |
| Number input | FOR$CNV_IN_Z, _I, _O, _DEFG | DIGIT and ILITERAL, OTS$CVT_T_D for floats |
| Float output | `#F`, G format, 6 digits | `.=`, G format, 16 digits |
| MTH$ functions | none | `kernel/crtl.mar` |
| SAVE, XLOAD, MAPOPEN, IMAGE | absent | present |
| Global link, code length | absent | present |
| Empty-stack check in `=` | yes | no |
| `>` guard | yes | no |

The sections below give the citations.

## Memory

GM allocates everything statically (`gm/kernel.mar:133-168`).

| Item | GM | Source |
|---|---|---|
| Kernel code | `.psect kernel,nowrt` | `gm/kernel.mar:50` |
| Stack sizes | P 400, L 30, V 10 longwords (decimal) | `gm/kernel.mar:53-56` |
| Stacks | in the `impure` psect, each page-aligned, with a "buffer page" between them | `gm/kernel.mar:133-168` |
| First moat | label `MOAT_` | `gm/kernel.mar:136` |
| Vocabulary stack | starts holding `b_kernel` | `gm/kernel.mar:162-164` |
| Compile buffer | static `comp_buf` in `impure` | `gm/kernel.mar:447` |
| Dictionary space | `pages 60`, then `.blkl ^x2000`, at the end of the file | `gm/kernel.mar:1545-1547` |

The buffer pages are ordinary writable memory. `gm/kernel.mar` has no
`$DELTVA`, `$SETPRT` or `$EXPREG`. So a stack overflow writes into the
buffer page and then the next stack, with no fault. In SAO each block is
`$EXPREG`'d with one page more than it needs, and the first page is deleted
with `$DELTVA` (`kernel/dtinit.mar:11-23`), so overflow faults with ACCVIO.
GM's checks in `=` and `>` (below) are a partial guard against this.

The comment on `.blkl ^x2000` says "reserve 16 blank pages", but 2000 hex
longwords are 32 KB, or 64 decimal pages (`gm/kernel.mar:1547`).

## Headers and the dictionary

| | GM | SAO |
|---|---|---|
| Header macro | `gm/kernel.mar:191-204` | `kernel/rkernel.mar:169-190` |
| Where | in line, just before the code label | in the `dictionary` psect, apart from the code |
| Fields | link, counted name, lookup attribute | branch link, global link, counted name, attribute, code-length word, 16-bit displacement of the code from R8 |
| Link | absolute address of the previous header | offset from `dict_start`, biased |
| Chain end | 0 (`gm/kernel.mar:884`) | 7FFFFFFF (`kernel/rkernel.mar:972`) |

In GM the code of a word follows its header. MATCH returns the address
just past the name, which is where the attribute and the code are
(`gm/kernel.mar:899-910`). A new definition is copied from the compile
buffer to the space after its header (`gm/kernel.mar:751-760`), and
I_ENTER links the header by absolute address (`gm/kernel.mar:800-808`).

Calls are compiled the same way in both: `JSB W^disp(R8)`. In GM,
I_JUMP_TO_ME subtracts R8 from the code address and stores the low 16 bits
with `cvtlw` (`gm/kernel.mar:920-926`). R8 is the unbiased label
`dictionary` (`gm/kernel.mar:401`), which is the start of the user's
dictionary space. So kernel words are reached at negative displacements
and user words at positive ones. The space reserved after `dictionary` is
about 62 KB (60 pages plus 32 KB), but a signed 16-bit displacement reaches
only 32 KB. The overflow of `cvtlw` is not checked. This is the GM form of
defect 6. It is a source observation.

`CONSTANT` (`gm/kernel.mar:1418-1424`) and the `dlte` macro
(`gm/kernel.mar:208-220`) keep the value in the dictionary with the
PUSH_THIS_WORD attribute, as in SAO.

## User table

| | GM | SAO |
|---|---|---|
| R11 | `moval user_table,r11` (`gm/kernel.mar:318`, `:397`) | biased by 8000 (`kernel/rkernel.mar:310`) |
| Table | `gm/kernel.mar:246-300` | `kernel/rkernel.mar:1903-2018` |
| `F_STACK_0`, `FLOAT`, `TTIO` entries | absent | present (`kernel/rkernel.mar:1950`, `:1959`) |
| DISP_TO_R11 lookup attribute | absent; the dispatch table has `LKP_DSP_TEMP` (`gm/kernel.mar:302-310`) | present (`kernel/rkernel.mar:2050-2058`) |
| User variables | `dlte` pushes an absolute address | DISP_TO_R11 compiles an R11 displacement |

Without DISP_TO_R11, a GM user variable is an absolute address fixed at
link time. That is one reason GM could not have SAVE or IMAGE, which rely
on everything being found through R8 and R11.

## Number input

GM replaces SAO's DIGIT-based literal parser with FORTRAN conversion
routines when the radix is 16, 10 or 8 (`F_iliteral`,
`gm/kernel.mar:585-662`). I_LITERAL calls `F_iliteral`, and ICOMPILE then
compiles one `MOVL #n,-(R10)` (`gm/kernel.mar:524-530`, `:714`).

| Case | GM routine | Source |
|---|---|---|
| Starts with `"` or `'` | not a number | `gm/kernel.mar:595-598` |
| Starts with `^` | local qualifier: `^X` hex, `^D` decimal, `^O` octal | `gm/kernel.mar:600-602`, `:645-654` |
| Radix 16 | sign handled by hand, then FOR$CNV_IN_Z, then multiplied by `U_SGN` | `gm/kernel.mar:603-616` |
| Radix 10 | FOR$CNV_IN_I; if that fails, FOR$CNV_IN_DEFG (a float) | `gm/kernel.mar:626-634` |
| Radix 8 | FOR$CNV_IN_O | `gm/kernel.mar:636-640` |
| Any other radix | the old ILITERAL | `gm/kernel.mar:642-643`, `:669` |
| Success | `MOVL TEMP,-(R10)`: only the first longword of the result | `gm/kernel.mar:619-622` |

What follows from the source:

- **A float literal is possible only in DECIMAL**, or with `^D` in any
  radix (`gm/newstoic.mem:255-337`). In SAO a float literal is accepted in
  any radix, but its text is read as decimal (defect 5).
- **A float is one longword on P.** The result buffer `TEMP` is a
  quadword, but only its first longword is pushed. The first longword of a
  D_floating has the F_floating layout, so either way the value pushed is a
  valid single-precision F_floating number. The manual says "Only single
  precision floating point is used" (`gm/newstoic.mem:333`).
- **The `^` path does not move R1.** LOCAL_QUAL skips the two qualifier
  characters in `DESCRIPTOR` only (`gm/kernel.mar:646-647`), while
  HEX_CON tests for a sign at `(R1)` (`gm/kernel.mar:606`), which is still
  the `^`. So in `^X-10` the `-` is not handled by HEX_CON and is passed on
  to FOR$CNV_IN_Z.
- **Decimal integer overflow may fall into float.** If FOR$CNV_IN_I fails,
  the same text is tried with FOR$CNV_IN_DEFG (`gm/kernel.mar:628-632`). If
  FOR$CNV_IN_I rejects an out-of-range integer, that integer would become
  a float's bit pattern. This depends on the RTL routine's behaviour and is
  unverified.

### DIGIT

GM's DIGIT (`gm/kernel.mar:483-506`) has no decimal-point handling. A
character above `Z` goes to `not_digit` (`gm/kernel.mar:494-495`). So GM
does **not** have defect 1, where SAO's DIGIT takes any character above
`Z` as a decimal point (`kernel/rkernel.mar:643-644`). GM's DIGIT is used
only for the "other radix" case and for words not handled by `F_iliteral`.

## Floating point

GM has no float stack, no float words in the kernel and no MTH$ calls. Its
float package `gm/float.sto` works on F_floating values on P. It is
compared with SAO's in `doc/float.md`.

GM output is `#F` (`NRSGN_F`, `gm/kernel.mar:1352-1377`), with `=.`
defined as `#F COUNT TYPE` (`gm/float.sto:45`). The manual has
`'=. : #F MSG ;` (`gm/newstoic.mem:1745-1763`).

- `#F` moves one longword from P into the quadword `DP_VAL` and calls
  FOR$CNV_OUT_G with 6 fraction digits into a 32-byte field
  (`gm/kernel.mar:1353-1355`, `:1367-1377`). The high longword of `DP_VAL`
  is never written, so it stays 0, and the F value is read as an exact
  D_floating.
- It trims leading blanks by writing the length word in the two bytes
  before the first non-blank character, then trims trailing blanks
  (`gm/kernel.mar:1358-1366`).
- If FOR$CNV_OUT_G fails, `#F` returns with nothing pushed
  (`gm/kernel.mar:1357`), so `=.` would then type whatever was below.
- The manual's example is `1.23456 8.76544 +. #F MSG`, giving `10.00000`
  (`gm/newstoic.mem:2233-2249`).

## Safety checks

| Check | GM | SAO |
|---|---|---|
| `=` on an empty P | prints "Parameter stack empty" and returns (`gm/kernel.mar:1306-1312`) | no check; the moat page faults |
| `>` popping the last vocabulary | prints "Operation not honored -- would empty stack" (`gm/kernel.mar:1497-1514`) | no check (`kernel/rkernel.mar:1863-1865`) |
| Console end of file | LASTINCH does `ret`, which exits (`gm/kernel.mar:1061-1066`) | exits too (see AGENTS.md) |

## Errors and CTRL/C

| | GM | SAO |
|---|---|---|
| Condition handler | saves the PC, sets the restart PC to `ABORT`, resignals as a warning (`gm/kernel.mar:380-388`) | the same, plus `$UNWIND` when the signal came from deeper than one frame (`kernel/rkernel.mar:472-484`) |
| SYSERR | `LIB$SIGNAL`, then `halt` (`gm/kernel.mar:440-442`) | |
| CTRL/C | `here_on_ctrl_c` uses `ctrl_c_flag+user_table`, an absolute address (`gm/kernel.mar:1390-1396`) | recovers R11 from the argument block (`kernel/rkernel.mar:1727`) |
| CTRL/C handler | patches the AST frame's PC to ABORT (`gm/kernel.mar:1398-1409`) | the same (`kernel/rkernel.mar:1737-1747`) |

So GM shares defect 2: the CTRL/C AST never reaches `$ASTEXIT`. The
`$UNWIND` path that is the suspect in defect 18 is SAO-only.

## Output and I/O

- GM's `TYPE` jumps straight to `_type` (`gm/kernel.mar:1245`). SAO's
  jumps through `typeaddr(r11)` (`kernel/rkernel.mar:1558`), which
  `outinit` sets for a terminal or for batch (`kernel/rkernel.mar:424`).
- GM's `=` builds a negative sign with `movl #^a/-/,-(r5)`
  (`gm/kernel.mar:1335`), as SAO does (`kernel/rkernel.mar:1655-1690`). So
  GM shares defect 14: a `-` followed by three NULs.
- GM's number-output buffer `out_conv_stack` is static, 40 bytes
  (`gm/kernel.mar:970`).

## SS.MAR

| | GM `gm/ss.mar` | SAO `kernel/ss.mar` |
|---|---|---|
| Header | simple, inline (`gm/ss.mar:34-39`) | dictionary psect (`kernel/ss.mar:36`) |
| `$FAO` | yes (`gm/ss.mar:163`) | no |
| `FOR$CNV_OUT_G` | yes, by CALLG on `(R10)` (`gm/ss.mar:165-169`) | no |
| GETCMD | yes; `cmddesc` is static (`gm/ss.mar:174-181`) | yes; `cmddesc(r11)` (`kernel/ss.mar:291-296`) |
| `$SETPRN`, JPI$ ACCOUNT | no | yes (`kernel/ss.mar:231`, `:234`) |
| SEC$ global-section flags | fewer | `kernel/ss.mar:268-277` |
| Extra IO$ codes (READLBLK, SETCHAR, SETMODE, tape) | no | `kernel/ss.mar:185-207` |

## What GM lacks

Not found anywhere in `gm/kernel.mar` or `gm/ss.mar`:

- SAVE, XLOAD and MAPOPEN (SAO: `kernel/rkernel.mar:1138`, `:1195`,
  `:1207`), and so no IMAGE;
- the separate dictionary psect, the global link and the code-length word;
- the FS stack and `kernel/crtl.mar` (MTH$ words, `FLOAT_TO_STRING`,
  `STRING_TO_FLOAT`, the `SCR.` screen words);
- the TTIO and IORB support of `ttio.mar`, `tyio.mar` and `rms.mar`;
- REVISION, `CODE_PNTR` and `DICT_BASE`;
- `outinit`'s batch switch for TYPE.

## Defects compared

By `PLAN.md` number. All GM entries are from the source.

| Defect | In GM? | Why |
|---|---|---|
| 1 (DIGIT takes `>Z` as `.`) | no | `gm/kernel.mar:494-495` |
| 2 (CTRL/C skips `$ASTEXIT`) | yes | `gm/kernel.mar:1398-1409` |
| 5 (float text read as decimal in any radix) | no; floats only in DECIMAL or with `^D` | `gm/kernel.mar:626-633` |
| 6 (16-bit displacement not checked) | yes, and the reserved space is larger than the window | `gm/kernel.mar:925-926`, `:1545-1547` |
| 14 (`-` and three NULs) | yes | `gm/kernel.mar:1335` |
| 16–18 (FS words, MTH$ errors) | not applicable; no FS or MTH$ | |
