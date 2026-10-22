# The MACRO-32 kernel

This is Phase 5 of `PLAN.md`. It describes the SAO STOIC kernel, the
MACRO-32 program that `RKERNEL.EXE` and `HEAD0.EXE` are linked from and
that every STOIC, RED and IMAGE child carries at its base. It is built from
the source and checked against the results of Phases 1–4, which ran on
VAX/VMS V5.5-2H4. No new VAX runs were made for this page.

**Result:** the kernel is a small compile-and-go system with no inner
interpreter.
- It reads one line, compiles it into native VAX code in a buffer, and
  then jumps into the buffer. A word is a VAX subroutine that ends in RSB.
- A header lives in a separate DICTIONARY psect. It holds two link chains,
  the name, a lookup attribute, the code length and a 16-bit displacement
  of the code from R8.
- All state lives in a user table that R11 addresses with a bias of 8000.
- The stacks, the compile buffer, the RMS control blocks and the data
  region are each `$EXPREG`'d behind an unmapped moat page. Overflow and
  underflow show up as ACCVIO, not as checks.
- Errors go through one condition handler, which sends control to the
  word in the ABORT cell. CTRL/C patches a saved PC to do the same.

The design works on V5.5-2H4, shipped and rebuilt (`doc/build.md`). Its
known faults are listed by number in `PLAN.md`'s defect checklist and
described in `doc/defects.md`.

Conventions:
- Values are **hex** unless they say otherwise. Hex is also STOIC's
  default radix (`U_RAD` is 16 decimal, `rkernel.mar:2017`).
- Source files are in `saostoic-text/kernel/` unless a path is given.
- "Shipped" means `[.SAOSTOIC.STOIC]STOIC.EXE`. Its run-time addresses
  come from the tests named. The rebuilt exe has the same layout 4F800
  lower (`doc/build.md`).

## Modules and build

`rkernel.opt:1-3` links nine modules in this order. The second column is
the module name in `rkernel.map`.

| File | Module | What it holds |
|---|---|---|
| `dtinit.mar` | DTINIT | `K_START`/`GET_BLOCK` (the moat allocator), `DAT_START`, `DICT_START` |
| `crtl.mar` | CRTL | the FLOAT branch: float conversion and MTH$/OTS$ words |
| `controlc.mar` | CONTROLC | `enable_ctrl_c`, the CTRL/C AST |
| `ss.mar` | SYSTEM | the SS (system service) words, constants and GETCMD |
| `rms.mar` | RMS | the eight channels: OPEN, GET, PUT, SAVE, XLOAD and more |
| `tyio.mar` | TYIO | terminal QIO, plus the RMS fallbacks for batch |
| `ttio.mar` | TERMINAL | the TTIO branch: terminal QIO codes |
| `rkernel.mar` | KERNEL | START, the outer loop, the compiler, the user table |
| `extend.mar` | EXTEND | empty space at the end of each psect |

- `kermac.com` only assembles the modules. `kerlink.com` links them with
  `/MAP /NOTRACE` and copies `RKERNEL.EXE` to `HEAD0.EXE`.
- `rkernel.opt:4-8` adds `UNIVERSAL=START`, makes the three psects
  `WRT,SHR,PAGE`, and sets `IOSEGMENT=128,NOP0BUFS`.
- The rebuild on V5.5-2H4 is clean; see `doc/build.md`.

## Registers

`rkernel.mar:63-68` assigns them, and RESET_REGISTERS
(`rkernel.mar:515-521`) loads them.

| Register | Use | Value at reset |
|---|---|---|
| R11 | user table and data, biased by 8000 | set once in START (`rkernel.mar:310`) |
| R10 | parameter stack P, grows down | `P_STACK_0` |
| R9 | loop stack L, grows down | `L_STACK_0` |
| R8 | code base, biased by 8000 | `K_START+8000` (`rkernel.mar:519`) |
| R7 | float stack FS (D_floating), grows down | `F_STACK_0` |
| SP | return stack | `R_STACK_0` (I_ABORT, `rkernel.mar:488`) |
| FP | START's frame, the whole session | `(FP)` gets `COND_HANDLER` (`rkernel.mar:516`) |
| AP | START's argument list | never changed; GETCMD needs it (`ss.mar:293`) |

- The shipped STOIC's register dump at the end of `tests/12-math.expected`
  shows the reset values: R7=CE600, R8=27C00, R9=CE200, R10=CDE00 and
  R11=D7CF9.
- **Truth** is "any odd value": the kernel tests flags with `BLBS`/`BLBC`
  (`rkernel.mar:59-62`). The kernel itself pushes 1, −1 or 0.

## Threading: subroutine-threaded, compile-and-go

There is no inner interpreter. The compiler emits VAX instructions into
the compile buffer:

| Source item | Compiled bytes | Instruction | Where |
|---|---|---|---|
| a word (JUMP_TO_ME) | `16 C8 dddd` | `JSB W^d(R8)` | `rkernel.mar:1011-1018` |
| an integer literal | `D0 8F n 7A` | `MOVL #n,-(R10)` | `rkernel.mar:686-690` |
| a float literal | `70 8F q 77` | `MOVD #q,-(R7)` | `rkernel.mar:694-701` |
| a string literal | `16 C8 dddd`, count word, text | `JSB run_sliteral`, then inline data | `rkernel.mar:705-723` |
| a constant (PUSH_THIS_WORD) | `D0 9F a 7A` | `MOVL @#a,-(R10)` | `rkernel.mar:1032-1039` |
| a variable (DISP_TO_R11) | `DE CB dddd 7A` | `MOVAL W^d(R11),-(R10)` | `rkernel.mar:1043-1050` |
| an assembler opcode (COMPILE_BYTE) | one byte | the opcode | `rkernel.mar:1026-1029` |
| an IMMEDIATE word | nothing | it runs now | `rkernel.mar:1021-1022` |

