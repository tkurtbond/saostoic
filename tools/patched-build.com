$!	PATCHED-BUILD: build the patched copy in [.WORK.PATCHED]: the
$!	kernel (assembled), HEAD0, STOIC.EXE, RED.EXE and REDHIREZ.EXE.
$!	Run by tools/vax-do in [.WORK]; STOIC's progress goes to the
$!	terminal (vax-do -t).  P1 "LINK" skips the assembly.
$ SET NOON
$ SET VERIFY
$ HOME = F$ENVIRONMENT("DEFAULT")
$ SET DEFAULT [.PATCHED]
$ MAC = "MAC"
$ IF P1 .EQS. "LINK" THEN MAC = ""
$ @STOBUILD 'MAC'
$ SET DEFAULT SAO$RED
$ @HIREZ.CRE
$ SET DEFAULT 'HOME'
$ PURGE/KEEP=3 [.PATCHED...]*.EXE,*.OBJ,*.MAP,*.LIS
$ DIRECTORY/DATE/SIZE [.PATCHED...]*.EXE
$ EXIT 1
