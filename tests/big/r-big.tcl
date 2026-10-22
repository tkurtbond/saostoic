# R-BIG: the editor in BIGRED.EXE, a RED.EXE with the 1100-word BIGAPP on
# top (tests/big/run). Edit and write a file, then start RED on it again,
# ESC S to STOIC, and run the application from there.
line "CREATE/DIRECTORY \[.RED\]"
line "DELETE/NOLOG \[.RED\]BIG.TXT;*"
red "\[.RED\]BIG.TXT"
snap new
k ret
cmd "ITHIS FILE WAS WRITTEN BY BIGRED.EXE\rRED WITH AN 1100-WORD APPLICATION ON TOP\r~~"
snap inserted
cmd "W~H~~" 5
snap exit
line "TYPE \[.RED\]BIG.TXT"
snap type
red "\[.RED\]BIG.TXT"
snap reopen
k esc S
settle 5
line "HEX \"TOTAL \" MSG APP_TOTAL <#> TYPE CR" 10
snap total
line "'APP_NEW : APP_TOTAL 1 + ;" 5
line "'APP_NEW WHERE CR APP_NEW <#> TYPE CR" 10
snap new-word
line "REDOUT" 4
line ";F" 3
snap dcl