- **run_sliteral** pops its return address, pushes it as the string
  address, and jumps past the text (`rkernel.mar:718-723`). So a string
  pushes one address, the address of its count word.
- **A constant's value is fetched at run time** from the word's code
  area, because `MOVL @#a` reads the cell rather than copying the value.
  CONSTANT stores the value at CODE_PNTR (`rkernel.mar:1757-1764`).
- **Integer literals** are `sign * magnitude` with no overflow check
  (`rkernel.mar:745-761`, defect 5). DIGIT takes any character above `Z`
  as a decimal point (`rkernel.mar:640-644`, defect 1). Literal syntax is
  covered in `doc/language.md`.

### Lines

The outer loop is `top_loop` (`rkernel.mar:450-467`):

1. Reset COMP_BUF_PNTR to COMP_BUF_0, and clear CHECK and END_OF_CMND.
2. Clear END_OF_LINE and call `@READLINE`. On end of file, run `;F` and
   read again.
3. Call `@COMPILE`, which compiles every word of the line.
4. If END_OF_CMND is set, or CHECK is not zero, go back to step 2. The
   next line is added to the same buffer.
5. Otherwise call `@EXECUTE`. I_EXECUTE stores an RSB (05) at the end of
   the buffer and jumps to COMP_BUF_0 (`rkernel.mar:802-806`). When the
   code returns, go back to step 1.

So a line is compiled in full before any of it runs. A definition, `HEX`
or a branch word takes effect from the next line (`tests/README.md`, rules
for writing tests; `tests/05-define`, `tests/08-vocab`).

I_COMPILE (`rkernel.mar:595-621`) takes a word with WORD and looks it up.
- On a hit it finds the attribute byte and the code address (R8 plus the
  header's displacement). It then calls the handler at
  `lookup_dispatch + attribute` (`rkernel.mar:610`).
- On a miss it tries `@LITERAL`. If that fails it types the word and
  calls `@COMPILE_ERROR` with "undefined" (`rkernel.mar:615-623`).
- The dispatch goes through the **prototype** table at its link-time
  address (`@l^lookup_dispatch(r0)`, 679 in the map), not through the
  run-time copy or the DISPATCH_ADR cell.

WORD (`rkernel.mar:1490-1542`):
- skips blanks, tabs and form feeds;
- ends a word at a space or tab;
- skips a `%` comment up to the next `%` (`rkernel.mar:1512-1517`);
- handles a leading `"` (`rkernel.mar:1504-1509`);
- copies the word into WORD_BUFFER with a 2-byte count.

### CHECK and nesting

CHECK counts open structures. The prompt shows it.

- `:` (IMMEDIATE, `rkernel.mar:815-823`) needs CHECK = 0, or it gives
  "Syntax Error". It then:
  - increments CHECK;
  - compiles `JSB int_colon`;
  - leaves a 2-byte hole for the length.
- `;` (IMMEDIATE, `rkernel.mar:844-854`):
  - decrements CHECK, which must become 0, or "Syntax Error";
  - stores an RSB;
  - fills in the length.
- rdef's IF, BEGIN and DO raise CHECK and their closers lower it. That is
  STOIC-level code; see `doc/language.md`.
- `(:)` and `(;)` (`rkernel.mar:863-873`) do `:` and `;` without changing
  the net CHECK, for words that build definitions.
- I_READLINE (`rkernel.mar:1456-1466`) writes `'0'+CHECK` into byte 5 of
  the prompt before each read.
  - The prompt prototype is `20 0D 0A 30 3E 20`, a space, CR, LF and `0> `
    (`rkernel.mar:1074`). `PROMPT @ COUNT` gives 6 (`tests/lang/K1-KERNEL.con`
    K4).
  - `tests/interactive/prompt.log` shows `0>` `1>` `2>` `3>` `2>` `1>` `0>`
    through `'FOO : 1 IF BEGIN 2 1 END THEN ;`.
- A definition is not made when its text is compiled. `:` compiles a call
  to int_colon, and the word is made when the line **runs**
  (`rkernel.mar:829-838`):
  1. int_colon calls `@ENTER` to make the header.
  2. It copies the body that follows the call into the code area at
     CODE_PNTR (`MOVC3`, `rkernel.mar:835`).
  3. It returns past the body.

  So a word used on the line that defines it is still undefined, and a
  redefinition's body still calls the old word (`tests/11-errors`, `CNT`;
  `tests/05-define`).
- A structure left open at `;` gives "Syntax Error"
  (`tests/11-errors.expected`, `'BAD : 1 IF 2 ;`).
- The compile buffer is 2 pages and nothing checks it (defect 4).
  `tests/interactive/compbuf.log` shows 8 lines of 90 characters fit in
  one definition, and the 17th ACCVIOs at CF001.

## Headers and the dictionary

### Header layout

The `header` macro (`rkernel.mar:167-191`) and I_ENTER
(`rkernel.mar:878-895`) build the same layout in the DICTIONARY psect:

| Offset | Size | Field |
|---|---|---|
| 0 | long | branch link: offset of the previous header in the same branch |
| 4 | long | global link: offset of the previous header's +4 on the global chain |
| 8 | byte + n | name, as an ASCIC string |
| 9+n | byte | lookup attribute |
| A+n | word | code length |
| C+n | word | code displacement from R8 |

