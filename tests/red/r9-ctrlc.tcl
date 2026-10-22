# R9-CTRLC: ^C while a [...] iteration is running, and ^C after one ends.
# The text is LINE 1 to LINE 10. Z[IS~-D] runs 65536 passes, about 9 s;
# the ^C comes 3 s in. RED shows "Command aborted." (cli:1645) and waits
# for RETURN. A ^C typed after the loop (r7's case) gets a redraw instead
# (kbd:484). No file; left with GX~H~~.
red
cmd "1T#A10\[ILINE ~#A\027I\r~#A+1T#A\]~~" 5
send -- "Z\[IS\n-D\]\n\n"
after 3000
k ^C
settle 3
snap ^c
k ret
snap ack
cmd "Z5000\[IS~-D\]~~" 2
k ^C
settle 3
snap ^c-after
cmd "GX~H~~" 5
