$!	E2MAKE: make E2.TMP, a STOIC with a STACK and a .VARIABLE, from the
$!	tree's own kernel and HEAD0.  P1 is the tree: SAOSTOIC (the
$!	rebuild) or PATCHED.  tests/image/run then adds a demand-zero
$!	section to a copy's header (WIDEN.STO), so that E2W.TMP runs in a P0
$!	layout that differs from the one E2.TMP was made in, as an exe made
$!	on another system would.
$ SET NOON
$ DEFINE SAO$KERNEL DUA1:[USERS.CLAUDE.WORK.'P1'.KERNEL]
$ DEFINE SAO$STOIC DUA1:[USERS.CLAUDE.WORK.'P1'.STOIC]
$ RUN SAO$KERNEL:RKERNEL.EXE
CR 'SAO$STOIC:RDEF LOAD
'SAO$STOIC:IMAGE LOAD/L
'SAO$STOIC:FLOAT LOAD/L
'SAO$STOIC:OBUF LOAD/L
'SAO$STOIC:VT100 LOAD/L
HEX
"E2: USER_DATA " MSG USER_DATA @ <#> TYPE CR
40 'STK STACK
FLOAT<
2.5 'FV .VARIABLE
>
'E2.TMP IMAGE
;F
$ EXIT 1
