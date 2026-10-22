# R12-BOUNDS: the RED commands that compare, at their edges: < and > in
# expressions (C.< C.>), registers A and Z and the characters beside them
# (C.T#, CLI.RLOAD, CONVERT_TO_UPPER), the digits 0 and 9 (INCLUDE_DIGIT,
# C.@N), TF at 0, 1, 10 and 11 (C.TF), buffers 0, 9 and 10 (C.XDISP, C.:),
# ^G@ beside the digits (CLI.INPUT_BUFFER), [ nested 24, 25 and 33 deep, a
# search 24 deep, and a loop after 30 lines that left [ open (C.[, defect
# 49), a macro calling itself (the macro stack), M, D and K at and past the
# ends of the text (C.M+ C.M- C.D+ C.D-), and PF3/PF4 across ! and TAB (the
# BLANK tests in I.WORDLEFT/RIGHT). No file; left with GX~H~~. H alone
# leaves RED, so clear empties X0 from X1 (XK refuses the current buffer).
proc clear {} { cmd "X1S~~"; cmd "X0K~~"; cmd "X0S~~" }
red
cmd "3<5~~"
snap lt-3-5
cmd "5<3~~"
snap lt-5-3
cmd "3<3~~"
snap lt-3-3
cmd "-1<0~~"
snap lt-m1-0
cmd "3>5~~"
snap gt-3-5
cmd "5>3~~"
snap gt-5-3
cmd "3>3~~"
snap gt-3-3
cmd "0>-1~~"
snap gt-0-m1
cmd "09+90~~"
snap digits
cmd "7T#A9T#Z#A*10+#Z~~"
snap regs-a-z
cmd "4t#a#a~~"
snap lower-a
cmd "1T#@~~"
snap reg-at
k ret
cmd "1T#\[~~"
snap reg-bracket
k ret
cmd "1T#`~~"
snap reg-grave
k ret
cmd "1T#{~~"
snap reg-brace
k ret
cmd "#\[~~"
snap use-bracket
k ret
cmd "@NT#A#A~~"
snap @n-prompt
k - 0 9 ret
snap @n-m09
cmd "@NT#A#A~~"
k 9 /
snap @n-slash
k ret
cmd "@NT#A#A~~"
k 0 :
snap @n-colon
k ret
cmd "1T#A40\[ILINE ~#A\027I\r~#A+1T#A\]~~" 8
cmd "B20L~~"
snap 40-lines
cmd "0TF~~"
snap tf0
cmd "1TF~~"
snap tf1
cmd "10TF~~"
snap tf10
cmd "11TF~~"
snap tf11
cmd "TF~~"
snap tf-default
clear
cmd "0XD~~"
snap 0xd
k ret
cmd "9XD~~"
snap 9xd
k ret
cmd "10XD~~"
snap 10xd
k ret
cmd "-1XD~~"
snap m1xd
k ret
cmd ":9~~"
snap :9-empty
cmd ":10~~"
snap :10
k ret
cmd "X5SII~:5~XS~~"
clear
cmd ":5~~" 5
snap :5-recursive
k ret
clear
cmd "I"
k bs G
cmd "@:~~"
snap ^g@colon
k ret
clear
cmd "I"
k bs G
cmd "@/~~"
snap ^g@slash
k ret
cmd "0T#A[string repeat 1\[ 24]#A+1T#A[string repeat \] 24]#A~~" 5
snap nest24
cmd "0T#A[string repeat 1\[ 25]#A+1T#A[string repeat \] 25]#A~~" 5
snap nest25
k ret
cmd "0T#A[string repeat 1\[ 33]#A+1T#A[string repeat \] 33]#A~~" 5
snap nest33
k ret
clear
cmd "IXYZ~B[string repeat 1\[ 24]SXYZ~B[string repeat \] 24]~~" 5
snap nest24-search
for {set i 0} {$i < 30} {incr i} { cmd "1\[~~" }
cmd "0T#A2\[#A+1T#A\]#A~~"
snap open30
clear
cmd "IABC~B3M~~"
snap m3
cmd "B4M~~"
snap m4
k ret
cmd "Z-3M~~"
snap m-3
cmd "Z-4M~~"
snap m-4
k ret
cmd "B4D~~"
snap d4
k ret
clear
cmd "IABC~Z-4D~~"
snap d-4
k ret
clear
cmd "IABC~Z-3D~~"
snap d-3
clear
cmd "IAB!CD EF\tGH ~B~~"
k pf4
snap pf4-1
k pf4
snap pf4-2
k pf4
snap pf4-3
k pf4
snap pf4-4
k pf4
snap pf4-5
k pf3
snap pf3-1
k pf3
snap pf3-2
k pf3
snap pf3-3
k pf3
snap pf3-4
k pf3
snap pf3-5
cmd "GX~H~~" 5
snap exit
