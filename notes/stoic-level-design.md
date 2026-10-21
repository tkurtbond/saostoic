# SAO STOIC: the STOIC-language layer, IMAGE, FLOAT and RED

Source tree: `/home/tkb/Repos/STOIC/saostoic-text/`. Paths below are relative to that tree. Kernel line numbers refer to `kernel/rkernel.mar` unless another file is named.

## 1. Build pipeline

The top-level driver is `stobuild.com`:

1. `@ASSIGN` defines the logicals `SAO$KERNEL`, `SAO$STOIC` and `SAO$RED` from the current directory. It also defines the symbol `STOIC :== $SAO$STOIC:STOIC` (assign.com).
2. `SET DEF SAO$KERNEL`. If P1 is `MAC`, it runs `@KERMAC`, which assembles dtinit, crtl, controlc, ss, rms, tyio, ttio, rkernel and extend (kernel/kermac.com).
3. `@KERLINK` does `link/map=rkernel.map/notrace rkernel/options` and then `copy rkernel.exe head0.exe` (kernel/kerlink.com).
4. `SET DEF SAO$STOIC`, `@STOIC.CRE`.
5. `SET DEF SAO$RED`, `@RED.CRE`.

stobuild.com:22 mentions `ORANGE.CRE`, the INFOTON variant. That file is not in the tree.

`kernel/rkernel.opt` (lines 1-8) does four things:
- It gives the KERNEL, DATINIT and DICTIONARY psects the attributes `WRT,SHR,PAGE`.
- It puts the objects in their own cluster, `STOIC`.
- It sets `IOSEGMENT=128,NOP0BUFS`.
- It sets `UNIVERSAL=START`.

The separate cluster keeps foreign code (the RTL) out of STOIC's ISDs (aaareadme.doc:115-134).

The image layers are built like this:

- `stoic/stoic.cre` runs `$ RUN SAO$KERNEL:RKERNEL`, then `'RDEF LOAD`, then `'IMAGE LOAD/L`, `'FLOAT LOAD/L`, `'OBUF LOAD/L` and `'VT100 LOAD/L`. It writes the result with `'STOIC.EXE IMAGE` and ends with `;F`. The output is `STOIC.EXE`, which is RKERNEL plus everything just loaded.
- `red/red.cre` runs that `STOIC.EXE` and does `LOAD/L` of ERR DYNA E WINDOW EDV EB COMMAND IMMED CLI KBD RED. It then runs `'RED.EXE IMAGE ;F`.
- `red/hirez.cre` is the same except that it loads CLIHIREZ instead of CLI and writes `REDHIREZ.EXE`. CLIHIREZ differs from CLI only in the default and limit for the TF window: 14/1C hex instead of 8/0A (cli:819-820). It targets a 48-line Selanar HiREZ.

The layering works because IMAGE always rebuilds from `SAO$KERNEL:HEAD0.EXE`. The kernel's image header is the same for every layer, and only the contents of the three resident sections change.

`install.com` copies `SAO$RED:RED.EXE` to `SYS$SYSTEM:STOIC.EXE` and installs it with `STOIC/WRITE/SHARE/HEAD`. That is the old pre-V5 INSTALL syntax. It also contradicts the V4 advice in red4.doc and image.txt to drop `/SHARE`.

aaareadme.doc gives the user-facing symbols:
- `RED :== $SAO$RED:RED RED`
- `STOIC :== $SAO$RED:RED` (the editor image doubles as the plain STOIC)
- `CALC :== $SAO$RED:RED FLODEF`

## 2. STOIC language quirks (as implemented)

