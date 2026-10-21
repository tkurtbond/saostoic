# R5-FILES: FI, FO, J, `J, W, O, GX, GW and H, and their errors, on files in
# [.WORK.RED]; DIRECTORY and TYPE show the results.
line "DELETE/NOLOG \[.RED\]R5*.TXT;*,NONE.TXT;*"
line "CREATE \[.RED\]R5A.TXT"
line "FIRST A"
line "SECOND A"
keys "\032"
line "CREATE \[.RED\]R5B.TXT"
line "ONLY B"
keys "\032"
red "\[.RED\]R5A.TXT"
snap open
cmd "ZFI\[.RED\]R5B.TXT~~"
snap fi
cmd "FI\[.RED\]NONE.TXT~~"
snap fi-missing
k ret
cmd "FO\[.RED\]R5C.TXT~~"
snap fo
cmd "BIJ1 ~J~~" 4
snap j
cmd "BI`J ~`J~~" 4
snap `j
cmd "H~~"
snap h-active
k ret
cmd "O\[.RED\]R5B.TXT~~"
snap o-active
k ret
cmd "W~~" 4
snap w
cmd "O\[.RED\]R5B.TXT~~"
snap o
cmd "GX~~"
snap gx
cmd "O\[.RED\]NONE.TXT~~"
snap o-missing
k ret
cmd "GX~~"
cmd "GW\[.RED\]R5D.TXT~~"
snap gw
cmd "INEW D\r~~"
cmd "GW\[.RED\]R5E.TXT~~"
snap gw-active
k ret
cmd "W~H~~" 5
snap exit
line "DIRECTORY/SIZE/DATE \[.RED\]R5*.TXT,NONE.TXT"
snap dir
line "TYPE \[.RED\]R5A.TXT;*,R5C.TXT,R5D.TXT"
snap type