- **Links are offsets.** A link holds `address − DICT_BASE`, where
  DICT_BASE is `DICT_START+8000` (`rkernel.mar:1985`). Lookup adds
  DICT_BASE back (`rkernel.mar:975`).
- **A chain ends at 7FFFFFFF** (`rkernel.mar:972`).
- **The code length** is patched in by `wterm`/`rsbx` for kernel words
  (`rkernel.mar:195-207`) and set by ENTER for new ones. Some kernel words
  end in a plain `rsb` without `wterm`, and the `dlrte`/`dlte` table words
  have no `wterm` at all. So their length is 0. INVENTORY shows TYO,
  F_STACK, GETCMD, JUMP_TO_ME and F_STACK_0 with `(0)`
  (`doc/data/stoic-inventory.txt`).
- **The displacement is 16 bits.** ENTER stores `CODE_PNTR − R8` with
  `CVTLW` and does not check it (`rkernel.mar:892-893`, defect 6). R8 is
  `K_START+8000`, so code must stay within 1FC00 and 2FBFF. The Phase 7
  patched build makes it a longword (header size 10+n, not E+n), and
  JUMP_TO_ME compiles `JSB L^disp(R8)` (16 E8, 6 bytes) when the
  displacement does not fit in a word (`doc/patches.md`, "Phase 7").

I_ENTER (`rkernel.mar:878-895`) takes a name, a code length and an
attribute. It:
1. stores the CURRENT branch head and the GLOBAL head as the two links;
2. makes the new header the head of both;
3. copies the name, the attribute and the length;
4. stores the displacement of CODE_PNTR;
5. advances DICT_PNTR.

### Lookup attributes

`lookup_dispatch` (`rkernel.mar:2052-2059`) is a table of handler
addresses. An attribute is a byte offset into it.

| Attribute | Value | Compile-time action | Made by |
|---|---|---|---|
| JUMP_TO_ME | 0 | compile `JSB W^d(R8)` | `:`/int_colon, `header` |
| IMMEDIATE | 4 | jump to the word now | rdef's IMMEDIATE stores 4 (`rdef:85-87`) |
| COMPILE_BYTE | 8 | compile the word's first code byte | AC (`rkernel.mar:923-929`) |
| PUSH_THIS_WORD | C | compile `MOVL @#code,-(R10)` | CONSTANT, `dlte` |
| PUSH_VOCAB | 10 | compile a PUSH_THIS_WORD, then `JSB V_PUSH` | BRANCH (`rkernel.mar:1842-1853`) |
| DISP_TO_R11 | 14 | compile `MOVAL W^d(R11),-(R10)` | DATA_ADDRESS, `dlrte` |

- LOOKUP_ATTRIBUTE (`rkernel.mar:932-937`) pushes the address of the
  newest CURRENT word's attribute byte. rdef's IMMEDIATE is
  `4 LOOKUP_ATTRIBUTE B!` (`rdef:85-87`).
- The kernel words named JUMP_TO_ME, IMMEDIATE and so on are `dlte`
  words. A `dlte` word's code holds the address of its table slot
  (`rkernel.mar:1917-1929`), so these words push a slot address, not the
  attribute number: `JUMP_TO_ME =` gives 679, `lookup_dispatch` in the
  map (`tests/lang/K1-KERNEL.con` K2). rdef uses the literal 4, and
  redefines IMMEDIATE as the word that marks the last definition.

### Lookup

I_LOOKUP (`rkernel.mar:947-964`) searches the branches on the
vocabulary stack. It starts at VOCAB_SP, the top, and stops at V_STACK_0.

- try_branch (`rkernel.mar:970-981`) follows the branch links.
- MATCH (`rkernel.mar:989-1000`) compares the length, then the text with
  `CMPC3`.
- There is no hashing. The newest word in the topmost branch wins.

### Branches and chains

The kernel modules build four branches and one global chain at assembly
time. Each module ends its chains with a `nullhead`, a header named `NULL`
whose code is one RSB.

| Branch | User-table cell | Contents | Linked by |
|---|---|---|---|
| KERNEL | `B_KERNEL` | rkernel's words, then the SS words of `ss.mar` | `nullhead ttioglob,ss_kernel,...` (`rkernel.mar:227`) |
| TTIO | `TTIO` | terminal IO$_, IO$M_ and $_ codes (`ttio.mar:118-161`) | `TTIO<` (`rkernel.mar:1886-1889`) |
| FLOAT | `FLOAT` | the crtl.mar words | `FLOAT<` (`rkernel.mar:1892-1895`) |
| ASSEMBLER, STOIC | `ASSEMBLER`, `STOIC` | empty: 7FFFFFFF (`rkernel.mar:1956-1957`) | filled by rdef |

- **The global chain** starts at `B_GLOBAL` and runs rkernel → ttio →
  ss → end:
  - `rkernel.mar:227` links it to `ttioglob`;
  - `ttio.mar:89` links it to `ssglob`;
  - ss.mar ends it with 7FFFFFFF (`ss.mar:91-103`), where the link to
    crtl is commented out (`ss.mar:90`).

  So **the FLOAT words are not on the global chain**: `crtl.mar:68` gives
  both links the sentinel, and nothing refers to `crtlglob`.
- rdef's INVENTORY walks the global chain (`rdef:1363-1371`).
  `doc/data/stoic-inventory.txt` ends with the three NULLs, at D=10480
  (KERNEL), 10108 (TERMINAL) and FA67 (SYSTEM). It lists no crtl word.
