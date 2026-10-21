# R3-BUFFERS: the special buffers (XC XM XG XK XS XD and the B and I
# modifiers), macros (:k, @A, ^G string arguments, ^G@n, ^E, the keypad
# digits), ^W, and ^F. No file; left with GX~H~~. BACKSPACE then a letter
# types that control character into the command line.
red
snap start
cmd "IALPHA ONE\rBETA TWO\rGAMMA THREE\rDELTA FOUR\rEPSILON FIVE\rAAA\r~~"
cmd "B2X3C~~"
snap 2x3c
cmd "XD~~"
snap xd
k ret
cmd "ZX3G~~"
snap x3g
cmd "B2X4M~~"
snap 2x4m
cmd "X4S~~"
snap x4s
cmd "XS~~"
cmd "1X4IM~~"
cmd "3X5BC~~"
cmd "X4S~~"
snap x4-after-im
cmd "X5S~~"
snap x5-after-bc
cmd "XS~~"
cmd "X4K~~"
cmd "XD~~"
snap xd-after-k
k ret
cmd "X0K~~"
snap x0k-current
k ret
cmd "X7SIIHELLO~10I~XS~~"
snap macro7-made
cmd "Z:7~~"
snap :7
k kp7
snap kp7
cmd "X6S~~I@A*2T#C~XS~~"
cmd "21:6#C~~"
snap @a
k X 8 S lf I 2 bs G C bs G 0 bs G 1 bs E lf X S lf lf
snap macro8-made
cmd "X8S~~"
snap x8
cmd "XS~~"
cmd "B:8AAA~BBB~~"
snap :8-args
cmd "X2SIDELTA~XS~~"
cmd "BS"
k bs G
cmd "@2~~"
snap ^g@2
k ret
cmd "Z42\027"
cmd "~~"
snap ^w
cmd "IXYZ"
k ^F
snap ^f-on
k ^F
snap ^f-off
cmd "~~"
snap ^f-run
cmd "GX~H~~" 5
snap exit
