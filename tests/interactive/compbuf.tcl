# A definition is compiled into the 2-page compile buffer until its ";".
# MID (8 lines of 10 DUP DROP pairs) fits; BIG grows by 10 pairs a line
# until something gives, since nothing checks (defect 4). On the shipped
# STOIC the 17th line writes into the moat page at CF000 (so the buffer is
# CEC00-CEFFF), and STOIC then loops on OPCDEC faults, endlessly. The log
# keeps the first five lines of that; then CTRL/Y and STOP end it.
stoic
line "HEX"
set pairs "DUP DROP DUP DROP DUP DROP DUP DROP DUP DROP DUP DROP DUP DROP DUP DROP DUP DROP DUP DROP"
line "'MID :"
for {set i 0} {$i < 8} {incr i} { line $pairs 1 }
line ";"
line "5 MID = CR"
line "'BIG :"
set broke 0
for {set i 1} {$i <= 30 && !$broke} {incr i} {
  send -- "$pairs\r"
  set broke [await {%SYSTEM-} 2]
}
send_log "\n*** compbuf: line [expr {$i - 1}] of BIG\n"
if {$broke} {
  for {set n 0} {$n < 5} {incr n} { await {[^\n]*\n} 5 }
  log_file
  send "\031"; settle 5
  log_file -a [file join $outdir $name.log]
  send_log "\n*** compbuf: (output not logged) CTRL/Y\n"
  line "STOP" 5
} else {
  line ";"
  line "CHECK @ = 6 BIG = CR"
  line "1 2 + = CR"
  line ";F"
}
