#!/usr/bin/env bash
# Table tests for the harness-core hooks. Each case feeds a hook the JSON payload
# Claude Code would send and checks the exit code: 0 lets the call through, 2
# blocks it. Runs in a throwaway git repo, so `current branch` is controlled.
#
# Usage: tests/hooks/run.sh        Exit: 0 = all pass, 1 = a case failed.
set -uo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
hooks="$repo_root/plugins/harness-core/hooks"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
git -C "$sandbox" init -q -b main
git -C "$sandbox" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
export CLAUDE_PROJECT_DIR="$sandbox"

pass=0
fail=0

# expect <want-exit> <hook> <payload-json> <name>
expect() {
  local want=$1 hook=$2 payload=$3 name=$4 got
  printf '%s' "$payload" | bash "$hooks/$hook" >/dev/null 2>"$sandbox/stderr"
  got=$?
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL  $name: exit $got, want $want"
    sed 's/^/      /' "$sandbox/stderr"
  fi
}

bash_call() { jq -cn --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}'; }
guard() { expect "$1" guard-bash.sh "$(bash_call "$2")" "guard: $2"; }

# --- guard-bash: attribution ----------------------------------------------------
guard 2 'git commit -m "fix: x" -m "Co-Authored-By: Claude <noreply@anthropic.com>"'
guard 2 "git commit -m \"\$(printf 'feat: y\n\nhttps://claude.ai/code/session_1')\""
guard 0 'git commit -m "fix: handle empty input"'
guard 0 'echo co-authored-by'

# --- guard-bash: pushes ------------------------------------------------------------
guard 2 'git push --force origin main'
guard 2 'git push -f origin HEAD:main'
guard 2 'git push origin +main'
guard 2 'git push origin --delete master'
guard 2 'git push origin main'
guard 2 'git push' # current branch in the sandbox is main
guard 2 'cd x && git -C . push origin main'
guard 0 'git push origin feature/x'
guard 0 'git push -u origin HEAD:feature/x'
guard 0 'git push -o merge_request.target=main origin feature/x'
guard 0 'git push --force-with-lease origin feature/x'

# --- guard-bash: rm ------------------------------------------------------------------
guard 2 'rm -rf /'
guard 2 'rm -rf ~'
guard 2 'sudo rm -r "$HOME"'
guard 2 'rm -fr ..'
guard 2 'rm --recursive .'
guard 0 'rm -rf ./target'
guard 0 'rm -f /tmp/x.txt'
guard 0 'rm ~'

# --- configuration --------------------------------------------------------------------
mkdir -p "$sandbox/.claude"
cat >"$sandbox/.claude/harness.json" <<'JSON'
{
  "guards": { "protectedBranches": ["release"], "allowDirectPush": true },
  "postEdit": [
    { "glob": "*.ok",   "command": "true {file}" },
    { "glob": "*.bad",  "command": "echo broken {file}; exit 1" }
  ]
}
JSON
guard 0 'git push origin main'
guard 0 'git push origin release'
guard 2 'git push -f origin release'

edit() { jq -cn --arg f "$sandbox/$1" '{tool_name: "Edit", tool_input: {file_path: $f}}'; }
expect 0 post-edit.sh "$(edit src/a.ok)" "post-edit: passing check"
expect 2 post-edit.sh "$(edit src/a.bad)" "post-edit: failing check"
expect 0 post-edit.sh "$(edit src/a.txt)" "post-edit: no matching glob"

echo '{"tools": ["definitely-not-installed-tool"]}' >"$sandbox/.claude/harness.json"
if echo '{}' | bash "$hooks/check-tools.sh" | grep -q definitely-not-installed-tool; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "FAIL  check-tools: did not report a missing tool"
fi

echo "hooks: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
