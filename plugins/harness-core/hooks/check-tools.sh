#!/usr/bin/env bash
# SessionStart hook. Prints the CLI tools this project expects but cannot find.
# A SessionStart hook's stdout is added to the session context, so the warning
# arrives before the first prompt, and Claude does not plan around a tool that is
# not there. Silent when everything is present.
#
# Expected tools: git, jq and rg always, plus the project's `tools` list in
# .claude/harness.json.
set -uo pipefail
cat >/dev/null # drain the hook payload; nothing in it is needed

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

missing=()
while IFS= read -r tool; do
  [ -n "$tool" ] || continue
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done < <(
  printf '%s\n' git jq rg
  cfg_list '.tools'
)

if [ ${#missing[@]} -gt 0 ]; then
  # sort -u: a tool listed both as a default and in harness.json is named once.
  echo "Missing from PATH: $(printf '%s\n' "${missing[@]}" | sort -u | tr '\n' ' ')"
  echo "Do not plan around these tools; use an installed alternative or ask the user to install them."
  have_jq || echo "Without jq the harness hooks fall back to their defaults and ignore .claude/harness.json."
fi

exit 0
