# Defect 2 fixed: CTRL/C aborts a running loop three times in a row, and
# STOIC is still usable after each (the AST now ends through $ASTEXIT).
# Then a CTRL/C during DELAY, and one at the prompt. Run with STOIC_EXE set
# to the patched STOIC.EXE.
stoic
line "BEGIN 0 END" 3
keys "\003" 3
line "1 = CR"
line "BEGIN 0 END" 3
keys "\003" 3
line "2 = CR"
line "BEGIN 0 END" 3
keys "\003" 3
line "3 = CR"
line "HEX 4000 DELAY 4 = CR" 2
keys "\003" 8
line "5 = CR"
keys "\003" 3
line "6 = CR"
line ";F" 3
