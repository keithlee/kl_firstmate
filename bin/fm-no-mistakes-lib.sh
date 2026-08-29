#!/usr/bin/env bash
# Resolve the locally pinned no-mistakes executable and verify its identity.
# The pin is private operator configuration at config/no-mistakes, never a
# personal checkout path embedded in shared code.

fm_no_mistakes_config() {
  local home=${FM_HOME:-${FM_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}
  printf '%s\n' "${FM_NO_MISTAKES_CONFIG:-$home/config/no-mistakes}"
}

fm_no_mistakes_value() {
  local key=$1 file
  file=$(fm_no_mistakes_config)
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  sed -n "s/^$key=//p" "$file" | tail -1
}

fm_no_mistakes_resolve() {
  local configured expected_path expected_identity candidate real version
  configured=$(fm_no_mistakes_value path || true)
  candidate=${configured:-$(command -v no-mistakes 2>/dev/null || true)}
  [ -n "$candidate" ] || { echo "no-mistakes is not installed" >&2; return 1; }
  real=$(realpath "$candidate" 2>/dev/null || true)
  [ -n "$real" ] && [ -x "$real" ] || { echo "no-mistakes executable cannot be resolved: $candidate" >&2; return 1; }
  expected_path=$(fm_no_mistakes_value realpath || true)
  if [ -n "$expected_path" ] && [ "$real" != "$expected_path" ]; then
    echo "no-mistakes executable identity mismatch: resolved $real, expected $expected_path" >&2
    return 1
  fi
  expected_identity=$(fm_no_mistakes_value identity || true)
  if [ -n "$expected_identity" ]; then
    version=$($real --version 2>/dev/null || true)
    case "$version" in
      *"$expected_identity"*) ;;
      *) echo "no-mistakes build identity mismatch: expected $expected_identity" >&2; return 1 ;;
    esac
  fi
  printf '%s\n' "$real"
}

fm_no_mistakes_require() {
  local resolved
  resolved=$(fm_no_mistakes_resolve) || {
    echo "NO_MISTAKES_IDENTITY: $(fm_no_mistakes_config) does not match the active no-mistakes binary; set path, realpath, and identity to the approved fork build" >&2
    return 1
  }
  FM_NO_MISTAKES_BIN=$resolved
  export FM_NO_MISTAKES_BIN
}
