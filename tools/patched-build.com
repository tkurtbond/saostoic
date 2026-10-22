$!	PATCHED-BUILD: build the patched copy in [.WORK.PATCHED]: the
$!	kernel (assembled), HEAD0, STOIC.EXE, RED.EXE and REDHIREZ.EXE.
$!	Run by tools/vax-do in [.WORK]; STOIC's progress goes to the
$!	terminal (vax-do -t).  P1 "LINK" skips the assembly ("" or "MAC"
$!	does not).  P2 names another tree made by SETUP-PATCHED, such as
$!	CMPFIX (vax-do -p MAC -p CMPFIX).
$ SET NOON
$ SET VERIFY
$ HOME = F$ENVIRONMENT("DEFAULT")
$ TREE = "PATCHED"
$ IF P2 .NES. "" THEN TREE = P2
$ SET DEFAULT [.'TREE']
$ MAC = "MAC"
$ IF P1 .EQS. "LINK" THEN MAC = ""
$ @STOBUILD 'MAC'
$ SET DEFAULT SAO$RED
$ @HIREZ.CRE
$ SET DEFAULT 'HOME'
$ PURGE/KEEP=3 [.'TREE'...]*.EXE,*.OBJ,*.MAP,*.LIS
$ DIRECTORY/DATE/SIZE [.'TREE'...]*.EXE
$ EXIT 1
