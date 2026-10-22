$!	SETUP-PATCHED: make the Phase 6 copy of STOIC, once.  Run by
$!	tools/vax-do in [.WORK]: copies [.SAOSTOIC...] to
$!	[.WORK.PATCHED...], where tools/patched-push puts the patched
$!	sources and tools/patched-build.com builds them.  Does nothing if
$!	the copy is there.  P1 names another tree, such as CURRENT.
$ SET NOON
$ TREE = "PATCHED"
$ IF P1 .NES. "" THEN TREE = P1
$ IF F$SEARCH("''TREE'.DIR") .NES. "" THEN GOTO HAVE_COPY
$ BACKUP DUA1:[USERS.CLAUDE.SAOSTOIC...]*.*;* DUA1:[USERS.CLAUDE.WORK.'TREE'...]*.*;*
$ HAVE_COPY:
$ DIRECTORY/SIZE/TOTAL [.'TREE'...]
$ EXIT 1
