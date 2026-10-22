# R-FILL: the editor in FILLRED.EXE, a RED.EXE whose code space FILLAPP
# has filled (tests/big/runfill). Edit and write a file, start RED on it
# again, ESC S to STOIC, run the application, and try a new word.
line "CREATE/DIRECTORY \[.RED\]"
line "DELETE/NOLOG \[.RED\]FILL.TXT;*"
red "\[.RED\]FILL.TXT"
snap new
k ret
cmd "ITHIS FILE WAS WRITTEN BY FILLRED.EXE\rRED WITH ITS CODE SPACE FULL\r~~"
snap inserted
cmd "W~H~~" 5
snap exit
line "TYPE \[.RED\]FILL.TXT"
snap type
red "\[.RED\]FILL.TXT"
snap reopen
k esc S
settle 5
line "HEX \"LAST \" MSG FS_LAST <#> TYPE \"  GROUP \" MSG <#> TYPE CR" 10
snap last
line "'NEW1 : FS_LAST + ;" 5
line "\"NEW1 \" MSG NEW1 <#> TYPE CR" 10
snap new-word
line "REDOUT" 4
line ";F" 3
snap dcl
