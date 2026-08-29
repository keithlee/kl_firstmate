#!/usr/bin/env bash
# Executable lifecycle test: a live readiness read revokes checks-passed and
# permits a fresh ready handback only after the same current head passes.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT_CASE=$(fm_test_tmproot fm-feedback-readiness)
WT="$ROOT_CASE/worktree"
mkdir -p "$WT" "$ROOT_CASE/state" "$ROOT_CASE/config" "$ROOT_CASE/bin"
git -C "$WT" init -q
git -C "$WT" commit -q --allow-empty -m init
BRANCH=$(git -C "$WT" symbolic-ref --short HEAD)
HEAD=$(git -C "$WT" rev-parse HEAD)
export BRANCH HEAD
cat > "$ROOT_CASE/bin/no-mistakes" <<'SH'
#!/usr/bin/env bash
set -u
if [ "${1:-}" = --version ]; then echo 'no-mistakes v1.60.1 (approved-test-build)'; exit 0; fi
if [ "${1:-}" = runs ]; then exit 0; fi
if [ "${1:-}" = axi ] && [ "${2:-}" = status ]; then
  printf 'id: run-1\nbranch: %s\nhead: %s\nstatus: ci\noutcome: checks-passed\npr: https://github.com/example/repo/pull/1\n' "$BRANCH" "$HEAD"
  exit 0
fi
if [ "${1:-}" = axi ] && [ "${2:-}" = logs ]; then echo 'all CI checks passed - still monitoring until merged or closed'; exit 0; fi
if [ "${1:-}" = axi ] && [ "${2:-}" = pr-readiness ]; then
  [ "${FM_READINESS:-fail}" = pass ] && exit 0
  exit 1
fi
exit 0
SH
chmod +x "$ROOT_CASE/bin/no-mistakes"
cat > "$ROOT_CASE/config/no-mistakes" <<EOF
path=$ROOT_CASE/bin/no-mistakes
realpath=$(realpath "$ROOT_CASE/bin/no-mistakes")
identity=approved-test-build
EOF
cat > "$ROOT_CASE/state/crew.meta" <<EOF
worktree=$WT
kind=ship
harness=claude
backend=tmux
window=fm-crew
EOF
output=$(env PATH="$ROOT_CASE/bin:$PATH" FM_HOME="$ROOT_CASE" FM_STATE_OVERRIDE="$ROOT_CASE/state" FM_ROOT_OVERRIDE="$ROOT" \
  "$ROOT/bin/fm-crew-state.sh" crew)
case "$output" in *"state: blocked"*feedback-blocked*) ;; *) fail "expected blocked readiness, got: $output" ;; esac
output=$(env FM_READINESS=pass PATH="$ROOT_CASE/bin:$PATH" FM_HOME="$ROOT_CASE" FM_STATE_OVERRIDE="$ROOT_CASE/state" FM_ROOT_OVERRIDE="$ROOT" \
  "$ROOT/bin/fm-crew-state.sh" crew)
case "$output" in *"state: done"*) ;; *) fail "expected fresh ready handback, got: $output" ;; esac
pass "feedback readiness lifecycle"