- START puts B_KERNEL on the vocabulary stack and makes it CURRENT
  (`rkernel.mar:383-387`).
- Vocabulary words:

  | Word | What it does | Where |
  |---|---|---|
  | `V_PUSH` | push a branch cell on the vocabulary stack | `rkernel.mar:1856-1860` |
  | `>` | pop it (VOCAB_SP + 4), unchecked | `rkernel.mar:1863-1865` |
  | `DEFINITIONS` | make the top branch CURRENT | `rkernel.mar:1868-1870` |
  | `ASSEMBLER<`, `STOIC<` | push those cells | `rkernel.mar:1873-1884` |
  | `BRANCH` | make a PUSH_VOCAB word | `rkernel.mar:1842-1847` |

  rdef redefines BRANCH; defect 22 is about that version.

## The user table

R11 points 8000 bytes past the start of the user table. Each cell is
`W^d(R11)` with d from −8000 up, so all 180 bytes are in reach of a
word displacement.

- `dlrte` (`rkernel.mar:1903-1915`) makes each cell and a DISP_TO_R11
  word of the same name. The symbol is `offset − 8000`, so the map shows
  the cells as FFFF8000 to FFFF817C.
- The table starts at `ut_start` (`rkernel.mar:1936`, 4F9 in the
  prototype). `lookup_dispatch` follows it (679). `dat_end` is 691
  (`rkernel.map`).
- In the shipped STOIC, R11 is D7CF9, so the table starts at CFCF9 =
  `USER_DATA` + 2F9 (`tests/12-math.expected`; `doc/image.md`).

The cells by group, with offsets from the map:

| Offset | Cells |
|---|---|
| 00–18 | ADDRESS_STORAGE (2 longs), COND_HANDLER, CTRL_C_TEMP (2), CTRL_C_FLAG, CTRL_C_HANDLER |
| 1C–34 | P_STACK_0, R_STACK_0, L_STACK_0, F_STACK_0, V_STACK_0, FRAME_0, VOCAB_SP |
| 38–48 | OUT_CONV_STACK; the branch heads ASSEMBLER, STOIC, TTIO, FLOAT |
| 4C–94 | the compiler's vectors: DISPATCH_ADR, LOOKUP, COMPILE, COMP_BUF_0, COMP_BUF_PNTR, END_OF_CMND, END_OF_LINE, CHECK, EXECUTE, LITERAL, ERRCHK, READLINE, ABORT, ERROR_PC, COND_CODE, COMPILE_ERROR, DATE (quad), DATE_ERROR |
| 98–E4 | TIME_STRING, ENTER, CODE_PNTR, DICT_PNTR, DICT_BASE, USER_DICTIONARY, USER_CODE, DICT_0, CODE_0, DATA_0, DATA_END, USER_DATA, VARIABLE_LIST, B_KERNEL, B_GLOBAL, CURRENT, GLOBAL, PROMPT (2), USER_INIT |
| E8–110 | U_IFI, U_IFM, U_IFT, LINE_BUFFER, REST_OF_LINE (quad), WORD_BUFFER, U_SGN, U_MAG (quad), U_FLOAT |
| 114–134 | U_RAD, `.D`, `.M`, MSG_CHANNEL, RANDOCHAN, BLK_CHAN, TYOADDR, TYPEADDR, CHANNEL_LIST |
| 138–17C | CMDDESC, TTNAME, TTCHAN (2), NLEN, NADDR, NSTORE, and the remote-line cells RMINAME … RMBUF |

- **Vectors.** LOOKUP, COMPILE, EXECUTE, LITERAL, READLINE, ABORT,
  COMPILE_ERROR, ENTER, USER_INIT, DATE_ERROR, COND_HANDLER and
  CTRL_C_HANDLER hold code addresses. The kernel calls through them
  (`jsb @x(r11)`). rdef replaces some: ABORT becomes ERROR_TRACE
  (defect 19) and USER_INIT becomes DEF_INIT.
- **Initial values** (`rkernel.mar:2005-2022`): U_IFM 3, U_RAD 10 hex
  (16 decimal), MSG_CHANNEL 4, RANDOCHAN 5, BLK_CHAN 6.
- **TTCHAN** is 2 longwords (`rkernel.mar:2028-2030`). The terminal QIOs
  write an 8-byte IOSB at TTCHAN+2, which runs 2 bytes into NLEN
  (`tyio.mar:136, 154, 168, 177, 185`; defect 3).
  In `tests/interactive/tty.log`, NLEN no longer equals the length of
  the terminal's name, at startup or after a QIO.
- **Run-time addresses.** DATA_INIT (`rkernel.mar:492-513`) stores the
  run-time addresses of the line and word buffers, the prompt, the
  output-conversion stack, the time string, the channel list, the
  terminal name and the CLI request descriptor. They are R11-relative
  `MOVAL`s (`a_to_ut`, `rkernel.mar:272-278`).

## Memory

### Psects

From `rkernel.map`:

| Psect | Base | End | Contents | EXTEND space |
|---|---|---|---|---|
| DATINIT | 200 | F690 | the data prototype: control blocks, buffers, user table | F000 (`extend.mar:12-13`) |
| DICTIONARY | F800 | 1FB2E | headers | E400 (`extend.mar:4-5`) |
| KERNEL | 1FC00 | 2FB4C | code | DE00 (`extend.mar:8-9`) |

- `extend.mar` pads each psect to 10000 bytes from its base, so headers,
  code and data each get room to grow inside the image.
- The image runs from 200 to 2FDFF: 382 decimal pages, a 1-block header
  and 14 decimal image sections (`rkernel.map`).
