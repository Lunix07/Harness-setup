# Shared helpers for the harness-core hooks. Sourced, never executed.
#
# Every hook reads the project's .claude/harness.json through `cfg`. A missing
# file, a missing key or a missing jq all fall back to the default, so a project
# that never ran /harness-init still gets sane behaviour.

HARNESS_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HARNESS_CONFIG="$HARNESS_ROOT/.claude/harness.json"

have_jq() { command -v jq >/dev/null 2>&1; }

# cfg <jq-path> <default>: print one scalar from harness.json, or the default.
cfg() {
  local value=""
  if have_jq && [ -f "$HARNESS_CONFIG" ]; then
    value=$(jq -r "$1 // empty" "$HARNESS_CONFIG" 2>/dev/null)
  fi
  printf '%s' "${value:-$2}"
}

# cfg_list <jq-path> <default words...>: print one array from harness.json, one
# item per line, or the defaults.
cfg_list() {
  local path="$1"
  shift
  if have_jq && [ -f "$HARNESS_CONFIG" ] &&
    jq -e "$path | type == \"array\"" "$HARNESS_CONFIG" >/dev/null 2>&1; then
    jq -r "$path[]" "$HARNESS_CONFIG"
  else
    printf '%s\n' "$@"
  fi
}
