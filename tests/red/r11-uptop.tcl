# R11-UPTOP: the up arrow on the first line of the buffer (defect 33's
# fix uses C.L-, which stops at the start of the buffer). 5 lines, ^B to
# the start, right twice, then up, and up again.
red "\[.RED\]R11.TXT"
k ret
cmd "1T#A5\[ILINE ~#A\027I\r~#A+1T#A\]~~" 4
k ^B
snap start
k right right
snap right2
k up
snap up-1
k up
snap up-2
cmd "GX~H~~" 5
snap exit