- Names for the boundaries:

  | Cell | What it holds | Where |
  |---|---|---|
  | `DATA_0`, `DICT_0`, `CODE_0` | psect starts | `rkernel.mar:1988-1990` |
  | `DATA_END` | DAT_FIN, F691 | `rkernel.mar:1991` |
  | `USER_DICTIONARY` | the page after the kernel's headers | `rkernel.mar:1986` |
  | `USER_CODE` | the page after the kernel's code, 21E00 | `rkernel.mar:1987`; `doc/build.md` |

### START

START (`rkernel.mar:283-436`) is the transfer address: 20DD2 shipped,
20DDA rebuilt (`doc/build.md`). It does the following.

1. **Allocates blocks**, each through ISOLATE_BLOCK/`get_block`
   (`dtinit.mar:10-23`). `get_block` `$EXPREG`s n+1 pages and deletes the
   first with `$DELTVA`, which makes it the moat. It returns the first
   usable address in R1 and the first unusable one in R2. The blocks, in
   order:
   - P stack (2 pages), L stack (1), F stack (1), V stack (1). Each
     stack's base is R2, its top end, because the stacks grow down;
   - the compile buffer (2 pages), with base R1;
   - the FAB/RAB/XAB space (`rkernel.mar:305`);
   - the data region (`rkernel.mar:335-341`).
2. **Sets R11** to `R2 + (ut_start − dat_start) + 8000 + 200`, using R2
   from the FAB block (`rkernel.mar:310`). The 200 skips the data
   region's moat. This assumes the next `$EXPREG` follows on directly.
3. **Builds eight RAB/FAB pairs** from the RMS prototypes
   (`rkernel.mar:316-331`). The last three get an XAB (FHC), and they
   become channels 5, 6 and 7. The space was sized for two XABs
   (`rkernel.mar:305`); the page rounding leaves room.
4. **Copies the data prototype** into the data region
   (`MOVC3 dat_start`, `rkernel.mar:345`). The length is the word at
   `DAT_START`, `dat_end − dat_start` (`dtinit.mar:27-28`). Then it runs
   DATA_INIT, sets `.D`, `USER_DATA` and `.M`, fills CHANNEL_LIST and
   calls SETUP_FABS (`rkernel.mar:351-365`).
5. **Stores the stack bases**, `R_STACK_0 = SP` and `FRAME_0 = FP`
   (`rkernel.mar:369-378`). It then runs RESET_REGISTERS and starts the
   vocabulary stack (`rkernel.mar:383-387`).
6. **Remaps the dictionary and code tails** (`rkernel.mar:392-408`). It
   runs `$DELTVA` and `$CRETVA` from USER_DICTIONARY to DICT_END and from
   USER_CODE to K_END. This gives fresh writable pages, and it sets
   DICT_PNTR and CODE_PNTR to their starts. `doc/image.md` explains why
   IMAGE depends on this. In the patched build the code range runs to
   k_top, the end of the KERNEL psect, a spare page past K_END, and its
   end is never below its start: VMS works downward through a range whose
   start is above its end, and a child of a full exe then got a
   CODE_PNTR of 701FF (`doc/image.md`, "Filling the code space").
7. **Opens the console:**
   - installs the prompt (`rkernel.mar:412-413`);
   - opens SYS$INPUT on channel 0 with `_WOPEN_NCR`
     (`rkernel.mar:415-420`). That is a `$CREATE` with PUT access only
     (`rms.mar:297-306`, defect 25);
   - runs `outinit` (`rkernel.mar:424`) and `enab_ctrl_c` (427);
   - opens SYS$OUTPUT on MSG_CHANNEL (4) (`rkernel.mar:430-432`).
8. **Calls `@USER_INIT`**, then jumps to `top_loop`
   (`rkernel.mar:435-436`).
   - The kernel's own USER_INIT prints "Welcome to the STOIC kernel."
     (`rkernel.mar:438-447`).
   - STOIC.EXE prints "Welcome to STOIC", rdef's
     (`tests/interactive/prompt.log`).

Every `.errstop` in START exits through LIB$STOP on failure
(`rkernel.mar:84-89`, defect 7).

### The run-time map and the moats

The blocks of the shipped STOIC, from the addresses the tests show:

| Block | Moat | Usable | Evidence |
|---|---|---|---|
| P stack | CD800 | CDA00–CDDFF; R10 starts at CDE00 | R10 in `tests/12-math.expected` |
| L stack | CDE00 | CE000–CE1FF; R9 starts at CE200 | R9 in `12-math` |
| F stack | CE200 | CE400–CE5FF; R7 starts at CE600 | R7 in `12-math` |
| V stack | CE600 | CE800–CE9FF | `V_STACK` gives CEA00 (`tests/lang/K1-KERNEL.con` K5) |
| compile buffer | CEA00 | CEC00–CEFFF | `doc/build.md`; `COMP_BUF_0 @` gives CEC00 (K5) |
| FAB/RAB/XAB | CF000 | CF200–CF7FF | the compile-buffer fault at CF001 (`compbuf.log`) |
| data, user table | CF800 | from CFA00 (`USER_DATA`) | `doc/image.md`; R11 = D7CF9; `USER_DATA @` gives CFA00 (K15) |

- The moat pages are unmapped (`$DELTVA`, `dtinit.mar:20`), so any access
  faults with ACCVIO.
- A stack that **overflows** runs down into its own moat.
- A stack that **underflows** runs up into the moat of the next block.
  `tests/11-errors`: `DROP DROP DROP` on an empty stack does not fault,
  but the next fetch does, at CDE08 in the L stack's moat.
