# RED: the screen editor

This is Phase 4 of `PLAN.md`, run on 2026-10-21 on VAX/VMS V5.5-2H4.

RED is a VT100 screen editor written in STOIC by Roger Hauck (SAO), with a
TECO-like command line. Its manual is `saostoic-text/red/red.mem` (cited
below as "the manual", with its section numbers). `red.cre` loads eleven
modules on top of STOIC.EXE and IMAGEs the result as `RED.EXE`.

**Result:**
- **The shipped `RED.EXE` (1985) does not run on V5.5-2.** It faults with
  ACCVIO before it draws its screen. The cause is an absolute data address
  frozen into the image (defect 30).
- **The rebuilt `RED.EXE` works**, from the sources unchanged (Phase 2).
  Every command in the manual has been run with it, and nearly all behave as
  documented. The differences are listed at the end, with seven new defects
  (30–36).
- **The terminal is restored.** SHOW TERMINAL is the same before and after
  every session that ends normally. It is not restored after the shipped
  exe's fault.

The tests are `tests/red/r0`–`r8`. Each `.tcl` is a key script for
`tools/red-drive`. The `.raw` file is the session as the VAX sent it, and
the `.scr` file shows the screen at each `snap`, rendered by
`tools/red-screens`. A reference like "r2 `tc-end`" names a test and a
snapshot in it. All runs below use the rebuilt exe,
`DUA1:[USERS.CLAUDE.WORK.SAOSTOIC.RED]RED.EXE`, except r6, which runs the
shipped one.

## How the tests drive RED

`tools/red-drive` logs in over telnet, with the pty in raw mode, so that
RETURN reaches RED as CR and LF as LF. It sets the terminal to a 24-line,
80-column VT100 and runs each script in turn. It records SHOW TERMINAL
before and after each script. If a script does not leave the session at
DCL, red-drive sends CTRL/Y and STOP.

Scripts use these procs:
- `cmd "text"` types a command line, with `~` sent as LF;
- `k key...` presses named keys (`kp-`, `pf1`, `^B`, …);
- `snap name` marks the log once the output has gone quiet.

`tools/red-screens` replays the log through pyte, a VT100 emulator, and
prints each marked screen, with a line under it that marks reverse, bold,
underline and blink video.

Two harness points matter for reading the scripts:
- **An error message locks the keyboard until RETURN** (manual 1.3), so
  scripts press `k ret` after every error they expect. Without it, the next
  command is swallowed and the rest of the script goes wrong.
- **`^W` in a `cmd` string is written `\027`.** A literal `^W` would be
  typed as `^` and `W`, which runs the `^` command.

## Structure

The modules, in `red.cre`'s load order, are:

| Module | Contents |
|---|---|
| `err` | Creates the `RED<` branch and the error messages. |
| `dyna` | Dynasts: the text buffers X0–X9 and the command buffers K0, K1…, each with a gap. |
| `e` | Constants and state, including the 26 number registers and the user stack. |
| `window` | Window tracking and redraw (SETSCREEN, DISP). |
| `edv` | The VT100 display, the divider line, the prompts, ERR.MSG, and E.SET_CHARS/E.RESET_CHARS. |
| `eb` | Cursor and edit primitives (C.M+, C.L+, C.UP_ARROW, C.D+, C.I+). |
| `command` | Kill, searches, delete and insert. |
| `immed` | Immediate-mode insert and delete. |
| `cli` | The command-line interpreter. |
| `kbd` | Keys, cut and paste, and the main loop. |
| `red` | The entry words RED, RED_NOSP, REDCPU and REDOUT. |

`stoic/obuf` (output buffering) and `stoic/vt100` (escape sequences) come
from STOIC.EXE.

### Dynasts: the buffers and the gap

RED keeps all its text in "dynasts" (dynamic strings), defined in `dyna`.

- **The pointer table.** It starts at `D.START`, which `.D@ 'D.START
  CONSTANT` freezes at the data pointer when dyna is loaded
  (`dyna:121-126`).
  - It holds K0, the command buffers: 8 longwords.
  - Then X0, the ten text buffers (`#BUFS` = 0A): 4 longwords each.
  - Then `D.STOP`.
  - D.INIT points every entry at the current end of data, so every buffer
    starts empty (`dyna:266-270`).
