# R10B-BUFOFF: as r10-fault, but BUFFER_OFF first, to see whether RED's
# output buffering (obuf), left on by the fault, is what hides the output
# and hangs ;F.
red "\[.RED\]R10.TXT"
k ret
cmd "1/0=~~" 4
snap fault
k ret
snap fault-ret
line "BUFFER_OFF" 3
snap bufoff
line "DECIMAL 1 2 + = CR" 3
snap stoic
line ";F" 3
snap dcl
