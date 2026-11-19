#!/usr/bin/env bash
# Validate the whole harness: manifests, versions, skill and agent frontmatter,
# shell syntax, hook tests, and a privacy scan. Run before every commit and in
# CI. Prints one line per problem and a summary.
#
# Usage: scripts/validate.sh        Exit: 0 = clean, 1 = problems found.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

problems=0
problem() {
  echo "  ✗ $*"
  problems=$((problems + 1))
}
section() { echo "== $*"; }

# frontmatter_field <file> <key>: the value of a top-level key in the leading
# --- block, quotes stripped.
frontmatter_field() {
  awk -v key="$2" 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit}
    NR>1 && index($0, key": ")==1 {sub("^" key ": *", ""); gsub(/^"|"$/, ""); print; exit}' "$1"
}

section "JSON parses"
while IFS= read -r f; do
  jq empty "$f" 2>/dev/null || problem "$f does not parse"
done < <(find . -name '*.json' -not -path './.git/*' -not -path '*/evals/results/*')

section "Manifests and versions agree"
marketplace=.claude-plugin/marketplace.json
for dir in plugins/*/; do
  name=$(basename "$dir")
  manifest="$dir.claude-plugin/plugin.json"
  [ -f "$manifest" ] || {
    problem "$name has no .claude-plugin/plugin.json"
    continue
  }
  [ "$(jq -r .name "$manifest")" = "$name" ] || problem "$manifest: name is not '$name'"
  version=$(jq -r .version "$manifest")
  [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || problem "$manifest: version '$version' is not semver"
  listed=$(jq -r --arg n "$name" '.plugins[] | select(.name == $n) | .version' "$marketplace")
  [ -n "$listed" ] || problem "$name is not listed in $marketplace"
  [ -z "$listed" ] || [ "$listed" = "$version" ] || problem "$name: plugin.json says $version, marketplace says $listed"
  grep -q "^## \[\?$name" CHANGELOG.md 2>/dev/null || grep -q "$name" CHANGELOG.md || problem "$name has no CHANGELOG.md entry"
done
while IFS= read -r source; do
  [ -d "$source" ] || problem "$marketplace lists $source, which does not exist"
done < <(jq -r '.plugins[].source' "$marketplace")

section "Skills and agents"
while IFS= read -r skill; do
  dir=$(basename "$(dirname "$skill")")
  name=$(frontmatter_field "$skill" name)
  desc=$(frontmatter_field "$skill" description)
  [ "$name" = "$dir" ] || problem "$skill: name '$name' does not match its directory '$dir'"
  [ -n "$desc" ] || problem "$skill: no description"
  [ ${#desc} -le 1024 ] || problem "$skill: description is ${#desc} characters (keep it under 1024)"
  lines=$(wc -l <"$skill")
  [ "$lines" -le 500 ] || problem "$skill: $lines lines; move detail into files next to it"
done < <(find plugins -name SKILL.md)
while IFS= read -r agent; do
  [ -n "$(frontmatter_field "$agent" name)" ] || problem "$agent: no name"
  [ -n "$(frontmatter_field "$agent" description)" ] || problem "$agent: no description"
done < <(find plugins -path '*/agents/*.md')

section "Shell scripts"
while IFS= read -r script; do
  bash -n "$script" 2>/dev/null || problem "$script: syntax error"
  [ -x "$script" ] || [[ $script == */lib.sh ]] || problem "$script is not executable"
done < <(find plugins tests scripts -name '*.sh')
if command -v shellcheck >/dev/null; then
  find plugins tests scripts -name '*.sh' -print0 | xargs -0 shellcheck -x -S warning || problem "shellcheck found warnings"
else
  echo "  (shellcheck not installed; skipped)"
fi

section "Hook tests"
tests/hooks/run.sh | tail -n 20 | sed 's/^/  /'
[ "${PIPESTATUS[0]}" -eq 0 ] || problem "hook tests failed"

section "claude plugin validate"
if command -v claude >/dev/null; then
  for target in . plugins/*/; do
    out=$(claude plugin validate "$target" 2>&1) || problem "claude plugin validate $target: $(tail -n 3 <<<"$out" | tr '\n' ' ')"
  done
else
  echo "  (claude not installed; skipped)"
fi

section "Privacy"
# This repo is public. Nothing personal or employer-specific belongs in it.
# Extra words to refuse go in .privacy-denylist, one per line; that file is
# gitignored, so the list itself is never published.
emails=$(git ls-files -co --exclude-standard | grep -v '^scripts/validate.sh$' |
  xargs rg -n --no-heading -e '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' 2>/dev/null |
  rg -v 'noreply@|t@t|@example\.(com|org)|@anthropic\.com' || true)
[ -z "$emails" ] || problem "email addresses found:"$'\n'"$emails"
if [ -f .privacy-denylist ]; then
  while IFS= read -r word; do
    [ -n "$word" ] || continue
    hits=$(git ls-files -co --exclude-standard | grep -v '^\.privacy-denylist$' | xargs rg -il -F -- "$word" 2>/dev/null || true)
    [ -z "$hits" ] || problem "denylisted word found in: $(tr '\n' ' ' <<<"$hits")"
  done <.privacy-denylist
fi

echo
if [ "$problems" -eq 0 ]; then
  echo "validate: clean"
else
  echo "validate: $problems problem(s)"
  exit 1
fi
