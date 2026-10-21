$!	Assemble RMS and RKERNEL, then...
$!	STOBUILD: command procedure to assign the STOIC logical names
$!	from the current default directory, and run the three STOIC
$!	build files.
$ SET DEF GP2:[SAOSTOIC]
$ @ASSIGN		!assign SAO$KERNEL, SAO$STOIC, and SAO$RED
$ SET DEF SAO$KERNEL	!move to the kernel directory
$ MAC RMS
$ MAC RKERNEL
$ TYPE SYS$INPUT
Building RKERNEL.EXE ...
$ IF "''P1'" .NES. "MAC" THEN GOTO LINK
$ @KERMAC		!assemble the MACRO sources
$ LINK:
$ @KERLINK
$ SET DEF SAO$STOIC
$ TYPE SYS$INPUT
Loading the STOIC definitions ...
$ @STOIC.CRE		!load STOIC input files; create STOIC.EXE
$ SET DEF SAO$RED
$ TYPE SYS$INPUT
Loading RED ...
$ @RED.CRE
$ TYPE SYS$INPUT
Finished; current default directory is SAO$RED.
To create the INFOTON version now, type "@ORANGE.CRE".
$ XMTR REPLY/BELL/TERM=TXA1 "STOIC JOB DONE"
