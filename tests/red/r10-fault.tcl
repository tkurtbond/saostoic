# R10-FAULT: a fault inside RED (defect 31). 1/0 on the command line is a
# DIVL by zero, SS$_INTDIV, which the kernel's handler sends to ABORT. Then
# a STOIC line, and ;F at the prompt, as in r6-ship.
red "\[.RED\]R10.TXT"
k ret
cmd "1/0=~~" 4
snap fault
k ret
snap fault-ret
line "DECIMAL 1 2 + = CR" 3
snap stoic
line ";F" 3
snap dcl
line ";F" 3
snap dcl-2