- **Names go before the defining word.** You write `'NAME : body ;`. Both `'X` and `"..."` are string literals. SLITERAL compiles them (765-788), and at run time they push the address of a word-counted string. `:` and the other defining words take that address from the stack.
- **Definitions take effect when the line executes.** Each input line is compiled into COMP_BUF and then run through I_EXECUTE. `int_colon` does its work at execute time (815-861). As a result, inside a redefinition the name still refers to the *previous* definition. stoic/obuf depends on this: its new `TYPE` calls the old `TYPE` (obuf:44-123). It is also why red4.doc's suggested `'IMAGE : ... IMAGE ;` works as a wrapper and does not recurse.
- `;` ends a colon definition. `;F` closes the current LOAD file (1384), and at console level it leaves STOIC. `%` starts a comment that runs to the end of the line.
- **The default radix is hexadecimal** (`dlrte U_RAD,16`, 2017). `DECIMAL` and `HEX` are in rdef:1302-1424. `=` prints the top of the stack in the current radix with a leading space (1655).
- A number containing `.` is a D_floating literal. It compiles to `MOVD #lit,-(R7)` (DIGIT 630-660, ICOMPILE 682-701).
- **Registers:**
  - P = R10, the parameter stack (`(P)+` pops, `-(P)` pushes).
  - L = R9, the loop/L-stack.
  - FS = R7, the float stack.
  - SP, the return stack.
  - R8, the code base.
  - R11, the user table.
- **There is an in-line VAX assembler.** You switch to it with `ASSEMBLER<`. The operand order is the same as MACRO, not postfix: `MOVL (P)+ R0`. Mode constants are defined with `AC` (rdef:29-76), and displacement forms such as `B^(P)`, `@B^(P)`, `B^(FS)`, `S^` and `W^` are at rdef:102-143.
- **Vocabularies are called branches.** `'X< BRANCH` creates one (rdef:925-944). `X<` pushes it on the vocabulary stack, `>` pops it, and `DEFINITIONS` sets CURRENT. The kernel provides ASSEMBLER<, STOIC<, TTIO< and FLOAT< (1863-1892). rdef adds IORB< (rdef:948).
- **Comparisons are the reverse of the manual.** The operands are A = top of stack and B = next. stoic/stoic.mem:567 says GT gives "-1 if B greater than A". The code does `CMPL (P)+,(P)+`, which compares A against B, so GT is true when **A > B**. Every use in the sources agrees with the code, not the manual:
  - MAX and MIN (rdef:647-658)
  - `#A` (rdef:1169)
  - `DUP 20 GT_IF % control char?` (window:75)
  - `TERMINATORS @ 1 GE IF` (kbd K.LF)
  - `DDUP GT_IF % n>m?` (vt100 SCROLL)
  - `FFFF GE_IF` (MOVE_BYTES)

  This needs confirming on the real machine. See section 8.
- **Arithmetic:** `-` computes B-A and `/` computes B/A. `MOD` and `/MOD` use EDIV with a zero high longword, so the results are wrong for negative dividends: the dividend is effectively treated as unsigned 64-bit. `/MOD` leaves the quotient under the remainder, with the remainder on top.
- **Control structures:**
  - `IF … ELSE … THEN` (rdef:520-553).
  - `BEGIN … END` repeats until the flag is true.
  - `BEGIN … IF … REPEAT` is a while loop.
  - `DO … LOOP` and `+LOOP`, with I, J, K, I', LAST_I and EXIT (rdef:670-747).
  - `n ( … )` is a counted loop with I running from 0 to n-1.
  - CHECK counts nesting, so a line with an unclosed structure is held until it closes.

## 3. rdef by category (stoic/rdef, 1544 lines)

