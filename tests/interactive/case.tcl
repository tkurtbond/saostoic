# Case of console input. The shipped and patched kernels set RAB$M_CVT on
# the console RAB, so RMS (the terminal driver) uppercases every line as it
# is typed and echoed. cmpfix does not: a line reaches STOIC as typed, and
# the dictionary is case-sensitive. ROP of RAB 0 is 44000000 (PMT+CVT)
# with CVT, 40000000 (PMT) without.
stoic
line "CHANNEL_LIST @ @ 4 + @ = CR"
line "decimal 1 2 + = cr"
line "\"Hello, World\" MSG CR"
line "'hello : \"lower\" MSG CR ;"
line "'HELLO : \"UPPER\" MSG CR ;"
line "hello HELLO"
line ";F"
