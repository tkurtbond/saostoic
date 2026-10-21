$!	SETUP: make the directories the IMAGE tests use, in [.WORK.IMG].
$!	SHIP holds the shipped HEAD0.EXE (from the reference tree), NEW the
$!	rebuilt one (;2 in the work tree), and EMPTY nothing.  Run once with
$!	tools/vax-do; it does nothing that is already done.
$ SET NOON
$ IF F$SEARCH("[]IMG.DIR") .EQS. "" THEN CREATE/DIRECTORY [.IMG]
$ IF F$SEARCH("[.IMG]SHIP.DIR") .EQS. "" THEN CREATE/DIRECTORY [.IMG.SHIP]
$ IF F$SEARCH("[.IMG]NEW.DIR") .EQS. "" THEN CREATE/DIRECTORY [.IMG.NEW]
$ IF F$SEARCH("[.IMG]EMPTY.DIR") .EQS. "" THEN CREATE/DIRECTORY [.IMG.EMPTY]
$ IF F$SEARCH("[.IMG.SHIP]HEAD0.EXE") .EQS. "" THEN -
	COPY DUA1:[USERS.CLAUDE.SAOSTOIC.KERNEL]HEAD0.EXE;1 [.IMG.SHIP]HEAD0.EXE
$ IF F$SEARCH("[.IMG.NEW]HEAD0.EXE") .EQS. "" THEN -
	COPY DUA1:[USERS.CLAUDE.WORK.SAOSTOIC.KERNEL]HEAD0.EXE;2 [.IMG.NEW]HEAD0.EXE
$ DIRECTORY/SIZE/DATE [.IMG...]
$ EXIT 1
