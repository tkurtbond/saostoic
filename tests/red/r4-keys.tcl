# R4-KEYS: the instant commands (arrows, PF1-PF4, ^B, ^Z, ^R, ^U, DELETE),
# re-executing a command with LF, immediate mode (keypad 0 and ENTER),
# control characters typed with BACKSPACE, keypad . (background), and cut
# and paste (keypad - and ,) up to the second-cut prompt. The text is 40
# lines LINE 1 to LINE 40, made with ^W. No file; left with GX~H~~.
red
cmd "1T#A40\[ILINE ~#A\027I\r~#A+1T#A\]~~" 8
snap 40-lines
k ^B
snap ^b
k down down
snap down2
k right right right
snap right3
k up
snap up-mid
k up
snap up-bol
k pf4 pf4
snap pf4x2
k pf3
snap pf3
k pf2
snap pf2
k pf1
snap pf1
k ^Z
snap ^z
k ^B
cmd "5L~~"
snap 5l
k lf
snap lf-repeat
k del
snap del-first
cmd "~~"
snap del-run
cmd "3L"
k ^U
snap ^u
k ^R
snap ^r
k kp.
snap kp.
k kp.
snap kp.-again
k ^B kp0
snap kp0
k N E W ret T E X T del del
snap immediate-typed
k bs Y
snap immediate-^y
k kp0
snap kp0-off
k enter
snap enter
k A B
snap enter-typed
k enter
snap enter-off
k ^B kp-
snap cut-open
k down down
snap cut-moved
k kp-
snap cut-closed
k ^Z kp,
snap paste
k ^B kp-
snap cut-again
k down kp-
snap cut2-closed
k ^B kp-
snap 2nd-cut-options
k Q
snap 2nd-cut-q
cmd "GX~H~~" 5
snap exit
