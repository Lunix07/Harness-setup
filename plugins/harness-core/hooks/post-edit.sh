#!/usr/bin/env bash
# PostToolUse hook for Edit|Write|MultiEdit. Runs the project's own checks on
# the file just edited, as configured in .claude/harness.json:
#
#   "postEdit": [
#     { "glob": "*.ts",          "command": "deno check {file}" },
#     { "glob": "crates/*.rs",   "command": "cargo check -q" }
#   ]
#
# `glob` is a bash pattern against the path relative to the project root (`*`
# also matches `/`). `{file}` is replaced by that path, shell-quoted. Every
# matching entry runs, from the project root.
#
# On failure it prints the check's output to stderr and exits 2. A PostToolUse
# hook's stdout on exit 0 only reaches the debug log; exit 2 with stderr is the
# only way the errors reach Claude.
#
# The commands come from the project's checked-in config, so they run with the
# same trust as the project's own .claude/settings.json hooks.
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

have_jq || exit 0
[ -f "$HARNESS_CONFIG" ] || exit 0

file=$(jq -r '.tool_input.file_path // empty')
[ -n "$file" ] || exit 0
rel=${file#"$HARNESS_ROOT"/}

count=$(jq '.postEdit // [] | length' "$HARNESS_CONFIG" 2>/dev/null || echo 0)
status=0
for ((i = 0; i < count; i++)); do
  glob=$(jq -r ".postEdit[$i].glob // empty" "$HARNESS_CONFIG")
  command=$(jq -r ".postEdit[$i].command // empty" "$HARNESS_CONFIG")
  [ -n "$glob" ] && [ -n "$command" ] || continue
  # shellcheck disable=SC2053 # $glob is a pattern on purpose
  [[ $rel == $glob ]] || continue

  command=${command//\{file\}/$(printf '%q' "$rel")}
  if ! output=$(cd "$HARNESS_ROOT" && bash -c "$command" 2>&1); then
    {
      echo "postEdit check failed for $rel: $command"
      # The last lines carry the error; a full build log would flood the context.
      printf '%s\n' "$output" | tail -n 60
    } >&2
    status=2
  fi
done

exit $status
