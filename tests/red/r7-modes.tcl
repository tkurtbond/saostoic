# R7-MODES: a search within cut mode, INPUT MODE (the undocumented ,
# command), the conditional change `C and its replies, and ^C during an
# endless iteration. The text is LINE 1 to LINE 10. No file; left with
# GX~H~~.
red
cmd "1T#A10\[ILINE ~#A\027I\r~#A+1T#A\]~~" 5
k ^B kp-
snap cut-open
cmd "SLINE 5~~"
snap cut-search
k kp-
snap cut-closed
k ^Z kp,
snap paste
k ^B
cmd ",~~"
snap input-mode
k F I R S T ret S E C O N D del
snap input-typed
k lf
snap input-done
cmd "B`CLINE~row~~"
snap cond-1
k lf
snap cond-lf
k esc
snap cond-esc
k ret
snap cond-ret
k x
snap cond-x
k " "
snap cond-space
cmd "Z\[IS~-D\]~~" 3
k ^C
snap ^c
k ret
snap ^c-ack
cmd "B2L~~"
snap after-^c
cmd "GX~H~~" 5
snap exit
