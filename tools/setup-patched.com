$!	SETUP-PATCHED: make the Phase 6 copy of STOIC, once.  Run by
$!	tools/vax-do in [.WORK]: copies [.SAOSTOIC...] to
$!	[.WORK.PATCHED...], where tools/patched-push puts the patched
$!	sources and tools/patched-build.com builds them.  Does nothing if
$!	the copy is there.
$ SET NOON
$ IF F$SEARCH("PATCHED.DIR") .NES. "" THEN GOTO HAVE_COPY
$ BACKUP DUA1:[USERS.CLAUDE.SAOSTOIC...]*.*;* DUA1:[USERS.CLAUDE.WORK.PATCHED...]*.*;*
$ HAVE_COPY:
$ DIRECTORY/SIZE/TOTAL [.PATCHED...]
$ EXIT 1