| Lines | Category | Words |
|---|---|---|
| 29-143 | Assembler support | AC mode/opcode constants, B^(P), @B^(P), B^(FS), B^(SP), S^, B^, W^ |
| 151-203 | Stack | DROP DUP 2DROP DDUP SWAP OVER 2OVER +ROT -ROT (DROP) UNDER FLIP UNDROP 2UNDROP |
| 208-279 | Arithmetic and logic | + - * / MOD /MOD MINUS NOT AND OR XOR, shifts, 2* 4* 2/ 4/ (218-223) |
| 285-390 | Memory | @ @@ B@ W@ ? ! <- B<- W<- EXCHANGE MOVE D@ D! D<- W! 1+! +! -! 0<- -1<- 1<- |
| 401-457 | Compiler support | +CHECK CODE_COUNT ,COMPILE CMARK TARGET ARCHER INLINE< >INLINE |
| 466-516 | Tests | ITEFT test primitives, EQ NE GT LT GE LE, the combined *_IF forms |
| 520-567 | Control | IF THEN ELSE BEGIN END REPEAT DGE; `()` gives a word's address |
| 595-622 | Dispatch | DISPATCH, plus in-line redefinitions of hot words for speed |
| 626-658 | L-stack, misc | MARK NOTE RECALL RESTORE MIN MAX ABS |
| 670-751 | Loops | DO LOOP +LOOP EXIT I J K I' LAST_I `(` `)` MOVE_BYTES |
| 786-882 | VMS services | INCLUDE GETJPI EXPREG DELTVA CRETVA MAP GETTIM ASCTIM BINTIM DELAY EVENT_FLAG |
| 886-944 | Data region | .D@ MEMORY .D+! ,D B,D VARIABLE ARRAY SVARIABLE BRANCH |
| 948-1089 | RMS (IORB<) | FRAB, FAB/RAB field accessors, F-file words, FMAP, IORB fields |
| 1091-1144 | I/O and system | TRNLOG ASSIGN QIOW QIO STACK BPUSH |
| 1148-1196 | Number output | ASCII <# #> #PUT #A # #S <#> I= |
| 1205-1295 | Strings | MOVE_WORDS SEARCH_STRING .STREQ STAB .STRAP STRAP MOVE_STRING (SUBSTRING) DUPI+B@ |
| 1302-1424 | Utilities | CRET LFEED BLANK BUF RDL +SPACES BCOUNT BMSG LIST LIST_NCR DECIMAL HEX SHOW_WORD INVENTORY SYSMSG WHERE WHAT |
| 1427-1440 | Errors | ERROR_TRACE, installed into ABORT |
| 1442-1512 | Session | LAST_WORD BELL LOAD/L EXEC MODULE FORGET SET_REVISION REVISION |
| 1516-1542 | Startup | DEF_INIT, stored into USER_INIT |

**Startup hook.** DEF_INIT (rdef:1516-1535) calls the kernel word GETCMD (kernel/ss.mar:286-291, a CLI$K_GETCMD request). GETCMD copies the DCL command-line tail into LINE_BUFFER. If the tail is non-empty, DEF_INIT compiles and executes it as one STOIC line. If it is empty, it prints "Welcome to STOIC". Lines 1539-1542 store DEF_INIT's code address into USER_INIT. The kernel calls it with `jsb @user_init(r11)` (435) before entering top_loop. The whole foreign-command mechanism (`RED file`, `CALC expr`) rests on this.

**rdefold compared with rdef.** rdef adds:
- `@B^(P)` (111-114)
- `2* 4* 2/ 4/` (218-223)
- `I=` (1193-1196)
- `DUPI+B@` (1291-1295)
- `+SPACES` (1317-1322)

It also moves `BUF SVARIABLE` earlier and fixes some typos. Otherwise the two files are the same. `stoic/dupi` is a stand-alone test of `@B^(P)` and `DUPI+B@`: `'TEST : COUNT ( DUPI+B@ = CR ) ;`.

