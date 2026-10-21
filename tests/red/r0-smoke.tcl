# R0-SMOKE: RED starts on a new file in [.WORK.RED] and shows its screen.
# ESC S leaves the editor for STOIC; REDOUT restores the terminal; ;F
# returns to DCL.
line "CREATE/DIRECTORY \[.RED\]"
line "DELETE/NOLOG \[.RED\]R0.TXT;*"
red "\[.RED\]R0.TXT"
snap start
k ret
snap ack
k esc S
settle 5
snap esc-s
line "DECIMAL 2 3 + = CR" 3
snap stoic
line "REDOUT" 4
snap redout
line ";F" 3
snap dcl
