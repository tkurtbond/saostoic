$!	SETUP-WORK: make the scratch copy of STOIC, once.  Run by
$!	tools/vax-do in [.WORK]: copies [.SAOSTOIC...] to [.WORK.SAOSTOIC...]
$!	and creates [.WORK.TESTS].  Does nothing if the copy is there.
$ SET NOON
$ IF F$SEARCH("SAOSTOIC.DIR") .NES. "" THEN GOTO HAVE_COPY
$ BACKUP DUA1:[USERS.CLAUDE.SAOSTOIC...]*.*;* DUA1:[USERS.CLAUDE.WORK.SAOSTOIC...]*.*;*
$ HAVE_COPY:
$ IF F$SEARCH("TESTS.DIR") .EQS. "" THEN CREATE/DIRECTORY [.TESTS]
$ DIRECTORY/SIZE/TOTAL [.SAOSTOIC...]
$ EXIT 1