- **Three strings per buffer.** A buffer's four pointers are TOPOTOP,
  BOTOTOP, TOPOBOT and BOTOBOT (`dyna:228-231`). Consecutive pairs mark
  three strings:
  - the text before the cursor, from TOPOTOP to BOTOTOP;
  - the gap, from BOTOTOP to TOPOBOT;
  - the text after the cursor, from TOPOBOT to BOTOBOT.
- **Moving the cursor.** MOVE_UP and MOVE_DOWN (`dyna:247-262`) move the
  cursor by copying bytes across the gap. Inserting adds bytes at the end
  of the first string (ABE, ASE), and deleting removes them (RBE).
- **Growing the gap.** When a gap is full, D.EXPAND1 (`dyna:147-161`)
  grows it by at least 800 (hex) bytes:
  - it extends the data region with `.D+!` if needed;
  - it moves every later dynast up, pointer pair by pointer pair
    (D.EXPAND2).
  - So the buffers sit end to end in the data region, in table order.
- **XD.** XD shows these pointers as LOC, TOP, GAP and BOT for each buffer
  (r3 `xd`).

`D.START` is another address frozen at load time, like `O.BUFSTRT`
(defect 30). The shipped RED faults in obuf before it would reach the
dynasts, so it is not known whether `D.START` would fault too.

### Startup

1. DCL runs `RED.EXE` with the command tail `RED file`.
2. rdef's DEF_INIT compiles the tail. `RED` is IMMEDIATE, so it runs as it
   is compiled. It reads the file name with WORD and calls `.RED`
   (`red/red:28-44`). `.RED` then:
   - pushes `RED<`;
   - calls E.SET_CHARS, which saves the terminal characteristics and sets
     RED's own;
   - calls BUFFER_ON, then INIT_VT100;
   - opens the file;
   - runs KBD, the main loop (`kbd:498-511`).
3. A missing file gives "New file." (r1 `new`). Any other open failure
   prints the RMS message in the text area, then "File OPEN failure."
   (LOAD_ERROR, `red:18-26`).

### Leaving RED

- **H** leaves RED and STOIC (r1 `exit`). The terminal is reset, and the
  session is back at DCL.
- **ESC S** leaves the main loop for the STOIC prompt (`kbd:330`,
  r0 `esc-s`). The RED screen stays, and the STOIC prompt `0>` appears in
  the command area. STOIC works there: `DECIMAL 2 3 + = CR` prints ` 5`
  (r0 `stoic`).
  - `REDOUT` resets the terminal (it sends ESC c) and restores the
    characteristics (r0 `redout`).
  - `;F` then returns to DCL with the terminal as it was before.
  - The manual does not mention ESC S or REDOUT.

### The screen

- **Row 1** shows the file name in reverse video and double width, then
  `X` and the buffer number. With no file open, the name field is blank.
  - When a command line ends with an argument, its value is shown in
    reverse video at the left of row 1.
  - After a command such as `[...]` the field may show a stray `~`.
- **Rows 2–18** are the text window. The cursor is on row 10, with TF lines
  (default 8) on each side.
- **Row 19** is the divider line, drawn in the line-drawing set. Error
  messages appear in blinking video at its left end, and so do the prompts
  "CUT MODE", "INPUT MODE", "IMMEDIATE MODE", "Type a key:" and
  "Type a number:".
- **Rows 20–24** are the command area, a scroll region. LF echoes as `~`.
  Control characters are shown as the letter in bold.

`nTF` changes the window (r2 `3tf`):
- the text area shrinks to n lines on each side;
- the divider moves up, to row 2n+3;
- the command area grows to fill the rest of the screen.

## Commands

A command line runs when two LFs (`~~`) end it (manual 4.1). Numbers are
decimal. The manual says "the current input radix", but `TI`, the command
that would set it, is not implemented.

