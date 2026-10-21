# The prompt shows CHECK, the depth of open structures, while a definition
# runs over several lines; CTRL/Z at the prompt (end of file on the console)
# exits STOIC to DCL.
stoic
line "'FOO :"
line "1 IF"
line "BEGIN 2"
line "1 END"
line "THEN"
line ";"
line "FOO = CR"
keys "\032" 3
