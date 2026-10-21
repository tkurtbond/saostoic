# '.' this file from tools/vax-do after setting host. Only one run at a time
# may use the CLAUDE account's [.WORK] directory, so each run holds a lock
# while it uses the VAX:
#
#   vax_lock      waits for the lock and takes it
#   vax_unlock    gives it up (in the run's EXIT trap)
#
# The lock is flock(1)'s on /tmp/stoic-vax-<uid>-<host>.flock, held by file
# descriptor 9, so the kernel frees it when the run ends, however it ends.
# It is in /tmp, not TMPDIR, so every run on this host shares it.

vax_locked=

vax_lock() {
  command -v flock >/dev/null 2>&1 || { echo "vax-lock: flock(1) is needed" >&2; exit 2; }
  exec 9>>"/tmp/stoic-vax-$(id -u)-$host.flock"
  if ! flock -n 9; then
    echo "vax-lock: waiting for another run to finish with the VAX" >&2
    flock 9
  fi
  vax_locked=1
}

vax_unlock() {
  if [ -n "$vax_locked" ]; then
    exec 9>&-
    vax_locked=
  fi
}