The tables cover every entry in CLI.DISP1 (`cli:1590-1638`) and its
second-level tables (F, G, T, X, `` ` ``, and `@` in arguments), plus the
instant keys of `kbd`.

The Status column uses these terms:
- **works**: it does what the manual says;
- **differs**: it works, but not as the manual says;
- **undocumented**: the manual does not mention it;
- **broken**: it does not work.

### Arguments and operators (manual 4.4)

| Command | Status | Observed | Test |
|---|---|---|---|
| no argument; `-` alone | works | 1 and −1 | r2 `minus` |
| `+ - * /` | works | strictly left to right: `5+5*3+3` is 33. `7/2` is 3, `-7/2` is −3, `10-12` is −2 | r2 `expr33`, `div`, `div-neg`, `sub` |
| `& ! %` | works | `12&9` is 8, `6!9` is 15, `5%3` is 6 | r2 `and`, `or`, `xor` |
| `'` (NOT) | differs | **postfix**: `0'` is −1, and `'0` gives "Invalid command.". The manual lists `'` as an operator without saying where it goes | r2 `not` |
| `< > =` | works | operand 1 is on the left: `1<2` is −1, `1>2` is 0, `3=3` is −1, `4=3` is 0, `1+1=1` is 0 | r2 `lt`, `gt`, `expr0`; r8 `equals` |
| `"c` | works | `"A` is 65 | r2 `quote-a` |
| `?` | works | the error flag: −1 after a failed search that `E` suppressed | r2 `e-?` |
| `#x`, `nT#x` | works | number registers A–Z. The manual's example, 50 lines X … XXXXX, works | r2 `registers`, `manual-registers` |
| `@C @L @T` | works | character number, line number (both from 0), and the code of the character at the cursor | r2 `@c`, `@l`, `@t` |
| `@K` | works, but see defect 34 (fixed in the patched build) | prompts "Type a key:"; `A` gives 65, and BACKSPACE Y gives 25 (^Y) | r8 `at-k`, `at-k-bs`, `refresh` |
| `@N` | works, but see defect 34 (fixed in the patched build) | prompts "Type a number:"; `-123` RETURN gives −123 | r8 `at-n`, `refresh` |
| `@A` | works | a macro's argument: `21:6` with `@A*2` in X6 gives 42 | r3 `@a` |
| `nTP`, `@P`, `@Q` | works | push; pop; top without popping: `10TP@P` gives 10 | r2 `tp`, `@q` |

### Moving and deleting (manual 5.2, 5.3)

| Command | Status | Observed | Test |
|---|---|---|---|
| `nM` | works | moves n characters | r2 `3m` |
| `nL` | works | `nL` moves to the start of the nth line on; `0L` to the start of this one; `-2L` back two | r1 `2l`, r2 `0l`, `-2l` |
| `B`, `Z` | works | start and end of the buffer | r1 `b`, r2 `z` |
| `nD` | works | deletes n characters. `-D` at the start of a line joins it to the previous one | r1 `-3d`, r2 `d`, `-d` |
| `nK` | works | kills n lines forward; `-K` backward; `0K` from the cursor back to the start of the line | r2 `k`, `-k`, `0k` |

### Inserting (manual 5.1)

| Command | Status | Observed | Test |
|---|---|---|---|
| `Itext~` | works | inserts the text | r1 `inserted` |
| `nI` | works | inserts the character whose code is n: `66I` inserts B | r2 `66i` |
| TAB, SPACE | works | insert a tab or a space, then the text that follows | r2 `tab-insert`, `space-insert` |
| `nTC` | works | replaces the character at the cursor. At the end of the buffer it gives "TC invalid at end of text buffer." | r2 `tc`, `tc-end` |
| `^W` | undocumented | inserts the argument as a decimal number: `Z42^W` inserts 42 (`cli:1094-1099`) | r3 `^w`, r8 |
| `,` | undocumented | INPUT MODE (`cli:1198`). It runs only when the line ends with `~~`. RETURN starts a new line, DELETE rubs out, and LF ends the mode | r7 `input-mode`, `input-typed`, `input-done` |

### Searching and changing (manual 5.4–5.6)

| Command | Status | Observed | Test |
|---|---|---|---|
| `Sstr~` | works | finds the string. A failure gives "String not found." | r1 `sfour`, r2 `s-fail` |
| `Cold~new~` | works | changes the next occurrence | r2 `c` |
| `Unew~` | works | after a C, replaces the string it found: ALEPH became AYIN | r2 `u` |
| `^xyz~` | works | replaces as many characters as the string has | r2 `caret` |
| `` `Cold~new~ `` | differs | shows the reply menu. LF skips. ESC **or RETURN** replaces. SPACE exits. Any other key rings the bell and waits. The manual (5.6) gives only ESC and LF, and says "Other: exit to normal command mode". The menu on the screen matches the code (`cli:1217-1220`) | r7 `cond-1` … `cond-space` |
| `E` | works | suppresses the next search error | r2 `e-?` |

### Iteration, labels and macros (manual 4.3, 5.9, 5.10)

| Command | Status | Observed | Test |
|---|---|---|---|
| `n[...]` | works | `3[IX~]` inserts XXX. `[CE~e~]` changes every E to the end of the buffer, then stops with "String not found.", as the manual says | r2 `iterate-3`, `iterate-change` |
| `\x` and `n;x` | works | the factorial macro with labels gives 120. A branch to a missing label gives "No such label." | r2 `factorial`, `no-label` |
| `a:n` | works | runs buffer n with argument a. Keypad 1–9 run X1–X9 at once | r3 `:7`, `kp7` |
| `n^G`, `^Gn`, `^G@n` | works | string arguments: the manual's `:8AAA~BBB~~` example works, and `S^G@2` searches for X2's contents | r3 `:8-args`, `^g@2` |
| `n^E` | works | returns from a macro, or ends the command line | r2 `^e` |

### Buffers (manual 5.8)

| Command | Status | Observed | Test |
|---|---|---|---|
| `nXCb`, `nXMb` | works | copy or move n lines into buffer b | r3 `2x3c`, `2x4m` |
| `XGb` | works | inserts buffer b | r3 `x3g` |
| `XSb` | works | switches buffers; row 1 shows the number | r3 `x4s` |
| `XKb` | works | empties buffer b. `X0K` while in X0 gives "Invalid argument." | r3 `xd-after-k`, `x0k-current` |
| `XD` | works | a table of LOC, TOP, GAP, BOT and IBUF for K0, K1 and X0–X9, then "Type carriage return to continue." | r3 `xd` |
| `I`, `B` modifiers | works | `XCbI`, `XMbI`: insert, not replace; `B`: a byte count, not lines | r3 `x4-after-im`, `x5-after-bc` |

### Files (manual 5.7)

These work only in X0. All of them work as the manual says. The tests check
the results with DIRECTORY and TYPE (r5 `dir`, `type`).

| Command | Status | Observed | Test |
|---|---|---|---|
| `Ofile~` | works | reads a file. With a file active it gives "Active file present.". A missing file gives "New file.", not an error; a later GX then creates nothing | r5 `o`, `o-active`, `o-missing` |
| `W` | works | writes a new version and empties the buffer | r5 `w` |
| `J` | works | writes a new version and keeps the buffer | r5 `j` |
| `` `J `` | works | deletes the latest version, then writes the buffer under the same version number (`cli:1369-1386`). R5A.TXT;2 has the `` `J `` text and a creation time after the J | r5 `` `j ``, `dir` |
| `GX` | works | discards the file and the buffer, writing nothing | r5 `gx` |
| `GWfile~` | works | names a new file, only when none is active; W then creates it | r5 `gw`, `gw-active` |
| `FIfile~` | works | inserts a file at the cursor. A missing file prints `%RMS-E-FNF, file not found` in the text area, then "File OPEN failure." (`cli:842-848`, deliberately) | r5 `fi`, `fi-missing` |
| `FOfile~` | works | writes the whole buffer to a new file | r5 `fo` |
| `H` | works | leaves RED; with a file active it gives "Active file present." | r5 `h-active`, r1 `exit` |

### Other commands (manual 5.11, 1.2)

| Command | Status | Observed | Test |
|---|---|---|---|
| `nTF` | differs | sets the window. TF alone gives 8. `11TF` gives 10: out-of-range values are clamped to 1–10 (`cli:817-823`). The manual (1.2) calls them illegal | r2 `3tf`, `11tf`, `tf` |
| `T`TAB | works | toggles tabs between a bright `I` and a real tab | r2 `tab-toggle` |
| `TB` | works | rings the bell | r2 `tb` |
| `TI` | broken | "Command not implemented." (`cli:825-827`, commented "set radix"). The manual does not list it | r2 `ti` |
| LF, CR | works | do nothing inside a line. An LF as the first key runs the previous line again | r4 `lf-repeat` |
| any other | works | "Invalid command." (`Q` was tried) | r2 `invalid` |

### Instant keys (manual 2.0, 3.0, 6.0)

| Key | Status | Observed | Test |
|---|---|---|---|
| ↓ → ← | works | next line; one character on and back | r4 `down2`, `right3` |
| ↑ | differs | from mid-line it goes to the start of the **current** line, and only from the start of a line to the previous one. The manual says "beginning of previous line". C.UP_ARROW steps back one byte, then searches back for a CR (`eb:65-72`) | r4 `up-mid`, `up-bol` |
| PF4, PF3 | works | word right and left | r4 `pf4x2`, `pf3` |
| PF2, PF1 | works | bottom and top of the window, then re-centre | r4 `pf2`, `pf1` |
| ^B, ^Z | works | start and end of the buffer | r4 `^b`, `^z` |
| DELETE | works | as the first key, it drops the last character of the previous line and keeps the rest | r4 `del-first`, `del-run` |
| ^U, ^R | works | clear the command line; redraw the screen | r4 `^u`, `^r` |
| ^F | works | edits the command line as a buffer (row 1 shows K0); a second ^F restores it | r3 `^f-on`, `^f-off`, `^f-run` |
| ^C | works | stops a runaway `[...]`: VMS echoes "Cancel", the next command in the loop ends with "Command aborted." (`cli:1645`), and RETURN redraws the screen. A ^C typed when no command is running makes RED clear its output buffer and redraw (`kbd:484-487`). The text is intact either way. Which one r7 sees depends on whether its 9-second loop has ended | r9 `^c`, `ack`, `^c-after`; r7 `^c`, `after-^c` |
| kp0 | works | toggles IMMEDIATE MODE: typed keys go into the text, RETURN breaks the line, DELETE rubs out, and BACKSPACE+letter enters a control character | r4 `kp0` … `kp0-off` |
| ENTER | undocumented | toggles immediate mode too (`kbd:290`) | r4 `enter` … `enter-off` |
| kp. | works | toggles a light or dark background (ESC[?5h, ESC[?5l) | r4 `kp.`, `kp.-again` |
| kp- | works | opens and closes CUT MODE. The text between is moved into X9. In cut mode, `S` and `-S` searches move the far end (manual 6.1), as do the arrows, PF keys, ^B and ^Z | r4 `cut-open` … `cut-closed`; r7 `cut-search` |
| kp, | works | pastes X9 at the cursor | r4 `paste`, r7 `paste` |
| kp- with an unpasted cut | works | "2nd cut without paste; Type a key:", with RETURN to replace, A to append and Q to abort | r4 `2nd-cut-options`, `2nd-cut-q` |
| kp1–kp9 | works | run macro n | r3 `kp7` |
| BACKSPACE+letter | works | enters a control character, shown bold | r3, r4 `immediate-^y` |
| ESC S | undocumented | back to STOIC (see "Leaving RED") | r0 `esc-s` |

## Defects found

New defects are numbered on from `PLAN.md`'s checklist.

**30. The shipped `RED.EXE` faults at startup on V5.5-2** (r6):
- The fault is `%SYSTEM-W-ACCVIO, … virtual address=0007B173`.
- The traceback is B! ← TYO ← ESC ← ANSI_VT100 ← INIT_VT100 ← .RED ← RED.
- The cause is in `stoic/obuf`. `.D@ 'O.BUFSTRT CONSTANT` and
  `'O.BUFEND CONSTANT` freeze absolute addresses in the data region when
  obuf is loaded.
  - The data region is `$EXPREG`'d at startup, and its address depends on
    the P0 layout (Phase 3, defect 11).
  - In the shipped STOIC.EXE, `O.BUFSTRT` is 7B173: the 1985 address, and
    the fault address. `USER_DATA` is now CFA00 (checked with
    `tools/stoic-run`).
  - In the rebuilt exe, `O.BUFSTRT` is 80F73, inside its data at 80200.
- It is the same class as defect 22 (BRANCH). Shipped STOIC itself survives
  only because nothing turns on buffering (O.FLAG) at the console.
  RED.EXE was IMAGEd on top of the shipped STOIC, so it inherits the stale
  address.

**31. After the fault in 30, RED leaves the terminal changed, and `;F` does
not return** (r6 `dcl`, `dcl-2`):
- E.SET_CHARS ran before the fault, and nothing restores it. After STOP,
  SHOW TERMINAL shows `Device_Type: Unknown`, `No ANSI_CRT` and `No Wrap`.
- At the `0>` prompt, `;F` (twice) gives no output and no DCL prompt.
  red-drive had to use CTRL/Y and STOP.
- A likely reason, untested: BUFFER_ON has already set O.FLAG, so every
  TYO goes on faulting.
- Recovery: `SET TERMINAL/DEVICE=VT100` (or `/INQUIRE`).
- The hang comes from 30, not from the fault. After a fault inside the
  rebuilt RED (`1/0`, r10-fault), `;F` works, but the terminal is still
  changed, and CR at the prompt is buffered until BUFFER_OFF (r10b-bufoff).
- Fixed in the patched build: while RED runs, ABORT is RED_ABORT, which
  restores the terminal (as on exit, but without the screen-clearing
  reset) and then jumps to the old ABORT. After `1/0`, the message and
  traceback print, STOIC lines echo, `;F` returns to DCL, and the terminal
  is VT100 again (`tests/red/patched/r10-fault`).

**32. `KBD` sends a malformed escape sequence:**
- `6 RESET_MODE` (`kbd:500`) sends `ESC [ ? ^F l`. `vt100` defines
  RESET_MODE twice. The second definition (`vt100:153`) takes a character
  and replaces the first (`vt100:63`), which took a number.
- A VT100 acts on the ^F and ignores the rest. pyte prints the `l`, so
  `tools/red-screens` removes the sequence.
- It is harmless on a real terminal. The intent was probably `ASCII 6`
  (`?6l`, origin mode off), which `.RED` already sends.
- Fixed in the patched build (Phase 6, Batch G): `ASCII 6 RESET_MODE`.

**33. The up arrow differs from the manual:**
- From the middle of a line it goes to the start of the same line.
- The manual says the previous line.
- Fixed in the patched build: the up arrow goes to the start of the
  previous line from anywhere in the line (`tests/red/patched/r4-keys`
  `up-mid`, `up-bol`), and stays on line 1 at the top (`r11-uptop`).

**34. After `@K` or `@N`, inserted text is drawn on the divider line** (r8):
- C.@K and C.@N redraw the divider (DRAW_DIVIDER) and leave the terminal
  cursor at its end, but RED's notion of the cursor is unchanged.
- The next insertion echoes there: `65` appears after the divider.
- The text window scrolls a blank line instead.
- The buffer is right: ^R shows 65, 25 and −123 on their lines (r8
  `refresh`).
- Fixed in the patched build: C.@K and C.@N put the cursor back with
  S.CUP after redrawing the divider (`tests/red/patched/r8-input`).

**35. `` `C `` replies differ from the manual:**
- RETURN replaces, like ESC.
- SPACE exits.
- Any other key rings the bell and keeps waiting.
- The manual says any other key exits. The prompt RED draws matches the
  code.

**36. Smaller differences between the manual and the code** (all of them,
with corrections, are in [`errata.md`](errata.md)):
- `TF` clamps out-of-range values instead of rejecting them.
- `TI` (set radix) is in the table but not implemented, so arguments are
  always decimal, although the manual speaks of "the current input radix".
- `'` is postfix, which the manual doesn't say.
- `,` (INPUT MODE), `^W`, keypad ENTER and ESC S are not documented.

## Not covered

- RED_NOSP (SPACE and TAB not commands) and REDCPU (CPU time on the
  divider) were not run.
- Returning to RED from STOIC after ESC S was not tried.
- The INFOTON-200 version (manual appendix A) is not in the tree.
  `ORANGE.CRE` is missing.
- Files with fixed-length or stream records, and files too big to map
  (F.MAP_LOAD's fallback to F.LOAD, `cli:302-322`), were not tested.
