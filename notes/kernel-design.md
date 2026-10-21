# SAO STOIC VAX/VMS Kernel: Design Report

> **Historical.** This is a first draft written from reading the code before
> any test. It is superseded by `doc/` (see `doc/README.md`), which corrects
> it in places. Keep it for history; don't cite it.

Sources: `/home/tkb/Repos/STOIC/saostoic-text/kernel/` (rkernel.mar, rms.mar, ss.mar, ss.src, tyio.mar, ttio.mar, crtl.mar, controlc.mar, dtinit.mar, extend.mar, rkernel.opt, rkernel.map, kermac.com, kerlink.com) and the older GM variant in `/home/tkb/Repos/STOIC/saostoic-text/gm/` (kernel.mar, ss.mar, aaareadme.1st). Citations are `file:line`. Unless a directory is given, the file is in `kernel/`.

## 1. Overview

STOIC is a FORTH-like system. This kernel is a **native-code, subroutine-threaded** implementation. There is no inner interpreter and no NEXT. Every word is a VAX machine-code routine that ends in `RSB`. Calling a word compiles to `JSB w^disp(R8)`.

Input is processed **one line at a time**. Each line is compiled into a scratch compile buffer, an `RSB` is appended, and the buffer is executed. A colon definition is just compiled code that, when the line runs, copies itself into the permanent code area and links a header in.

The kernel is split into a few modules:

- rkernel.mar: compiler, dictionary, stacks, the outer loop.
- rms.mar: RMS file I/O.
- tyio.mar: terminal I/O through QIO.
- controlc.mar: the CTRL/C AST.
- dtinit.mar: allocating virtual memory blocks.
- ss.mar and ttio.mar: system service words and constant words.
- crtl.mar: floating point and the VMS run-time library.
- extend.mar: psect padding.

## 2. Register usage

Registers are declared at rkernel.mar:64-69 and loaded by RESET_REGISTERS at rkernel.mar:515-521.

| Reg | Use |
|---|---|
| R11 | Base of the user table and data area. It points 0x8000 bytes past the start of the user table, so all entries are reached as `w^(-0x8000+n)(r11)`. This gives a 64 KB window reachable with word displacements. |
| R10 | Parameter stack. Grows down; `-(r10)` pushes, `(r10)+` pops. |
| R9 | Loop stack, used for DO-style indices. `=` also uses the area below R9 as scratch for building digits. |
| R8 | Code base, `k_start+0x8000`. All compiled calls are `JSB w^d(r8)`. |
| R7 | Floating-point stack. Holds D_float quadwords and grows down. |
| SP | Return stack. Its base, `r_stack_0`, is recorded at START. |
| FP | START's call frame. `(fp)`, the condition-handler slot, is set to `cond_handler`. |
| AP | START's argument list, needed later by GETCMD (ss.mar:293). |

**Truth convention.** A value is true when its low bit is set. The kernel tests with `blbs`/`blbc`. The macros `..succeed` and `..fail` push the truth values; `..if`, `..else` and `..then` test them.

## 3. Threading model and compile-and-go execution

The outer loop is `top_loop` at rkernel.mar:450-467:

1. Read a line (`I_READLINE`).
2. Repeatedly call WORD and compile each token into the compile buffer.
3. When the line is used up and `CHECK` is 0, run `I_EXECUTE`. This stores an RSB and does `jmp @comp_buf_0` (rkernel.mar:802-806).
4. The buffer is reset and the loop repeats.

`CHECK` counts how deeply definitions are nested. The prompt shows it as the digit at prompt+5 (rkernel.mar:1457-1458). While `CHECK` is not 0, lines keep piling up in the buffer, so a definition can span many lines and runs only when it is closed.

Each token compiles as follows:

- **A found word** is dispatched on its attribute (section 4). The default attribute, JUMP_TO_ME, compiles `16 C8 dddd`, which is `JSB w^disp(r8)` (I_JUMP_TO_ME, rkernel.mar:1011-1018).
- **An integer literal** compiles `D0 8F <imm32> 7A`, which is `MOVL #n,-(r10)` (ICOMPILE, rkernel.mar:682-690).
- **A floating-point literal** compiles `70 8F <imm64> 77`, which is `MOVD #d,-(r7)`. The value is converted with OTS$CVT_T_D (crtl.mar:105-110).
- **A string literal** compiles `JSB run_sliteral`, then a word count and the bytes inline. At run time the address is pushed and the code skips past the text (rkernel.mar:705-723).
- **An immediate word** runs at compile time (section 4).

**Colon definitions** are handled at rkernel.mar:815-854.

- The syntax is `'NAME : body ;`. The quoted name is itself a string literal compiled into the same line, so the name is pushed when the line executes.
- `:` is immediate. It requires CHECK to be 0, increments CHECK, compiles `JSB int_colon`, and reserves a 2-byte count.
- `;` is immediate. It decrements CHECK, stores an RSB, and fills in the count.
- When the line runs, `int_colon` does the following:
  1. Calls ENTER with the name string on the stack, which builds the header.
  2. Copies the body bytes from the compile buffer to `code_pntr`.
  3. Records the code length and displacement in the header.
  4. Changes its own return address to just past the body, so the body is not executed.
