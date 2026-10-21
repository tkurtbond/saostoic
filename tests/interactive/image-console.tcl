# IMAGE-CONSOLE: an exe made by IMAGE (shipped STOIC, shipped HEAD0) reads
# its console at the terminal, and with SYS$INPUT a file. With a file, both
# the image and the shipped STOIC loop on RMS-W-FAC (the console is opened by
# $CREATE for PUT only), so each is stopped with CTRL/Y after a few seconds.
line "SET DEFAULT DUA1:\[USERS.CLAUDE.WORK\]"
line "DEFINE SAO\$KERNEL DUA1:\[USERS.CLAUDE.WORK.IMG.SHIP\]"
stoic
line "'SQ : DUP * ;"
line "'T9.TMP IMAGE" 5
line ";F"
line "T9 :== \$DUA1:\[USERS.CLAUDE.WORK\]T9.TMP"
# at the terminal
line "T9" 5
line "DECIMAL"
line "7 SQ = CR"
line ";F"
# from a file
line "CREATE T9IN.TMP"
line "DECIMAL"
line "8 SQ = CR"
line ";F"
keys "\032"
line "DIRECTORY/NOHEAD/NOTRAIL T9IN.TMP"
line "DEFINE/USER SYS\$INPUT T9IN.TMP"
send "T9\r"
await {RMS-W-FAC[^\n]*\n.*RMS-W-FAC} 20
keys "\031" 3
line "STOP"
# the same with the shipped STOIC
line "DEFINE/USER SYS\$INPUT T9IN.TMP"
send "ISTOIC\r"
await {RMS-W-FAC[^\n]*\n.*RMS-W-FAC} 20
keys "\031" 3
line "STOP"
# each run created a new, empty T9IN.TMP
line "DIRECTORY/NOHEAD/NOTRAIL/SIZE T9IN.TMP"
line "DELETE/NOLOG T9.TMP;*,T9IN.TMP;*"
line "DEASSIGN SAO\$KERNEL"
line "SET DEFAULT DUA1:\[USERS.CLAUDE\]"
