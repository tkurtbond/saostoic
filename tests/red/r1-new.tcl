# R1-NEW: a new file: "New file." (acknowledged with RETURN), I with lines
# ended by RETURN, B, nL, S, -nD, -L, then W~H~~ writes the file and returns
# to DCL, and TYPE shows what was written.
line "DELETE/NOLOG \[.RED\]R1.TXT;*"
red "\[.RED\]R1.TXT"
snap new
k ret
cmd "IALPHA ONE\rBETA TWO\rGAMMA THREE\rDELTA FOUR\rEPSILON FIVE\r~~"
snap inserted
cmd "B~~"
snap b
cmd "2L~~"
snap 2l
cmd "SFOUR~~"
snap sfour
cmd "-3D~~"
snap -3d
cmd "-L~~"
snap -l
cmd "W~H~~" 5
snap exit
line "TYPE \[.RED\]R1.TXT"
snap type