- The compile buffer overflows up into the FAB block's moat at CF000
  (`compbuf.log`, defect 4).
- MOAT (`rkernel.mar:1785-1787`) pushes `P_STACK_0 − 200`, which is CDC00:
  the lower P-stack page, not the moat. Its comment assumes a one-page P
  stack; `p_stack_size` is 2 (`rkernel.mar:75`). P_STACK, L_STACK and
  V_STACK push the stack bases, CDE00, CE200 and CEA00
  (`rkernel.mar:1791-1811`; `tests/lang/K1-KERNEL.con` K5).
  F_STACK uses `MOVAL`, so it pushes the address of the F_STACK_0 cell,
  not its contents (`rkernel.mar:1803-1805`): `F_STACK =` gives CFD21 and
  `F_STACK_0 @ =` CE600 (K6).
- `B,` and `,` append to the **code** area at CODE_PNTR, despite their
  comments (`rkernel.mar:1816-1828`). `5 B,` moves CODE_PNTR from 25801
  to 25802 (K8).
- The rebuilt exe has the same blocks 4F800 lower (`doc/build.md`). SAVE
  files and IMAGE depend on this layout (defect 11, `doc/image.md`).

## Errors

### The condition handler

RESET_REGISTERS puts COND_HANDLER, which is `i_cond_handler`, in START's
frame (`rkernel.mar:516`). Since every word runs by JSB inside START, it
handles every fault. The handler (`rkernel.mar:472-484`):

1. saves the signal PC in ERROR_PC and the condition code in COND_CODE;
2. replaces the signal PC with the contents of the ABORT cell;
3. clears the severity bits, which makes it a warning;
4. calls `$UNWIND` with depth 1 if the faulting frame is not START's
   (`rkernel.mar:480-482`);
5. returns SS$_RESIGNAL.

VMS then prints the message and continues at ABORT.
- Every message therefore shows ABORT's address as the PC (defect 19):
  PC=00023998 in `tests/11-errors.expected`, which is ERROR_TRACE.
- ERROR_TRACE then prints the line, the word and a traceback.
- The `$UNWIND` path is the suspect in defect 18: `.SQRT` of a negative,
  signalled from inside MTH$, ends STOIC (`tests/12-math.expected`).
- A fault in the middle of MOVC3 leaves PSL<FPD> set, so it loops
  (defect 27).

I_ABORT, the kernel's ABORT (`rkernel.mar:486-490`), reloads the
registers, resets SP to R_STACK_0, and goes to `top_loop`. That empties
every stack and drops the rest of the line. `tests/11-errors` shows the P
stack pointer back at its base after an abort.

### Kinds of error

| Kind | Path | Effect | Test |
|---|---|---|---|
| compile error (undefined word, syntax) | I_COMPILE_ERROR (`rkernel.mar:525-540`) | prints `<msg> error compiling...  <word>  ...in line`, runs LOAD_RESET, then I_ABORT. Every LOAD under way ends. | `11-errors`, `10-files` (10D) |
| run-time fault | handler → ABORT | message, traceback; only the current line ends | `11-errors` |
| FATAL (`rkernel.mar:548-552`) | message, then `jmp @ABORT` | like a run-time fault; a LOAD carries on | `10-files`: "Input file table overflow." |
| SYSERR (`rkernel.mar:557-564`) | LIB$SIGNAL if the status is even | handler → ABORT | |
| `.errstop` (`rkernel.mar:84-89`) | LIB$STOP | STOIC exits (defect 7) | `11-errors`: LOAD of a missing file |
| console read error | SYSERR → ABORT → read again | endless loop (defect 24) | `interactive/image-console` |

ERRCHK is an empty stub (`i_errchk`, `rkernel.mar:1063-1064`), and its
call in `top_loop` is commented out (`rkernel.mar:451`).

### CTRL/C

`enab_ctrl_c` (`rkernel.mar:1720-1725`) calls `enable_ctrl_c`
(`controlc.mar:35-83`). That routine:
- assigns its own channel to SYS$COMMAND;
- checks with `$GETCHN` that it is a terminal, and does nothing if not
  (`controlc.mar:75-77`);
- arms a CTRL/C AST with `IO$_SETMODE!IO$M_CTRLCAST`. The AST parameter
  is the CTRL_C_TEMP cell (`controlc.mar:79-81`).

On CTRL/C:
1. The AST routine in `controlc.mar:85-90` calls the kernel's
   `here_on_ctrl_c`.
2. `here_on_ctrl_c` (`rkernel.mar:1727-1735`) recovers R11 from the AST
   parameter, sets CTRL_C_FLAG to −1, and calls `@CTRL_C_HANDLER` if it
   is not zero.
3. The default handler, I_CTRL_C_HNDLR (`rkernel.mar:1737-1748`), walks
   the saved-FP chain. It looks for the frame whose saved FP equals
   R_STACK_0 (START's SP after setup) and writes `i_abort` into that
   frame's saved PC. R_STACK_0 and FRAME_0 hold the same value (K1:
   `R_STACK_0 @ FRAME_0 @ - =` gives 0), so the match is START's frame.
4. The kernel routine returns. The AST routine re-arms the AST
   (`brb CKTERM`) and returns, into I_ABORT.

It never goes through the AST exit. The process stays at AST level, so a
later CTRL/C is not delivered (defect 2). `tests/interactive/ctrlc.log`
shows the first ^C cancelling `BEGIN 0 END`, DELAY still working, and
then a second ^C with no effect.

