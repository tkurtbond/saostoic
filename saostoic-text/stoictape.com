$ TYPE SYS$INPUT

********************************************************************************
**********  This procedure creates a distribution tape for STOIC,     **********
**********  the Stack-Oriented Interactive Compiler and RED,          **********
**********  a CRT-oriented editor which is designed for convenience   **********
**********  and efficiency under VMS.                                 **********
**********                                                            **********
**********  After using BACKUP to restore this tape to disk,          **********
**********  examine the file AAAREADME.LIS                            **********
**********                                                            **********
**********                                                            **********
**********  Roger Hauck                                               **********
**********  Smithsonian Institution                                   **********
**********  Astrophysical Observatory                                 **********
**********  60 Garden Street                                          **********
**********  Cambridge, MA 02138                                       **********
**********  (617)495-7151 or (FTS)830-7151                            **********
********************************************************************************

$ SET DEFAULT G2:[SAOSTOIC]
$ INIT SAOSTOIC_RI/DENS=1600 ROGER
$ MNT SAOSTOIC_RI/DENS=1600/FOREIGN ROGER T
$ BACKUP [SAOSTOIC...] T:STOIC.BCK/LABEL=ROGER
$ BACKUP/REWIND/LIST T:STOIC.BCK
