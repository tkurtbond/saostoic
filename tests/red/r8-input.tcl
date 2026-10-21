# R8-INPUT: @K (a key from the keyboard), @N (a number from the keyboard)
# and the = comparison, each inserted with ^W on a line of its own. @K and
# @N prompt when the command line runs, so the key or number comes after it.
# ^R at the end redraws the screen from the buffer.
line "DELETE/NOLOG \[.RED\]R8.TXT;*"
red "\[.RED\]R8.TXT"
k ret
cmd "@K\027I\r~~"
snap at-k-prompt
k A
snap at-k
cmd "@K\027I\r~~"
k bs Y
snap at-k-bs
cmd "@N\027I\r~~"
snap at-n-prompt
k - 1 2 3 ret
snap at-n
cmd "3=3\027I ~4=3\027I\r~~"
snap equals
k ^R
snap refresh
cmd "GX~H~~"