- `(:)` and `(;)` are deferred versions for use inside definitions. They adjust CHECK and then call COLON or SEMI_COLON.

**Consequence.** Compiled code is position-dependent only through R8 and R11 displacements, and through absolute addresses compiled by PUSH_THIS_WORD. Code copied out of the compile buffer stays valid because every call is relative to R8, not PC-relative.

## 4. Dictionary, headers, vocabularies, lookup

### Header layout

The `header` macro (rkernel.mar:167-191; copies in ss.mar:36-51 and ttio.mar:36-51) uses **separate headers**: headers go in the `DICTIONARY` psect and code goes in `KERNEL`. A header contains:

```
+0  .long  branch link      (offset of previous entry in same branch, rel. dict_start+0x8000)
+4  .long  global link      (offset of previous entry's +4 on the global chain)
+8  .ascic name
    .byte  lookup attribute
    .word  code length      (back-patched by WTERM / RSBX, rkernel.mar ~185-191)
    .word  code displacement relative to R8 (kplace-k_start-0x8000)
```

- Links are offsets from `dict_base` (`dict_start+0x8000`), not absolute addresses. The end of a chain is the sentinel `0x7fffffff` (ss.mar:94-97).
- Because the code address is a 16-bit displacement from R8, every kernel and user word must lie within the 64 KB window around `k_start`.
- The code length is used by `<INLINE>` and by tools that copy code.

### Attributes and dispatch

Lookup returns the entry, and the compiler then runs `jsb @l^lookup_dispatch(r0)` (rkernel.mar:610). The dispatch vector is in the data prototype at rkernel.mar:2052-2059 and holds longword addresses indexed by attribute 0, 4, 8, and so on.

| Attr | Handler | Compile-time effect |
|---|---|---|
| JUMP_TO_ME | I_JUMP_TO_ME | Compiles `JSB w^d(r8)`. |
| IMMEDIATE | `jmp @(r10)+` | Calls the word now. |
| COMPILE_BYTE | I_COMPILE_BYTE | Copies the word's data byte into the buffer. This is the assembler's opcode mechanism, set up by `AC`. |
| PUSH_THIS_WORD | I_PUSH_THIS_WD | Compiles `MOVL @#addr,-(r10)` using mode 0x9F, absolute and deferred. The comment says `#`, but the constant is actually fetched from its cell at run time, so changing the cell changes every user of the constant. |
| PUSH_VOCAB | I_PUSH_VOCAB | Compiles a push of the branch address, then `JSB V_PUSH`. |
| DISP_TO_R11 | I_DISP_TO_R11 | Compiles `MOVAL w^d(r11),-(r10)`. Used for user-table variables. |

### Vocabularies

Vocabularies are called **branches**. Each is a linked list of headers. The branches are:

- KERNEL (`b_kernel`). The SS words are chained into it through `nullhead` (rkernel.mar:227; ss.mar:90-103, 302-303).
- ASSEMBLER.
- STOIC.
- TTIO (ttio.mar:89, 163-168).
- FLOAT, defined in crtl.mar. The crtl `nullhead` sets both of its links to the sentinel (crtl.mar:68), so the FLOAT words are not on the global chain.

The vocabulary stack is searched from the top down to `v_stack_0`. The words that manage it are `ASSEMBLER<`, `STOIC<`, `TTIO<`, `FLOAT<`, `>`, `DEFINITIONS`, `BRANCH`, `V_PUSH`, `CURRENT` and `GLOBAL`.

### Lookup

I_LOOKUP and MATCH are at rkernel.mar:947-1000. Lookup is a **plain linear search** of each branch on the vocabulary stack. MATCH compares the length byte first, then the name with `cmpc3`. There is **no hashing** anywhere. On failure, the original descriptor is pushed back with a false flag, and the compiler then tries the literal converters.

### User table

The user table is defined at rkernel.mar:1936-2046 by the `dlrte` macro. Each entry creates a cell and also a STOIC word with the DISP_TO_R11 attribute, so typing the name pushes the cell's address.

- rkernel.map shows the table at r11-relative offsets FFFF8000..FFFF817C.
- The radix `U_RAD` defaults to 16, so STOIC starts in hex.
- Entries include CHECK, the stack bases, DICT_0, CODE_0, DATA_0, DATA_END, USER_DICTIONARY, USER_CODE, USER_DATA, DATE, USER_INIT, U_IFI/U_IFM, the vectors TYPEADDR/TYOADDR, CTRL_C_HANDLER/FLAG, CMDDESC, and the dispatch slots.

## 5. Memory layout, psects, stack allocation

### Link-time layout

rkernel.opt and rkernel.map describe the image:

- The psects are `KERNEL` (code), `DATINIT` (prototype of the user table and data, plus module data from tyio.mar:62-80 and ss.mar:283-289), `SETUP` (address-fixup instructions generated by `addr_to_ut` and `addr_to_addr`, e.g. tyio.mar:45-59), and `DICTIONARY`.
- extend.mar pads KERNEL, DATINIT and DICTIONARY toward 64 KB using **hard-coded** fill sizes (0x1c00, 0x2200, 0x1000). This leaves room for user code and headers inside the 16-bit displacement windows.
- rkernel.map shows DICTIONARY at 0x1032F bytes, which already exceeds 64 KB. This is harmless only because links are 32-bit offsets.
- The options file contains:
  - `UNIVERSAL=START`.
  - `IOSEGMENT=128,NOP0BUFS`, which puts RMS buffers in P1 so they do not disturb the P0 layout.
  - `CLUSTER=STOIC`.
  - PSECT_ATTR lines.
