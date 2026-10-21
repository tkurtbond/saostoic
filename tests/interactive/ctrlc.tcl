# CTRL/C aborts a running loop. The handler (I_CTRL_C_HNDLR) makes the AST
# routine return into I_ABORT, skipping the AST dispatcher's $ASTEXIT, so
# the process stays at AST level (defect 2). DELAY, a $SETIMR timer waited
# for with $WAITFR, uses no AST and still works. A second CTRL/C is echoed
# ("Cancel": ABORT has re-armed the AST) but never delivered; a third finds
# no AST armed and interrupts the image like CTRL/Y. STOP ends it.
stoic
line "BEGIN 0 END" 3
keys "\003" 3
line "1 = CR"
line "HEX 1000 DELAY 4 = CR" 8
line "BEGIN 0 END" 3
keys "\003" 5
keys "\003" 5
line "STOP" 5