**Other STOIC-directory modules:**
- `obuf` adds output buffering. O.BUFSIZE is decimal 1000 (obuf:35) and must be at least 52 less than the kernel's MAXBUF (aaareadme.doc:41-50). It redefines TYO, CR, SPACE, SPACES, TYPE, MSG, TYI and GETLINE, and adds FLUSH, BUFFER_ON and BUFFER_OFF (44-123). The input words flush first so that prompts appear.
- `vt100` (365 lines) provides:
  - ANSI primitives: ESC, ESC[, SC, RC, RI, STBM, SGR, ED, SET_MODE, EL, CUP and DHLT, plus the attribute words BOLD, UNDERSCORE, REVERSE and STEADY (27-111);
  - a cached STBM and SCROLL (116-136);
  - TF=8 and WINDOW_SIZE=2*TF+1 (138-144);
  - FILE_NAME and BUFFER#;
  - `[[ ]]`, which counts stack entries (192-193);
  - INIT_VT100 and RESTORE_VT100, which save terminal state through a `VT100_BITS` logical name (283-356).
- `rem` (REM3) is a dial-out terminal program built on IORB/QIO, with DIAL, GO and HANGUP. `aipsplot` is a Versatec plotter interface. Neither is loaded by stoic.cre.

## 4. IMAGE in detail (stoic/image, 263 lines, J. Mark 1982)

IMAGE writes a new executable that has the same image header as the kernel, but whose three resident sections contain the *current* memory contents. STOIC has no linker step for user code. IMAGE "freezes" the running dictionary into an .EXE file.

### Data structures

- HEAD0_FRAB and IMAGE_FRAB are the two files (image:11-12). FRANDOGET and FRANDOPUT do keyed RMS GET/PUT with the virtual block number as the key (16-26). INIT_FRABS sets KSZ=4 and RAC=KEY (28-33).
- `#WRITES` is 10 hex (37), the size of the write schedule. HEAD and BLOCKBUF are each 80 hex longwords, one 512-byte block (42-43).
- The ISD accessors are offsets into the header (56-60):
  - ISD.SIZE (+0, word)
  - PAGCNT (+2)
  - VPN (+4, low 3 bytes)
  - FLAGS (+8)
  - VBN (+0C)
- SET_NOWRT clears ISD$M_WRT (08) and ISD$M_CRF (02) (64-66).

### Algorithm

1. `.IMAGE` (193-213) does the following in order:
   - opens `SAO$KERNEL:HEAD0.EXE` for GET;
   - reads VBN 1 into HEAD;
   - runs SCHEDULE_WRITES;
   - FCREATEs the output with PUT|BIO;
   - saves DATE, calls SET_REVISION and runs WRITE_IMAGE;
   - restores DATE and closes both files.
2. UPDATE_POINTERS (91-95) stores the current data length in USER_DATA. It rounds DICT_PNTR and CODE_PNTR up to a page boundary and saves them in USER_DICTIONARY and USER_CODE. The new image therefore starts with the dictionary at its present extent.
3. SCHEDULE_WRITES (152-163):
   - schedules the (modified) header as block 1;
   - walks the ISDs starting at `HEAD DUP W@ +`, i.e. at the offset held in IHD$W_SIZE;
   - treats an ISD of size 10 hex (a private section with a VBN) as resident, and passes it to DO_RESIDENT;
   - stops at an ISD of size 0.
4. DO_RESIDENT (139-150) calls CHECK_ISD for the data, the dictionary and the code in turn. If an ISD matches none of them, its blocks are scheduled as a copy from HEAD0.
5. CHECK_ISD (124-137) matches an ISD by `VPN = start/200`. On a match it:
   - schedules a write from live memory (for data it uses USER_DATA, not the prototype DATA_0);
   - calls SET_NOWRT on that ISD. This is unconditional (129), even for "writable" images;
   - calls FIX_COUNT to set the page count to the new length;
   - calls FIX_DZRO;
   - increments FIND_COUNT.
6. FIX_DZRO (79-84) steps 10 hex bytes forward to the demand-zero ISD that follows. It adds the grown page count to that ISD's VPN and reduces its PAGCNT, so the expansion tail shrinks by exactly what the section grew. If WRT_FLAG is 0 it also sets the DZRO ISD no-write.
7. SCHEDULE_WRITE and SCHEDULE_COPY (97-114) record schedule entries. A positive source is a memory address. A negative source is a HEAD0 block number to copy.
8. WRITE_IMAGE (179-191) aborts unless FIND_COUNT is exactly 3. It then performs the scheduled writes in VBN order.

The public words are:
- `'IMAGE : 0 .IMAGE ;` (215)
- `'IMAGE_WRT : -1 .IMAGE ;` (216)
- the V4 redefinition at 217-221, which prints a notice and calls IMAGE_WRT. Because definitions take effect at execute time, the redefinition does not recurse.

NOCREF (225-238) clears copy-on-reference. DISPLAY_ISD and SHOW (242-259) dump the ISDs in HEAD, which helps with debugging.

### Why the kernel tolerates this

At startup the kernel copies the DATINIT prototype into private storage and loads R11 with the user table. It then uses `$DELTVA`/`$CRETVA` to replace the no-write expansion tails beyond USER_DICTIONARY and USER_CODE with fresh writable VA (333-405). A frozen image can therefore keep growing its dictionary and code even though the image file marks those sections read-only. This is the "kernel linked read/write, created images read-only" arrangement in aaareadme.doc:115-134.

### The V4 BADISD problem

red4.doc says that VMS V4 removed a linker/image-activator behaviour that STOIC depended on, so images produced by IMAGE failed at activation with `%SYSTEM-F-BADISD`. The fix (red4.doc, image.txt) is to build *writable, non-shareable* images (`'IMAGE : IMAGE_WRT ;`) and install them `/OPEN/HEAD` only, without /SHARE. The leading hypothesis is that V4 rejects a section that is shareable but has its ISD changed to non-writable while the base is still WRT+SHR (rkernel.opt). This is not proven.

Note that IMAGE_WRT still runs the unconditional SET_NOWRT at image:129 on the resident section. Only the DZRO tail keeps WRT. So "writable" in practice means "the expansion tail is writable".

### Fragility under VMS 5.5-2

1. **Single-block header.** Only VBN 1 of HEAD0 is read and the ISD walk stays inside that buffer. V5 headers can span several blocks (IHD$B_HDRBLKCNT), and there is no code for that case. Check `$ ANALYZE/IMAGE RKERNEL.EXE` for "header block count = 1".
2. **ISD layout assumptions.** The code assumes:
   - private ISDs are exactly 10 hex bytes;
   - the 10-hex size identifies a resident section;
   - a DZRO ISD immediately follows each resident one (FIX_DZRO's +10);
   - 512-byte pages (VAX only, which is fine on VAX).

   A linker that emits fixup sections, global ISDs or reordered ISDs breaks these assumptions. The FIND_COUNT=3 check is the only guard.
3. **HEAD0 must be byte-identical to the running kernel**, linked `/NOTRACE`. kerlink.com enforces this by copying, but any relink without the copy produces silently wrong images. The logical `SAO$KERNEL` is hard-coded.
4. **Psect attributes.** The combination of `WRT,SHR` with the ISD rewriting is what tripped V4. 5.5-2 could have more checks.
5. **File attributes.** The output is created BIO via FCREATE with no explicit FIXED/512 record attributes, so the file attributes depend on FCREATE's defaults. Inspect them with `DIR/FULL`.
6. **INSTALL.** install.com uses `/SHARE` and the pre-V5 INSTALL syntax. Under V5 use `INSTALL ADD SYS$SYSTEM:STOIC/OPEN/HEADER_RESIDENT` (no /SHARED).
7. **No integrity check.** Nothing verifies that the written image activates. Rebuilding from an IMAGE-built image (STOIC.EXE builds RED.EXE) works only because HEAD0's header and VPNs still describe the same layout.

## 5. The float package

**stoic/float** (240 lines, the one that is built) works on VAX D_floating values held on the FS stack (R7):
- It opens the FLOAT< and ASSEMBLER< branches and sets the radix to hex (lines 4-8).
- Conversion: `I->F` and `F->I` (16-17).
- Stack words: `.DUP .OVER .DDUP .DROP .2DROP .SWAP .+ROT .-ROT .UNDER .FLIP` (21-48).
- Arithmetic:
  - `.+` and `.-` (53-54);
  - `.*` and `./` (56-62); `./` is `DIVD2 (FS)+,(FS)`, i.e. next divided by top, like `/`;
  - `.MINUS`;
  - `.^`, an alias for the kernel `.POWDD` (66).
- `.EFIX`, the comparisons `.NEZ` through `.LT`, and the `.xx_IF` forms (82-110).
- Output:
  - `F->S` and `.=` use the kernel FLOAT_TO_STRING, i.e. FOR$CVT_D_TG with 16 digits (crtl.mar:97-130), so `.=` prints in Fortran G format;
  - the custom pictured-output words `.<# .#> .E#> .# >.< .<#>`, which default to 4 decimals;
  - `F=` and `E=` for Fortran-style fixed and exponent formats (209-218).
- Variables: `.@ .! .? .VARIABLE` (222-230).
- `'FLODEF : FLOAT< DECIMAL ; IMMEDIATE` (236) is defined in the *main* branch so that the CALC symbol can name it.

The transcendental functions are kernel words, not FLOAT words. In crtl.mar the macro `math1` generates `.ACOS .ASIN .ATAN .LOG10 .COS .EXP .COSH .SINH .TANH .LOG .SIN .SQRT .TAN`, each calling `MTH$D<name>`, and the macro `math2` generates `.POWDD` (OTS$POWDD). Input conversion is STRING_TO_FLOAT, which uses OTS$CVT_T_D.

**gm/float.sto** (W. Wiitanen, GMR 1981) is an unrelated single-precision F_floating package. It works on the P stack, with words such as `+. -. *. /. MINUS FIX FLOAT =I =.` and the `.GT.` compare forms. It needs `#F` from the GM kernel (gm/kernel.mar) and is not part of the SAO build.

## 6. RED architecture

RED is a screen editor written entirely in STOIC and loaded on top of STOIC.EXE. Its key bindings are in the style of a VT100 keypad, and its command line is TECO-like. All of its words live in the `RED<` branch, which err creates (`'RED< BRANCH`, `RED< DEFINITIONS`, `'REDMODULE MODULE`, err:21-23).

### Modules (in load order)

| Module | Role |
|---|---|
| err | Creates the RED< branch and the module marker. Error messages are string addresses (`"msg" 2*`). |
| dyna | "Dynasts", dynamic strings in the data region after D.START. Ten text buffers X0…X9 (#BUFS=0A); each has four pointers: top-start, top-end (the cursor), bottom-start, bottom-end. This is a **buffer gap** design. There are also keyboard buffers K0… (8 longwords). CURBUF and CURKBUF select the current ones (120-128). D.EXPAND moves later dynasts up. The primitives are ABE RBE ABB RBB ASB RLB ASE, TOPOTOP BOTOTOP TOPOBOT BOTOBOT, TOP_COUNT and BOT_COUNT. MOVE_UP and MOVE_DOWN move text across the gap. SBF, SFCR, SRCR and SBB are byte searches. |
| e | Constants and state: GAPSIZE=800, MAXLINE=100, USEP=1D, IMODE (immediate/insert mode), TAB_MODE, CUT_FLAG, REC_SEP and SPACE_FLAG. NUM_REGS holds 26 numeric registers A-Z. There are terminal-characteristic arrays (0C bytes), C.STRING, C.COMMAND, MSTACK (the macro stack), USER_STACK, E.INIT and B.INIT. |
| window | Tracks the window top and bottom. E.TYO displays control characters. Also SETSCREEN, DISP and REVISE_WINDOW. (etype is an alternate E.TYO with bold control characters and the mark bit underscored. red.cre does not load it.) |
| edv | VT100 display driver: line drawing, on-screen insert and delete (D.I+ D.D- …), the command pane and divider line, ERR.MSG, and E.SET_CHARS/E.RESET_CHARS, which use GETMODE/SETMODE to put the terminal in raw mode and restore it (edv:529-543). |
| eb | Edit-buffer primitives (E.M+ …) and their CLI forms C.M+, C.L+, C.UP_ARROW, C.D+ and C.I+. |
| command | E.MATCH, TF_LL, word left and right, E.B, E.W, C.K, the searches C.+S, C.-S and C..S, and C..D and C..I. |
| immed | Single-keystroke insert and delete in immediate mode (I.INSERT, I.DELETE). |
| cli | The command-line interpreter (below). |
| kbd | Keyboard and escape-sequence decoding, and the main loop. |
| red | Entry words. |

### Screen and terminal

The screen is split into a text window and a command pane. The window is centred on the cursor, with TF lines above it (vt100:138-144). Scrolling uses the VT100 scroll region (STBM and SCROLL in vt100). E.SET_CHARS saves the terminal characteristics and sets the ones RED needs. RESTORE_VT100 and E.RESET_CHARS undo this on exit, using the `VT100_BITS` logical name to remember the original state (vt100:283-356). All output goes through obuf, and each command cycle ends with a FLUSH.

### Command language (red/cli)

CLI.GNB reads the next character from the current K buffer. Commands take numeric prefixes, numeric registers, and @-delimited arguments: C.@A, C.@C, C.@K, C.@L, C.@N, C.@P, C.@Q and C.@T. CLI.DISP1 (cli:1589-1640) dispatches on these characters:

`B C D E F G H I J K L M O S T U W X Z [ \ ] ^ , : ; < = > + - * / & ! % ? ` ' ^E ^G TAB ^W SPACE`

The main loop is CLI (1665). Other pieces:
- INPUT_TEXT (1125) reads inserted text.
- C.COMMA (1198) starts the "comma" input mode described in aaareadme.doc:76-88.
- `[ ]` is iteration, with a loop limit of 20 hex.
- File input: F.MAP_LOAD tries to map the file with `$CRMPSC` and falls back to the record-by-record F.LOAD (cli:~430-455). F.DUMP writes records back out, and F.OPEN_FILE opens the file.

### Keyboard (red/kbd)

- FOUND_ESCO handles the application keypad:
  - PF1-PF4;
  - Enter and 0 toggle IMODE;
  - `-` toggles the mark;
  - `,` pastes from buffer 9 (the cut buffer);
  - `.` toggles the background;
  - the digit keys run macros.
- FOUND_ESC[ handles the arrow keys. `ESC S` returns to STOIC.
- K.LF runs the accumulated command line when a terminator arrives. The terminator is LF, echoed as `~`.
- Other control keys:
  - K.DEL deletes;
  - ^R refreshes the screen;
  - ^U kills the line;
  - ^F toggles the K buffer;
  - ^B and ^Z go to the beginning and end;
  - backspace quotes a control character.
- KBD_COM and KBD_IMM are the command-mode and immediate-mode handlers. In immediate mode, GET_KEY calls INPUT_TEXT at end of line.
- KEY_LOOP and KBD (498-511) disable ^C abort, turn on output buffering, and loop for ever.

## 7. Entry points

**`RED filename`.**
1. DCL runs RED.EXE (`$SAO$RED:RED RED`) with the command tail `RED filename`.
2. DEF_INIT gets the tail through GETCMD and compiles it as a STOIC line.
3. `RED` is IMMEDIATE (`'RED : SPACE_FLAG -1<- WORD .RED ; IMMEDIATE`, red:53-56). During compilation it reads the next token, `filename`, with WORD, and calls `.RED`.
4. `.RED` (red:28-44) does the following in order:
   - selects RED<;
   - calls E.SET_CHARS and BUFFER_ON;
   - calls INIT_VT100 and sets up the screen;
   - calls E.INIT;
   - opens the file with F.OPEN_FILE. If the open fails with LOAD_ERROR, status 18292 hex (file not found), it prints "New file".
   - calls DISP and BUFFER_OFF, then LOAD_RESET (so that the rest of the line is discarded), then KBD.

Related entry words are RED_NOSP, REDCPU and REDOUT.

**`CALC 2. .SQRT 2. ./ .ASIN 4. .* .= CR ;F`** (aaareadme.doc:24).
1. The tail is `FLODEF 2. .SQRT …`. FLODEF is IMMEDIATE, so during compilation of that same line it pushes FLOAT< and switches to DECIMAL. That is why `.SQRT`, `./` and `.=` resolve.
2. The expression computes asin(sqrt(2)/2)*4 = pi.
3. `.=` prints pi in FOR$CVT_D_TG format with 16 digits, approximately `3.141592653589793`. The exact field layout is uncertain.
4. `;F` then exits to DCL.

Plain `STOIC` with no tail prints "Welcome to STOIC" and enters the interactive top loop.

## 8. Candidate test programs

Run these at the interactive STOIC prompt (`$ RUN STOIC.EXE` or the STOIC symbol). The radix is hex unless the test says otherwise. Each line is independent.

| # | Input | Expected | Purpose |
|---|---|---|---|
| 1 | `3 4 + =` | 7 | Basic arithmetic and `=` |
| 2 | `10 =` | 10 | Hex radix round trip |
| 3 | `DECIMAL 10 = HEX 10 =` | 10 10 | Radix words (the input radix changes too) |
| 4 | `7 3 - =` | 4 | `-` is B-A |
| 5 | `6 2 / =` | 3 | `/` is B/A |
| 6 | `7 3 MOD =` | 1 | MOD |
| 7 | `7 3 /MOD = =` | 1 2 | Remainder on top |
| 8 | `-7 3 MOD =` | garbage (not -1 or 2) | EDIV unsigned-high bug |
| 9 | `5 3 GT =` and `3 5 GT =` | 0 and -1 per code (the manual implies the opposite) | Settles the comparison sense |
| 10 | `3 5 MAX = 3 5 MIN =` | 5 3 | MAX/MIN |
| 11 | `-5 ABS =` | 5 | ABS |
| 12 | `'SQ : DUP * ; 9 SQ =` | 51 | Colon definitions (hex 51 = 81) |
| 13 | `'SQ : SQ 1+ ; 9 SQ =` | 52 | A redefinition refers to the previous definition |
| 14 | `5 ( I = )` | 0 1 2 3 4 | Count loop |
| 15 | `1 IF "yes" MSG ELSE "no" MSG THEN` | yes | IF/ELSE |
| 16 | `0 BEGIN 1+ DUP 5 EQ END =` | 5 | BEGIN…END |
| 17 | `0 'V VARIABLE 2A V ! V @ =` | 2A | Variables (check the VARIABLE argument convention in rdef:925) |
| 18 | `"abc" MSG` | abc | String literal |
| 19 | `'SQ WHERE`, `INVENTORY`, `REVISION` | address, word list, date of the image build | Dictionary utilities; REVISION checks SET_REVISION from IMAGE |
| 20 | `"abc" TEST` after `'DUPI LOAD` | 61 62 63, one per line | dupi test of @B^(P) |
| 21 | `FLOAT< 2. .SQRT .=` | about 1.414213562373095 | Float literal plus MTH$DSQRT |
| 22 | `FLOAT< 7 I->F .=` | 7.000… | I->F |
| 23 | `FLOAT< 2. 3. .^ .=` | 8.0 (9.0 would mean the operands are reversed) | Operand order of POWDD |
| 24 | `FLOAT< 1. 4. ./ .=` | 0.25 | `./` is next/top |
| 25 | `$ CALC 2. .SQRT 2. ./ .ASIN 4. .* .= CR ;F` | about 3.141592653589793 | Foreign-command path |
| 26 | `'IMAGE LOAD/L`, then `'T.EXE IMAGE`, then `$ RUN T.EXE`, then `'SQ WHERE` | SQ survives the round trip | IMAGE on VMS 5.5-2 |
| 27 | After `'IMAGE LOAD/L`, run `SHOW` | ISD list of HEAD0 | Inspect the header and check the single-block assumption |
| 28 | `$ RED TEST.TXT` (new file) | "New file", a clean screen; ESC S returns | RED start-up and terminal restore |
| 29 | In RED: type text, then the command `B` and LF, then `5L` and LF | Cursor moves to the top, then down 5 lines | CLI dispatch and the K.LF terminator |
| 30 | In RED: cut a marked region with the keypad and paste with `,` | Text duplicated | Buffer 9 and the gap primitives |

Tests 9, 23 and 26 are the most informative. They settle questions that the source alone cannot answer: the comparison sense, the POWDD operand order, and whether IMAGE still produces activatable images under 5.5-2.