- kermac.com links `rkernel.exe` and copies it to `head0.exe`, the "header prototype" used for image building. It also links `dkernel.exe` with /DEBUG. kerlink.com links with /NOTRACE.

### Run-time allocation

START is at rkernel.mar:283-436. It uses `isolate_block`, which calls dtinit `get_block`. That routine does `$EXPREG` for n+1 pages, then `$DELTVA` on the first page to make a no-access **moat**. It returns R1 as the first usable address and R2 as the end. Blocks are taken in this order:

1. Parameter stack, 2 pages.
2. Loop stack, 1 page.
3. Float stack, 1 page.
4. Vocabulary stack, 1 page.

   Each stack pointer starts at the top of its block and grows down toward the moat below, so **underflow** (popping too far) runs into the next block up and **overflow** hits the moat and causes an ACCVIO.

5. Compile buffer, 2 pages. A moat page follows it, but there is **no software overflow check**.
6. The FAB/RAB/XAB block for the 8 channels.
7. The data region. The DATINIT prototype is copied in with `movc3`, using the prototype's first word as a 16-bit length. R11 is then computed by **assuming** the data lands at R2+0x200 (rkernel.mar:310). `DATA_INIT` then patches addresses using the SETUP psect.

After that, START does the following:

- Sets `.d` (data end), `user_data` and `.m` (memory end).
- Stores each RAB's address in `channel_list` and runs `setup_fabs`.
- Sets up the dictionary and code extension areas with `$DELTVA` and then `$CRETVA` (rkernel.mar:392-408), and initializes `dict_pntr` and `code_pntr`.
- Opens SYS$INPUT on channel 0 with `wopen_ncr`, runs `outinit`, enables CTRL/C, and opens SYS$OUTPUT on message channel 4 (rkernel.mar:430-432).
- Finally runs `jsb @user_init`. This is the hook through which a saved image or the STOIC-level bootstrap takes over.

Channel roles:

| Channel | Role |
|---|---|
| 0 | Console. ROP is PMT+CVT, so prompts are used and lowercase is converted to uppercase. |
| 1-3 | LOAD nesting levels (U_IFM=3). |
| 4 | Message channel. |
| 5 | Random-access (keyed) channel. |
| 6 | Block I/O channel. |
| 7 | UFO channel for mapping files. |

## 6. Outer interpreter and compiler details

### Input sources

READLINE reads from channel `U_IFI` with GET_STRING.

- On the console, the RMS prompt (`_PROMPT` sets RAB PBF/PSZ) shows the CHECK digit.
- On a LOAD file, the same GET reads the next record.
- At end of file, READLINE runs `;F` (section 9).

### WORD

WORD is at rkernel.mar:1490-1542.

- It skips spaces, tabs and form feeds.
- A token starting with `"` runs to the closing `"` and may contain spaces.
- `%...%` is a comment and is skipped.
- Otherwise a word ends at the first space or tab.
- The word is copied to `word_buffer` as a STOIC string (2-byte count followed by bytes), and a descriptor and true are pushed. False is pushed at end of line.

### Number conversion

- **ILITERAL**: an optional sign (SIGN), then DIGIT repeatedly in radix `U_RAD`. Digits run 0-9 and A-Z, so any radix up to 36 works. A `.` switches to floating point.
- **SLITERAL**: accepts `"abc"` or `'abc`.

Defects in number conversion:

- **DIGIT bug** (rkernel.mar:630-667). Any character above `Z` falls through to the `found_dp` path and is treated as a decimal point. That includes lowercase letters, `[`, `\`, `]`, `^` and `_`. So an undefined word such as `x1`, `abc` or `_` becomes a float literal instead of an error. The status from STRING_TO_FLOAT is not checked, so whatever junk comes back is compiled. The console hides this because ROP CVT uppercases input, but **LOAD files are not uppercased**.
- Integer **overflow is not checked**.
- A float such as `1.5` typed while the radix is hex is handed to OTS$CVT_T_D, which reads it as **decimal**.

### Compile versus execute

There is no STATE variable. Everything is compiled, and the only things that run at compile time are immediate words and the attribute handlers. "Interpretation" just means executing the compile buffer at the end of a line when CHECK is 0.

### Assembler support

- `AC` makes COMPILE_BYTE words for opcodes.
- `CPUSH` and `CPOP` push and pop bytes in the compile buffer.
- `<INLINE>` copies a counted code string inline.
- `B,` and `,` append to the dictionary.

## 7. Error handling and CTRL/C

### Condition handler

`i_cond_handler` is at rkernel.mar:472-484 and is installed in START's frame. It works like this:

1. It saves the PC in `error_pc` and the condition code in `cond_code`.
2. It **overwrites the signal-array PC with the address of `abort`**.
3. It clears the severity bits, turning the condition into a warning.
4. It optionally calls `$UNWIND depadr=1`.
5. It returns SS$_RESIGNAL.

VMS's last-chance handling then prints the message and, because the severity is now a warning, continues at `abort`. I_ABORT resets the registers and SP and jumps to `top_loop`. The effect is that any ACCVIO, arithmetic trap or LIB$SIGNAL turns into a message followed by a return to the prompt.

Other error paths:

- `COMPILE_ERROR` prints the offending word and line, runs `LOAD_RESET`, and aborts.
- `FATAL` prints an inline string.
- `SYSERR` calls LIB$SIGNAL when the status is even, then `halt`s. The halt is unreachable unless LIB$SIGNAL returns.
- `.errstop` (tyio.mar:35-40 and elsewhere) calls LIB$STOP.

### CTRL/C

`controlc.mar` sets up the CTRL/C AST:

- It assigns SYS$COMMAND and does a QIOW SETMODE with IO$M_CTRLCAST. This is skipped when the device is not a terminal, i.e. in batch.
- It uses an `addl2 #4,ap` trick to adjust the argument list.
- The AST calls `here_on_ctrl_c` (rkernel.mar:1727-1735). That routine recovers R11 as `comm_block - ctrl_c_temp`, sets `ctrl_c_flag`, and jsb's through `ctrl_c_handler`.