## Terminal and RMS I/O

### Output: QIO or RMS

`outinit` (`tyio.mar:105-129`) chooses the output routines once, at
startup:
1. `_TYOPEN` (`tyio.mar:87-98`) assigns TTCHAN to SYS$COMMAND.
2. `$GETCHN` checks the device class.
3. The result:
   - **Terminal:** TYOADDR and TYPEADDR get `_tyo` and `_type`,
     `IO$_WRITEVBLK!IO$M_NOFORMAT` QIOs on TTCHAN (`tyio.mar:126-127`,
     `174-188`).
   - **Otherwise** (batch): the channel is deassigned. TYOADDR and
     TYPEADDR get `_rmstyo` and `_rmstype`, `$PUT`s on MSG_CHANNEL
     (`tyio.mar:119-123`; `rms.mar:774-787`). Each TYO is its own record
     (defect 8).

TYO and TYPE jump through these cells (`rkernel.mar:1558-1560`,
`1608-1610`). MSG is COUNT then TYPE (`rkernel.mar:1573-1576`). So
interactive output goes to the terminal named by SYS$COMMAND, not to
SYS$OUTPUT (`AGENTS.md`; `tools/vax-do -t`).

### Console input: RMS

- READLINE reads the console with RMS: GET_STRING on channel `INCH`,
  which is 0 at console level (`rkernel.mar:1417-1427`, `1456-1466`).
- Channel 0's RAB has ROP PMT+CVT (`rkernel.mar:1099`). RMS therefore
  writes the prompt and **uppercases** the line. cmpfix sets only PMT, so
  its console keeps the case typed (`cmpfix.md`, "Console case").
- `_PROMPT` puts the prompt in the RAB's PBF/PSZ (`rms.mar:432-436`).
- A LOAD file is read on channels 1–3, without CVT, so it is not
  uppercased (`AGENTS.md`).
- End of file on the console runs `;F`. That runs LASTINCH, which
  decrements U_IFI below 0 and RETs from START's frame, so STOIC exits
  (`rkernel.mar:1323-1329`, `1384-1389`). `prompt.log` shows CTRL/Z
  exiting.

### Terminal words

All use TTCHAN and an IOSB at TTCHAN+2 (defect 3).

| Word | QIO | Where |
|---|---|---|
| TYI | `IO$_READVBLK!NOECHO!NOFILTR`, 1 byte | `tyio.mar:132-138` |
| TYPE_GETLINE | `IO$_READPROMPT!NOFILTR!TRMNOECHO`, ends on control characters and ESC | `tyio.mar:142-160` |
| TYPE_TYI | a prompt and one byte; the function code has `-^X100` | `tyio.mar:162-172` |
| IO_CTRL_C | −1 if the last IOSB holds 651 (SS$_CONTROLC) | `tyio.mar:190-196` |
| GETMODE, SETMODE | `IO$_SENSEMODE`/`IO$_SETMODE` with a 0C-byte block | `tyio.mar:198-210` |

- `tests/interactive/tty.log` exercises each of these.
- The remote-line code (`tyio.mar:217-287`, REMSTART and REMTYPE) is
  defect 9. It is untested.

## Channels

RMS channels are numbered 0–7. CHANNEL_LIST points to the RAB of each
(`rkernel.mar:361-364`; `rms.mar:128-129`). Each RAB points to its FAB.

| Channel | Use | Set up by |
|---|---|---|
| 0 | console input (SYS$INPUT); ROP PMT+CVT (cmpfix: PMT) | START, SETUP_FABS (`rkernel.mar:1099`) |
| 1–3 | LOAD nesting and sequential files: OPEN, WOPEN, GET, PUT | NEXTINCH; U_IFM = 3 |
| 4 | messages (SYS$OUTPUT); the RMS output in batch | START (`rkernel.mar:430-432`) |
| 5 | keyed: RANDOGET, RANDOPUT; KSZ 4, RAC KEY, FAC GET+UPD | SETUP_FABS (`rkernel.mar:1107-1112`) |
| 6 | block I/O: SAVE, XLOAD; FAC BIO+GET+PUT | SETUP_FABS (`rkernel.mar:1113-1116`) |
| 7 | user-file-open: MAPOPEN | SETUP_FABS (`rkernel.mar:1117-1120`); `rms.mar:254-269` |

- Channels 5, 6 and 7 are the ones with XABs.
- SETUP_FABS also sets the file name of channels 0 and 4 to
  `sys$command` (`rkernel.mar:1100-1106`). The opens in START replace it.
- A plain PUT on channel 5 gives RMS-W-RAC (`tests/10-files.sto`
  header).
- The open routines (`rms.mar`):

  | Routine | Lines | Access and service |
  |---|---|---|
  | `_OPEN` | 226-234 | GET, not PUT; `$OPEN` |
  | `_WOPEN` | 272-281 | PUT, not GET, RAT=CR; `$CREATE` |
  | `_WOPEN_NCR` | 297-306 | as `_WOPEN`, RAT=0 |
  | `_ROPEN` | 238-251 | GET+UPD |
  | `_APPEND` | 321-331 | ROP=EOF |

  Each then `$CONNECT`s (`docon`, `rms.mar:210-214`).
- `_GET` (`rms.mar:354-366`) turns RMS$_EOF into a 0 flag with a success
  status.
- `tests/10-files` writes a file with WOPEN and PUT and reads it back
  with OPEN and GET on channel 3.
- SAVE and XLOAD (`rms.mar:655-768`) are covered in `doc/image.md`.

## LOAD

