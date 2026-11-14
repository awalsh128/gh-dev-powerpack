# Eval tasks replayed from awalsh128/ts-apt. Sourced through common.sh.
#
# Each task starts from the parent of a real fix commit. HIDDEN lists that commit's own tests;
# the agent never sees them, and score.sh overlays them afterwards.

SRC_REPO="${SRC_REPO:-$HOME/repos/ts-apt}"
# Origin URL for the clones, so bootstrap.sh can fill in the owner and repo.
REMOTE_URL=https://github.com/awalsh128/ts-apt.git
# Both conditions use the source repo's AGENTS.md at this ref.
AGENTS_REF="${AGENTS_REF:-HEAD}"

INSTALL=(npm ci --ignore-scripts --no-audit --no-fund --loglevel=error)
TEST_HIDDEN=(npx vitest run) # followed by the hidden *.test.ts paths
TEST_UNIT=(npx vitest run --exclude test/ubuntu.integration.test.ts
  --exclude test/ubuntu.mutating.integration.test.ts)
TYPECHECK=(npx tsc -p tsconfig.json --noEmit)
TYPE_ERROR_PATTERN='error TS'

# Shell commands the agent may run, besides the read/edit tools.
ALLOWED_BASH=(
  "Bash(npx vitest:*)" "Bash(npx tsc:*)" "Bash(npx eslint:*)" "Bash(npm run:*)" "Bash(npm test:*)"
  "Bash(git diff:*)" "Bash(git log:*)" "Bash(git status:*)" "Bash(git show:*)"
  "Bash(git add:*)" "Bash(git commit:*)"
  "Bash(ls:*)" "Bash(cat:*)" "Bash(grep:*)" "Bash(rg:*)" "Bash(find:*)" "Bash(head:*)"
  "Bash(tail:*)" "Bash(wc:*)"
)

# id  fix-commit  hidden-test-paths...
# The parent of 7725fee already has one type error (test/ubuntu.integration.test.ts), so compare
# type_errors with the reference fix rather than with zero.
TASKS=(
  "t1-inst-lines 5f22584 test/parser.test.ts"
  "t2-simulate-scope cb068c5 test/manager.test.ts"
  "t3-native-arch 7725fee test/manager.test.ts"
  "t4-list-installed e3c6851 test/parser.test.ts test/manager.test.ts test/data/listinstalled.log"
)

# prompt_for <id>: the task as a bug report or feature request, without the fix.
prompt_for() {
  case "$1" in
    t1-inst-lines) cat <<'EOF'
`parseInstallOutput` and `parseUpgradeOutput` in the apt output parser mishandle two kinds of `Inst` lines from apt's simulated output:

- Foreign-arch packages: `Inst libc6:i386 (2.31-0ubuntu9.2 Ubuntu:20.04/focal-updates [i386])` comes back with the name `libc6:i386` instead of the name `libc6` with arch `i386`.
- Upgrades of installed packages, which show the installed version in brackets: `Inst vim [2:8.1.2269-1ubuntu5.31] (2:8.1.2269-1ubuntu5.32 Ubuntu:20.04/focal-updates [amd64])` is dropped entirely.

Fix the parsing so both produce the right package name, version and architecture, and add tests.
EOF
    ;;
    t2-simulate-scope) cat <<'EOF'
Creating an `AptPackageManager` with simulate mode on leaks into other managers: every `AptPackageManager` created afterwards in the same process also passes `--simulate`, and each simulating manager adds the flag again. Simulate mode should only affect the manager it was enabled on. Fix it and add tests.
EOF
    ;;
    t3-native-arch) cat <<'EOF'
Add a `getNativeArchitecture()` method to the `PackageManager` interface and implement it in `AptPackageManager`. It returns the system's native architecture (for example `amd64`), as reported by `dpkg --print-architecture`, so callers can tell native packages from foreign-arch ones such as `libc6:i386`. Add tests.
EOF
    ;;
    t4-list-installed) cat <<'EOF'
`listInstalled` returns wrong package names for Multi-Arch "same" and foreign packages. dpkg-query prints lines like `bind9-libs:amd64:amd64=1:9.18.30-0ubuntu0.20.04.2`, and the parser returns the name `bind9-libs:amd64`. Every installed package should come back with a plain name and its architecture, and each line `listInstalled` asks dpkg-query for should be in the same `name:arch=version` form that `PackageName.serialize()` produces. Fix it and add tests.
EOF
    ;;
  esac
}