The default handler is `I_CTRL_C_HNDLR` (rkernel.mar:1737-1748). It walks the saved-FP chain until it finds the frame whose saved FP equals `r_stack_0`, then writes `i_abort` into that frame's saved PC. The frame it patches is the AST routine's own frame, called from the VMS AST dispatcher. When it returns, control goes straight to `abort` **instead of back through the AST dispatcher and $ASTEXIT**.

**Likely bug:** the process may be left marked "user-mode AST active". If so, no further user-mode ASTs are delivered, including a second CTRL/C, timer ASTs from `$SETIMR` and the remote-line ASTs (`rmast`). It may also be why the handler re-enables CTRL/C on every abort. This needs testing.

## 8. I/O

### Terminal I/O through QIO (tyio.mar)

- **`_TYOPEN`** (tyio.mar:87-98) runs `$TRNLOG` on SYS$COMMAND, strips the 4-byte ESC/IFI prefix from process-permanent names, and runs `$ASSIGN`.
- **`outinit`** (tyio.mar:105-129) is the **batch output switch**. It runs `$GETCHN` on that channel:
  - If the device class is not `DC$_TERM`, it deassigns the channel and points `TYOADDR` and `TYPEADDR` at `_rmstyo`/`_rmstype`. Those routines `$PUT` to message channel 4, one record per call, so every `TYO` becomes its own record.
  - Otherwise it uses the QIO routines `_tyo`/`_type`, which do IO$_WRITEVBLK with NOFORMAT.
- **`_tyi`** (132-138) reads one character with NOECHO and NOFILTR.
- **`_type_getline`** (151-160) does a READPROMPT with the terminator mask `rdterm`: every control character plus ESC (142-147). It actually takes four stack arguments (prompt address, prompt length, buffer, length) and pops 16 bytes.
- **`_type_tyi`** (162-172) builds its function code as `...!io$m_noformat - ^X100`. This clears bit 8, which is IO$M_NOFORMAT, from READPROMPT's modifiers. It is a hack for an assembler or macro quirk.
- **`_getmode`/`_setmode`** (198-210) use SENSEMODE and SETMODE with a 12-byte buffer, a VMS V3 workaround.
- **IOSB placement.** Every QIO uses `iosb=ttchan+2(r11)`. If the user-table `ttchan` entry is a longword cell, the 8-byte IOSB overruns into the next entry, which the summary of rkernel.mar identifies as NLEN's low word. `_io_ctrl_c` (190-196) compares that IOSB *longword* with 0x651 (SS$_CONTROLC). That only matches when the transfer-count word is 0.
- **Remote line support** (217-287): `_remstart`, the `rmast` AST echo listener, and `_remtype`. It has defects:
  - At 243, `movl @nstore(r11),naddr(r11)` dereferences, whereas line 227 does not, so the output-name descriptor is wrong.
  - At 264 and 271, `calls #1,g^lib$signal` is made with no argument pushed.
  - At 262, `.entry rmast^m<>` has no comma.
  - The AST relies on R11 still holding STOIC's value.
- **Macro continuations.** Several `$qiow_s` calls continue a line with `-` but leave out the comma (176, 184, 284). This works only because macro arguments may also be separated by spaces.

### RMS (rms.mar)

There are 8 channels. Each is a RAB+FAB pair copied from `proto_rab`, `proto_fab` and a FHC `proto_xab`. Space is computed for two XABs, but the setup loop attaches three (channels 5, 6 and 7). This fits only because of page rounding.

The words fall into these groups:

- **Opening files:** `_OPEN` (FAC=GET), `ROPEN`, `RCREATE`, `WOPEN` (carriage-return carriage control), `RWOPEN`, `WOPEN_NCR`, `WOPEN_FTN`, `APPEND` (ROP=EOF), `CLOSE`, `ERASE`.
- **Record I/O:** `_GET`, `_PUT`.
- **Block I/O:** `_READ`/`_WRITE`, done in 0xFE00-byte chunks.
- **Random I/O:** `RANDOGET`/`RANDOPUT`, keyed by a 4-byte record number taken from the parameter stack.
- **Caller-supplied FAB/RAB:** `FOPEN`, `FCREATE`, `FREAD`, `FWRITE`, `FGET`, `FPUT`, `FCLOSE` take a FRAB address and skip `$CONNECT` when UFO is set.
- **Mapped files:** `MAPOPEN` opens a file with UFO on channel 7 and returns the channel from `FAB$L_STV`, ready for `$CRMPSC`. `MAPCLOSE` runs `$DASSGN`.
- **File attributes:** `FIL_EBK` and `FIL_FFB` (from the XABFHC), `FIL_FSZ`, `FIL_MRS`, `FIL_RFM`, `FIL_RAT`.
- **Prompting:** `_PROMPT`.

**Note:** OPEN always forces FAC=GET. START opens SYS$OUTPUT on channel 4 with OPEN (rkernel.mar:430-432), yet in batch `_rmstype` does `$PUT` on that channel. That works for a process-permanent file, because RMS hands back the PPF's own access, but it is a risk.

## 9. How LOAD works

`LOAD` is at rkernel.mar:1331-1335. Its argument is a file-name string.

1. **NEXTINCH** increments `U_IFI`. If it would pass `U_IFM`=3, it calls FATAL with "Input file table overflow".
2. **OPEN** opens the file on channel `U_IFI`. **PREOPEN** accepts either an ASCIC name or a STOIC string with a 2-byte count, telling them apart by skipping a zero second byte.
3. The next READLINE reads from the file. The file's lines are compiled and executed exactly as console lines would be, including multi-line definitions.
4. At end of file, READLINE runs **`;F`** (SEMIF), which closes the channel and runs **LASTINCH**.
5. **LASTINCH** decrements `U_IFI`. If it would go below 0, which only happens at end of file on the console (^Z, or the end of a batch SYS$INPUT), it executes **`ret`** from START and so **exits STOIC**.
6. **LOAD_RESET**, called by COMPILE_ERROR, runs SEMIF repeatedly until back at the console level.

A LOAD issued inside a file runs only once the current line has finished compiling and executing. Nesting is limited to three files.

## 10. System-service interface (ss.mar)

The `SS name` macro (ss.mar:129-134) makes a header and generates `name_G (r10)`, i.e. `CALLG` with the **parameter stack as the argument list**. The caller pushes the arguments in reverse order and then the count, so the count is on top. On return, `movl r0,(r10)` overwrites the count with the status, and **the arguments are left on the stack** for STOIC code to drop.

The wrapped services are:

- $READEF, $CLREF, $WAITFR
- $TRNLOG
- $ASSIGN, $DASSGN, $QIO, $QIOW, $GETCHN, $GETMSG
- $CREPRC, $DELPRC, $WAKE, $SCHDWK, $EXIT
- $SETPRN, $SETPRI, $GETJPI
- $GETTIM, $NUMTIM, $ASCTIM, $BINTIM, $SETIMR
- $EXPREG, $CRETVA, $DELTVA, $CRMPSC, $UPDSEC, $MGBLSC, $DGBLSC, $SETPRT

The services are at ss.mar:164-264. Constant words are generated by the `IO$`, `JPI$`, `SEC$` and `SS$` macros. ttio.mar adds a TTIO vocabulary of terminal function codes, modifiers and status codes (ttio.mar:118-161).

Oddities in ss.mar:

- **ss.mar:249** is a bare `$SCHDWK` with no `SS` in front. It expands the system macro inline and generates dead code.
- **GETCMD** (ss.mar:291-296) uses the old **CLI callback** `calls #1,@cli$a_utilserv(ap)` with a `$CLIREQDESC CLI$K_GETCMD` descriptor (ss.mar:286). It depends on AP still being the image's original argument list.
- `ss_calls` (298) is the head of the SS branch, and `SYSTEM_SERVICES` pushes it.
- **ss.src** is a listing-style copy, indented with spaces, with a listing page header ("14-MAR-1984 17:40:27 GP2:[SAOSTOIC.KERNEL]SS.MAR;47") embedded inside the `nullhead` macro text. **It will not assemble** and should be treated as documentation only.

crtl.mar provides:

- FLOAT_TO_STRING (FOR$CVT_D_TG) and STRING_TO_FLOAT (OTS$CVT_T_D).
- Math words built on MTH$Dxxx: `.ACOS .ASIN .ATAN .LOG10 .COS .EXP .COSH .SINH .TANH .LOG .SIN .SQRT .TAN`.
- `.POWDD` (OTS$POWDD).
- `SCR.*` screen-package wrappers around LIB$.
- `DUMMY_WORD`.

## 11. Image creation support (STOIC/IMAGE)

The kernel supplies the building blocks. The image builder itself is written in STOIC:

- **SAVE and XLOAD** (rms.mar:654-768). SAVE writes a block-I/O file:
  - Block 1 holds 20 bytes: the DATE quadword, then the lengths of the dictionary, code and data segments.
  - Then come the blocks of `user_dictionary..dict_pntr`, `user_code..code_pntr` and `user_data...d`. The user table lives inside the data segment.
  - XLOAD requires the saved DATE to match the running kernel's `DATE(r11)`, otherwise it calls `date_error`. It does `$EXPREG` when the data runs past `.m`, and preserves `u_ifi` and `vocab_sp`.
  - Lengths pass through `cvtlw` into RSZ/USZ, so **each segment is limited to 64 KB** per transfer.
  - In `_SAVE`, the r2/r3 block-count arithmetic is dead code.
