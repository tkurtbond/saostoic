$!	WORK-ASSIGN: point the STOIC logical names and symbols at the
$!	scratch copy in [.WORK.SAOSTOIC], as the shipped ASSIGN.COM does for
$!	its own tree.  tools/stoic-run sends this with every run.
$ ASSIGN DUA1:[USERS.CLAUDE.WORK.SAOSTOIC.KERNEL] SAO$KERNEL
$ ASSIGN DUA1:[USERS.CLAUDE.WORK.SAOSTOIC.STOIC]  SAO$STOIC
$ ASSIGN DUA1:[USERS.CLAUDE.WORK.SAOSTOIC.RED]    SAO$RED
$ STOIC :== $SAO$STOIC:STOIC
$ RED :== $SAO$RED:RED RED
$ CALC :== $SAO$RED:RED FLODEF
