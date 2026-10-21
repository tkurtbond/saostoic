# The VAX login by telnet, for tools/vax-do.exp, adapted from Peaseblossom's
# tools/vax-login.tcl. "source" it, then "vax_login $host": that leaves the
# session at the prompt "STOICVAX> " ($prompt, a regular expression), with
# the default directory the work directory ([.WORK], or $VAX_WORKDIR), or
# exits 2 with a message. The password is read here from $VAX_NETRC (by
# default ~/.netrc-claude-vax), never from a command line, and nothing is
# shown while it is sent (log_user 0).

# the netrc file: $VAX_NETRC, or ~/.netrc-claude-vax
proc netrc_file {} {
  if {[info exists ::env(VAX_NETRC)] && $::env(VAX_NETRC) ne ""} { return $::env(VAX_NETRC) }
  return [file join $::env(HOME) .netrc-claude-vax]
}

# login and password of the first "machine $host" entry in the netrc file
proc netrc {host} {
  if {[catch {open [netrc_file] r} f]} { fail "cannot read [netrc_file]" }
  set tokens [regexp -all -inline {\S+} [read $f]]
  close $f
  set login ""; set password ""; set here 0
  for {set i 0} {$i < [llength $tokens]} {incr i} {
    set t [lindex $tokens $i]
    if {$t eq "machine"} {
      if {$here} break
      incr i; set here [expr {[lindex $tokens $i] eq $host}]
    } elseif {$t eq "default"} {
      if {$here} break
    } elseif {$here && $t eq "login"} {
      incr i; set login [lindex $tokens $i]
    } elseif {$here && $t eq "password"} {
      incr i; set password [lindex $tokens $i]
    }
  }
  return [list $login $password]
}

# the message, after the name of the tool's script, on the standard error
proc fail {message} {
  puts stderr "[file rootname [file tail $::argv0]]: $message"
  exit 2
}

proc vax_login {host} {
  global spawn_id expect_out prompt
  lassign [netrc $host] login password
  if {$login eq "" || $password eq ""} { fail "no login and password for $host in [netrc_file]" }

  spawn -noecho telnet $host
  expect {
    -re {Username: ?$} {}
    timeout { fail "no Username: prompt from $host" }
    eof { fail "telnet to $host closed" }
  }
  send "$login\r"
  expect {
    -re {Password: ?$} {}
    timeout { fail "no Password: prompt from $host" }
  }
  send "$password\r"
  unset password
  # VAX_LOGIN_LOG names a file for the session from here on, the password
  # already sent, for finding out why a prompt was not recognised
  if {[info exists ::env(VAX_LOGIN_LOG)]} { log_file -a -noappend $::env(VAX_LOGIN_LOG) }
  # the DCL prompt: "$ " at the start of a line
  set prompt {\n\$ $}
  set answered 0
  expect {
    -re $prompt {}
    -re "\033(Z|\\\[0?c)" {
      # SET TERMINAL/INQUIRE in the login asks what the terminal is: a
      # VT100 with advanced video, answered once
      if {!$answered} { send "\033\[?1;2c"; set answered 1 }
      exp_continue
    }
    -re {User authorization failure} { fail "login to $host refused" }
    timeout { fail "no DCL prompt after logging in to $host" }
  }
  # from here on a prompt of our own, which no output can be mistaken for
  send "SET PROMPT=\"STOICVAX> \"\r"
  set prompt {STOICVAX> $}
  expect {
    -re $prompt {}
    timeout { fail "SET PROMPT was not answered" }
  }
  set workdir {[.WORK]}
  if {[info exists ::env(VAX_WORKDIR)] && $::env(VAX_WORKDIR) ne ""} { set workdir $::env(VAX_WORKDIR) }
  send "SET DEFAULT SYS\$LOGIN\r"
  expect -re $prompt
  send "SET DEFAULT $workdir\r"
  expect -re $prompt
}