- **head0.exe** (kermac.com) is a copy of the linked kernel, used as the prototype image header and body.
- **MAPOPEN plus the SS memory services** ($CRMPSC, $UPDSEC, $CRETVA, $DELTVA, $EXPREG) let STOIC code map an executable as a section and write the current memory into it.
- **FAB_COUNT, RAB_COUNT, XAB_COUNT** give the control-block sizes.
- **User-table words** describe the layout: DICT_0, CODE_0, DATA_0, DATA_END, USER_DICTIONARY, USER_CODE, USER_DATA, DATE and USER_INIT.
- **USER_INIT** is the startup hook that a saved image redirects to its own application entry.

Everything depends on **deterministic P0 layout**. Saved data contains absolute addresses: stack bases, `channel_list` RAB addresses, `dict_pntr`, `code_pntr` and the absolute operands of PUSH_THIS_WORD. Those addresses are only valid if `$EXPREG` returns the same addresses on every run. That in turn requires the same image size, the same IOSEGMENT/NOP0BUFS settings, and no shareable images or RTL activity that grows P0 before START allocates.

## 12. MACRO primitives by category (rkernel.mar unless noted)

**Initialization and control**
- I_USER_INIT: the default user-init hook.
- I_ABORT: reset registers and stacks and re-enter top_loop.
- DATA_INIT: patch data-area addresses using the SETUP code.
- RESET_REGISTERS: load R7-R11 from the user table.
- I_COMPILE_ERROR: report the bad word and line, then LOAD_RESET and abort.
- FATAL: print an inline string and abort.
- SYSERR: signal if the status on the stack is an error.
- I_DATE_ERROR: report a mismatched save file date.

**Compiler**
- I_COMPILE: compile one word (lookup, then literal).
- DIGIT: convert one digit.
- CEQ: compare a character with a character.
- ICOMPILE: compile an integer or float literal.
- SCOMPILE: compile a string literal.
- SIGN: parse a leading `-`.
- ILITERAL: try an integer or float.
- SLITERAL: try a string.
- I_LITERAL: try both.
- I_EXECUTE: append RSB and run the buffer.
- `:` and `;`: open and close a definition.
- `(:)` and `(;)`: deferred colon and semicolon.
- I_ENTER: build a header.
- CPUSH and CPOP: push or pop a byte in the compile buffer.
- AC: define an assembler opcode word.
- LOOKUP_ATTRIBUTE: address of the current word's attribute byte.
- I_LOOKUP: search the vocabulary stack.
- MATCH: compare a name with an entry.

**Attribute handlers**
- I_JUMP_TO_ME: compile a JSB.
- I_COMPILE_BYTE: emit the stored byte. It actually writes a longword with `movzbl`.
- I_PUSH_THIS_WD: compile `MOVL @#a,-(r10)`.
- I_DISP_TO_R11: compile `MOVAL d(r11),-(r10)`.
- `<INLINE>`: copy inline code.
- I_PUSH_VOCAB: compile a branch push plus V_PUSH.

**Files**
- PREOPEN: normalize a file-name string.
- SETUP_FABS: initialize the channel FABs.
- OPEN, .OPEN, ROPEN, .ROPEN, .RCREATE, WOPEN, .WOPEN, RWOPEN, .RWOPEN, .WOPEN_NCR, .WOPEN_FTN, APPEND, .APPEND: the open variants. Dotted forms return the status; plain forms stop on error.
- CLOSE, ERASE.
- MAPOPEN, MAPCLOSE.
- SAVE, .SAVE, XLOAD, .XLOAD.
- FAB_COUNT, RAB_COUNT, XAB_COUNT.
- FIL_RAT, FIL_EBK, FIL_FFB, FIL_FSZ, FIL_MRS, FIL_RFM: file attributes.
- READ, WRITE: block I/O.
- INCH, NEXTINCH, LASTINCH, LOAD, `;F`, LOAD_RESET: input nesting.
- .FOPEN, .FCREATE, .FCLOSE, .FREAD, .FWRITE, .FGET, .FPUT: FRAB operations.
- GET, .GET, GET_STRING, PUT, .PUT: record I/O.
- RANDOGET, RANDOPUT: keyed I/O.

**Console**
- I_READLINE: read the next line.
- NEWPROMPT: set the prompt.
- REMSTART, REMTYPE: remote line.
- WORD: next token.
- COUNT: string to address and length.
- TYPE, RMSTYPE, QIOTYPE: string output, plus its two back ends.
- MSG: type a STOIC string.
- TYI: read one character.
- TYPE_GETLINE: QIO line read.
- TYPE_TYI: prompted single-character read.
- TYO, RMSTYO, QIOTYO: one-character output and its back ends. TYO ends in a plain `rsb` with no `wterm`, so its code length is not set.
- IO_CTRL_C: did the last I/O end with ^C?
- GETMODE, SETMODE: terminal characteristics.
- CR, SPACE.
- `=`: print a number in U_RAD.

**Time**
- SHOW_TIME: print the time using $ASCTIM.

**CTRL/C**
- I_CTRL_C_HNDLR: the default ^C abort.