LOAD nests input on channels 1–3. U_IFI is the current input channel and
U_IFM the highest allowed (3).

| Word | What it does | Where |
|---|---|---|
| `INCH` | push U_IFI | `rkernel.mar:1305-1307` |
| `NEXTINCH` | U_IFI + 1, or FATAL "Input file table overflow." if that passes U_IFM | `rkernel.mar:1311-1320` |
| `LOAD` | NEXTINCH, then OPEN on the new channel | `rkernel.mar:1332-1335` |
| `;F` | INCH, CLOSE, LASTINCH | `rkernel.mar:1384-1389` |
| `LASTINCH` | U_IFI − 1; below 0, RET and exit STOIC | `rkernel.mar:1323-1329` |
| `LOAD_RESET` | `;F` until U_IFI is 0 | `rkernel.mar:1393-1400` |

- LOAD only switches the channel. The rest of the line that called LOAD
  has already been compiled, and it runs first. READLINE then reads the
  next line from the new channel (`rkernel.mar:1461`). `'KA.STO LOAD
  "AFTER" MSG` prints AFTER before the file's "IN A" (`tests/lang/K1-KERNEL.con` K10).
- At end of file, `top_loop` runs `;F` and reads from the previous level
  (`rkernel.mar:456-458`).
- `tests/10-files`:
  - LOAD nests three deep (10-FILES, 10A, 10B).
  - A fourth LOAD gives "Input file table overflow." through FATAL. 10B
    carries on ("BACK IN 10B").
  - A compile error in 10D ends every level through LOAD_RESET.
- OPEN of a missing file exits STOIC through `.errstop`
  (`rkernel.mar:1130-1135`, defect 7; `tests/11-errors`).

## SS words

ss.mar makes the system-service words. The `SS` macro
(`ss.mar:129-134`) expands `SS $GETTIM` into:

```
header $GETTIM
    $GETTIM_G (R10)     ; CALLG (R10),SYS$GETTIM
    MOVL R0,(R10)
    RSB
```

- The STOIC parameter stack **is** the argument list. The caller pushes
  the arguments last to first, then the count. The service runs with
  `CALLG` on it.
- The status replaces the count on top. **The arguments stay on the
  stack.** For example, rdef's DELAY pushes four arguments, then
  `4 $SETIMR SYSERR`, then `6 (DROP)` (`rdef:867-873`). TRNLOG ends
  `6 $TRNLOG SYSERR 0A (DROP)` (`rdef:1091-1097`).
- The V5 `$ASSIGN_S` change does not affect `$ASSIGN`: the `_G` form
  takes its count from the stack (`doc/build.md`).

The words, by group:

| Group | Words | Lines |
|---|---|---|
| event flags | `$READEF`, `$CLREF`, `$WAITFR` | `ss.mar:164-168` |
| logical names | `$TRNLOG` | `ss.mar:175` |
| I/O | `$ASSIGN`, `$DASSGN`, `$QIO`, `$QIOW`, `$GETCHN` | `ss.mar:179-183` |
| messages | `$GETMSG` | `ss.mar:222` |
| processes | `$CREPRC`, `$DELPRC`, `$WAKE`, `$SCHDWK`, `$EXIT`, `$SETPRN`, `$SETPRI`, `$GETJPI` | `ss.mar:226-233` |
| time | `$GETTIM`, `$NUMTIM`, `$ASCTIM`, `$BINTIM`, `$SETIMR` | `ss.mar:244-248` |
| memory | `$EXPREG`, `$CRETVA`, `$DELTVA`, `$CRMPSC`, `$UPDSEC`, `$MGBLSC`, `$DGBLSC`, `$SETPRT` | `ss.mar:256-264` |

Constant words push a code with `MOVL #n,-(R10)`:
- `IO$_…` and `IO$M_…` (`ss.mar:142-146`, `185-214`);
- `$_…`, the SS$ codes (`ss.mar:154-158`, `165-166`, `217-218`);
- `SEC$M_…` (`ss.mar:148-152`, `268-277`);
- `JPI$` item words, named without a prefix: ACCOUNT, CPUTIM, DIRIO,
  FREP0VA, GRP, MEM, UIC (`ss.mar:136-140`, `234-240`).

Notes:
- **They are in the KERNEL branch.** ss.mar's headers use its local
  `kernel` chain. rkernel's `nullhead` links that chain to the end of its
  own (`ss.mar:302-303`; `rkernel.mar:227`).
- **TTIO repeats some of them** in its own branch: the terminal IO$_,
  IO$M_ and $_ codes (`ttio.mar:118-161`). INVENTORY lists
  `IO$_READVBLK` and `$_NORMAL` twice, once from each module
  (`doc/data/stoic-inventory.txt`).
- `ss.mar:249` is a bare `$SCHDWK` with no `SS` in front. It makes no
  word; the word comes from line 229.
- **GETCMD** (`ss.mar:291-296`) asks the CLI for the command line with
  the old callback, `CALLS #1,@CLI$A_UTILSERV(AP)`. The request block is
  `$CLIREQDESC CLI$K_GETCMD` (`ss.mar:286`), and CMDDESC points to it
  (DATA_INIT). GETCMD pushes the command-string descriptor.
  - It relies on AP still being START's argument list. That holds,
    because the kernel never changes AP.
  - It works on V5.5-2H4, with and without a tail (`tests/13-calc`,
    defect 10). rdef's DEF_INIT runs the tail with it.
- **SYSTEM_SERVICES** (`rkernel.mar:1779-1782`) pushes `ss_calls`, a
  pointer to the last SS header (`ss.mar:298`).
