#!/usr/bin/env bash
# Executable pin contract tests: configured identity is authoritative and an
# absolute pinned binary works even when it is absent from PATH.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
case_dir=$(fm_test_tmproot fm-no-mistakes-pin)
mkdir -p "$case_dir/config" "$case_dir/bin"
cat > "$case_dir/bin/pinned" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = --version ] && { echo 'no-mistakes approved-build'; exit 0; }
[ "${1:-}" = axi ] && { echo 'ok'; exit 0; }
SH
chmod +x "$case_dir/bin/pinned"
cat > "$case_dir/config/no-mistakes" <<EOF
path=$case_dir/bin/pinned
realpath=$(realpath "$case_dir/bin/pinned")
identity=approved-build
EOF
# shellcheck disable=SC2016
if ! output=$(env FM_HOME="$case_dir" FM_NO_MISTAKES_CONFIG="$case_dir/config/no-mistakes" PATH=/usr/bin:/bin bash -c '. "$1/bin/fm-no-mistakes-lib.sh"; fm_no_mistakes_resolve' _ "$ROOT"); then
  fail "valid absolute pin was rejected outside PATH"
fi
[ "$output" = "$(realpath "$case_dir/bin/pinned")" ] || fail "pin resolved to $output"
printf 'path=%s\nrealpath=%s\nidentity=wrong-build\n' "$case_dir/bin/pinned" "$(realpath "$case_dir/bin/pinned")" > "$case_dir/config/no-mistakes"
# shellcheck disable=SC2016
if env FM_HOME="$case_dir" FM_NO_MISTAKES_CONFIG="$case_dir/config/no-mistakes" PATH=/usr/bin:/bin bash -c '. "$1/bin/fm-no-mistakes-lib.sh"; fm_no_mistakes_resolve' _ "$ROOT" >/dev/null 2>&1; then
  fail "mismatched configured identity was accepted"
fi
printf 'path=%s\nrealpath=%s\n' "$case_dir/bin/pinned" "$(realpath "$case_dir/bin/pinned")" > "$case_dir/config/no-mistakes"
# shellcheck disable=SC2016
if env FM_HOME="$case_dir" FM_NO_MISTAKES_CONFIG="$case_dir/config/no-mistakes" PATH=/usr/bin:/bin bash -c '. "$1/bin/fm-no-mistakes-lib.sh"; fm_no_mistakes_resolve' _ "$ROOT" >/dev/null 2>&1; then
  fail "path-only configured pin was accepted"
fi
pass "no-mistakes pin authority"

# Readiness is a structured contract, not an exit code. Malformed or unknown
# output must remain blocked even when the wrapped command exits successfully.
valid_readiness=$'pr: https://github.com/example/repo/pull/1\nphase: handback\nready: true\nhead: expected-head\nproof_review: true\nci: true\nreview_decision: APPROVED\nunresolved_item_ids: []\nunresolved_item_urls: []\nunknown: false\nreason: validated'
if ! bash -c '. "$1/bin/fm-nm-run-lib.sh"; fm_nm_validate_readiness "$2" expected-head handback' _ "$ROOT" "$valid_readiness"; then
  fail "valid readiness contract was rejected"
fi
if bash -c '. "$1/bin/fm-nm-run-lib.sh"; fm_nm_validate_readiness "ready: true" expected-head handback' _ "$ROOT"; then
  fail "malformed readiness contract was accepted"
fi
pass "readiness output contract fails closed"