**Miscellaneous**
- OCONSTACK: the output conversion stack.
- CONSTANT: define a constant.
- DATA_ADDRESS.
- SYSTEM_SERVICES: head of the SS branch.
- MOAT, P_STACK, L_STACK, F_STACK, V_STACK: stack addresses. F_STACK uses `moval` where the others use `movl`, so it is inconsistent with them.

**Memory**
- `B,` and `,`: append a byte or a longword to the dictionary.
- ISOLATE_BLOCK: allocate a block with a moat.

**Vocabularies**
- BRANCH, V_PUSH, `>`, DEFINITIONS, `ASSEMBLER<`, `STOIC<`, `TTIO<`, `FLOAT<`.

**Other modules**
- ss.mar: the SS words and constants, plus GETCMD.
- ttio.mar: terminal constants.
- crtl.mar: the float and math words.
- Every user-table entry is also a DISP_TO_R11 word.

## 13. GM variant (gm/kernel.mar, gm/ss.mar) versus rkernel.mar

gm/aaareadme.1st (W. Wiitanen, GMR, 15.I.82) describes the GM version as a modification of an earlier SAO kernel. The differences are:

- **Static memory.** Stacks, the compile buffer (400 longwords) and the user table are static, in an `impure` psect with page moats (`p_stack` 400 longwords, and so on). R11 is set with `moval user_table,r11`, and table entries have no -0x8000 bias. The dictionary is a static reserve of 60 pages plus 0x2000 longwords at the end of `impure` (gm/kernel.mar:1545-1547). The code psect is `kernel,nowrt`.
- **Inline headers.** A header is the link, the ASCIC name and the attribute byte, followed immediately by the code. There is no global link, no code length and no separate dictionary psect. R8 points at `dictionary`. Dispatch reads the attribute at `-1(r0)` just before the code address.
  - I_ENTER (gm/kernel.mar:800-808) writes the header directly into the dictionary.
  - `int_colon` (751-760) copies the code right after the header.
  - CONSTANT stores the value inline (1418-1424).
  - MATCH returns the address just past the name (906).
  - Chains end at 0, not 0x7fffffff (884).
- **No float stack.** R7 does not exist. A float is a single longword on the parameter stack.
- **Number input via Fortran RTL routines** (gm/kernel.mar:571-665):
  - `F_iliteral` dispatches on the radix: hex uses FOR$CNV_IN_Z, decimal uses FOR$CNV_IN_I and then FOR$CNV_IN_DEFG for floats, octal uses FOR$CNV_IN_O, and any other radix falls back to the original ILITERAL.
  - The local qualifiers `^X`, `^D` and `^O` select the conversion explicitly.
  - Floats are accepted **only in decimal radix**.
  - CONV_OK pushes only the first longword of the D_float result (619-620), which behaves as an F_float.
  - A local `^X` with a sign is checked against the wrong byte, because R1 has not been advanced past the qualifier (606).
  - These FOR$CNV_IN_* entry points are internal Fortran RTL routines and may not exist in later VMS releases.
- **Empty-stack checks.**
  - `=` prints "Parameter stack empty" instead of underflowing (1306-1312).
  - `>` refuses to pop the last vocabulary (1503-1511).
- **`#F`** formats a float in Fortran G format through FOR$CNV_OUT_G (1351-1377). gm/ss.mar adds `$FAO` and FOR$CNV_OUT_G.
- **No batch switch.** There is no `outinit`, and TYPE jumps straight to `_type`, so output always goes through QIO. The console is opened with OPEN, not WOPEN_NCR.
- **Error handling and CTRL/C.** The condition handler has no `$UNWIND`. `here_on_ctrl_c` addresses `user_table` absolutely (1390-1396) instead of recovering R11. `I_CTRL_C_HNDLR` is the same and has the same AST-exit concern (1398-1409).
- **Spare table space and missing features.** It has FREE_USER_SPACE, UST_TEMP and LKP_DSP_TEMP. It has no SAVE/XLOAD, MAPOPEN, FOPEN family or crtl/TTIO vocabularies.
- **gm/ss.mar** uses the simpler header, `kernel=0`, a plain `rsb`, and `cmddesc` in an impure psect. It links through `prefix_link`, and lacks $SETPRN, the SEC$ list and several IO$/JPI$ items.

In short, GM is a simpler, earlier, single-image design. rkernel adds separate headers, dynamic moat-isolated memory, a float stack, SAVE/XLOAD and image building, and batch support.

## 14. Oddities, bugs and VMS 5.5-2 risks

### Probable bugs and oddities

