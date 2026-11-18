# Shared helpers for the setup_*.sh scripts. Source it; don't run it.
#
# The sourcing script sets dry_run (true or false) before calling run.
#   step <title>      Prints a section heading.
#   run <command...>  Prints the command, then runs it unless dry_run is true.
#   manual <text>     Prints a step that only a person can do.

step() { printf '\n==> %s\n' "$*"; }
run() {
  echo "+ $*"
  "$dry_run" || "$@"
}
manual() { printf '\n[MANUAL] %s\n' "$*"; }
