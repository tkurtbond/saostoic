# TYI, TYPE_TYI and IO_CTRL_C, which read by QIO on TTCHAN; the IOSB of
# those QIOs is at TTCHAN+2, which overlaps the low word of NLEN, the next
# user-table cell, 3F as assembled (defect 3). NLEN should be the length
# of the terminal's name at NADDR (from $TRNLOG of SYS$COMMAND), which
# NAMELEN counts up to its colon; the name's unit number varies from
# session to session, so the check prints NLEN @ NAMELEN EQ, -1 when NLEN
# is intact, rather than NLEN itself. GETMODE and SETMODE take the
# address of a 12-byte block: a round trip, and a page width of 132 set and
# restored. (Not CB for its name: that is a hex number.)
stoic
line "HEX"
line "'NAMELEN : NADDR @ BEGIN DUP B@ ASCII : NE IF 1+ REPEAT NADDR @ - 1+ ;"
line "NLEN @ NAMELEN EQ = CR"
send "TYI = CR\r"; settle 2
keys "A"
line "NLEN @ NAMELEN EQ = IO_CTRL_C = CR"
send "\"KEY? \" COUNT TYPE_TYI = CR\r"; settle 2
keys "B"
send "TYI = CR\r"; settle 2
keys "\003" 3
line "IO_CTRL_C = NLEN @ NAMELEN EQ = CR"
line "3 'MODEA ARRAY  3 'MODEB ARRAY"
line "MODEA GETMODE MODEA @ = MODEA 4+ @ = MODEA 8 + @ = CR"
line "MODEA SETMODE MODEB GETMODE MODEB @ = MODEB 4+ @ = MODEB 8 + @ = CR"
line "MODEB @ FFFF AND 840000 OR MODEB ! MODEB SETMODE MODEB GETMODE MODEB @ = CR"
line "MODEA SETMODE MODEB GETMODE MODEB @ = CR"
line ";F"