1. **DIGIT treats anything above 'Z' as a decimal point** (rkernel.mar:630-667). Lowercase undefined words in LOAD files become float literals, and the conversion status is not checked.
2. **The CTRL/C handler skips $ASTEXIT** (rkernel.mar:1737-1748). Later ASTs may be blocked.
3. **The compile buffer has no overflow check.** It is 2 pages, and a long multi-line definition will hit the moat and ACCVIO. That is recoverable, but the partial definition is lost and CHECK may be left non-zero until abort resets it.
4. **IOSB overlap.** `iosb=ttchan+2(r11)` writes 8 bytes over the adjacent user-table cell (tyio.mar:136 and elsewhere). `_io_ctrl_c` compares a longword that includes the byte count (tyio.mar:191).
5. **`_remstart`, `rmast` and `_remtype` defects** (tyio.mar:243, 262, 264, 271): a dereferenced descriptor address, LIB$SIGNAL called with no argument, and an `.entry` with no comma.
6. **`I_COMPILE_BYTE` writes a longword** (`movzbl`). Harmless, since the following bytes are overwritten.
7. **Inconsistent code lengths:** F_STACK uses `moval` and ends in a plain `rsb`, and TYO ends in `rsb` rather than `rsbx`, so their code-length fields are 0. `<INLINE>`-style copying of these words will copy nothing.
8. **Dead and unreferenced code:** the bare `$SCHDWK` (ss.mar:249), `lib$sig_to_ret` declared extern but unused, the `halt` after LIB$SIGNAL in SYSERR, and the dead block arithmetic in `_SAVE`.
9. **The XAB count is computed as 2 but 3 are attached** (rms.mar setup loop).
10. **ss.src cannot be assembled.**
11. **R11 placement is assumed** (rkernel.mar:310): R11 is computed as if the data starts at R2+0x200. If `get_block` ever returned a different layout, every user-table access would be wrong.
12. **PUSH_THIS_WORD compiles absolute addresses**, which ties compiled code to the saved memory layout.

### VMS 5.5-2 risks

- **GETCMD and the CLI callback** (`cli$a_utilserv`, ss.mar:291-296). This was obsolete by V4. Under V5.5 DCL it may return an error or garbage. Replace it with LIB$GET_FOREIGN.
- **$TRNLOG and the ESC/IFI prefix logic** (tyio.mar:89-94, 229-250). $TRNLOG is still supported in V5.5 but obsolete. The prefix stripping still works for process-permanent files. $GETCHN is also obsolete but still present.
- **The condition handler relies on R11 being intact** when the exception dispatcher calls it. It also rewrites the signal PC and resignals as a warning. That works on V5, but **LIB$STOP**, used by `.errstop`, does not allow continuation. Expect the image to exit, or SS$_NOTCONTINUE behaviour, rather than a return to the prompt.
- **The CTRL/C AST path:** both the $ASTEXIT bypass above and the R11 recovery.
- **Batch output:** SYS$OUTPUT is opened FAC=GET and then $PUT to. One record per TYO makes batch logs show one character per line.
- **Deterministic P0 for SAVE/XLOAD and images.** Any change to image size, RTL or shareable-image activation order, or IOSEGMENT moves the `$EXPREG` addresses, and a saved image or XLOAD file then fails or crashes. The DATE check only catches a *rebuilt* kernel, not a layout shift.
- **Psect padding versus the 64 KB windows.** extend.mar's hard-coded sizes do not match the actual psect sizes (DICTIONARY is 0x1032F). Code reached through R8 and data through R11 must stay inside ±32 KB of their bases. A larger user application will silently fail to fit when `cvtlw` truncates the displacements in I_JUMP_TO_ME and I_DISP_TO_R11. There is no range check.
- **`UNIVERSAL=START` in an executable link** is meaningless and may give a linker warning on V5.
- **FOR$CNV_IN_* and FOR$CVT_D_TG** are internal Fortran entry points. They are present in V5.5's FORRTL, but are not a documented interface.

## 15. What to test (on VMS 5.5-2)

1. **CTRL/C twice:** press ^C during a long loop, then do it again. Also start a `$SETIMR` with an AST and see whether it fires after a ^C abort.
2. **Batch run:** submit a job that LOADs a file and uses TYPE, TYO and `=`. Check that output goes through `_rmstype`/`_rmstyo` and how it is laid out in the log.
3. **LOAD nesting:** nest LOADs three deep, then a fourth, which should give "Input file table overflow". Put an error in the innermost file and confirm LOAD_RESET closes everything.
4. **End of file on the console:** ^Z at the prompt should exit cleanly through LASTINCH's `ret`.
5. **SAVE/XLOAD round trip:** in the same image, and then after relinking (expect a date error). Also try it with a different IOSEGMENT or an activated shareable image to see whether P0 layout sensitivity breaks it.
6. **Lowercase undefined word in a LOAD file**, e.g. `foo` or `x1`. Expect it to be accepted silently as a float literal instead of producing a compile error. `_` should behave the same way.
7. **Float literals:** `1.5`, `-2.0E3`, a bad float, and a float in hex radix. Check `FLOAT_TO_STRING` and the MTH$ words.
8. **GETCMD** run from a foreign command (`$ STOIC :== $dev:[dir]rkernel`) with arguments.
9. **ACCVIO recovery:** overflow the stacks (e.g. `DROP` on an empty stack, repeated), run off the end of the compile buffer with a very long definition, and divide by zero. Each should give a message and return to the prompt with CHECK reset.
10. **LIB$STOP path:** OPEN a file that does not exist to trigger `.errstop`, and see whether STOIC exits or returns to the prompt.
11. **The 64 KB windows:** define enough user code to pass 64 KB from `k_start` and see whether calls go to the wrong place.
12. **The terminal words:** `_type_getline`, `TYPE_TYI`, `GETMODE`/`SETMODE`, and `IO_CTRL_C` after a ^C during a read.
