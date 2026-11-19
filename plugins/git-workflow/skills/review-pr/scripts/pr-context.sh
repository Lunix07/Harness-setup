#!/usr/bin/env bash
# Collect everything a review of one pull request (GitHub) or merge request
# (GitLab) needs into a directory, and print a short index of it.
#
# With a usable gh/glab: the PR record, check status and existing review
# comments. Always, with plain git: the head, the diff against the merge base,
# the touched files, the commits and the issue key.
#
# Exit: 0 = collected, 2 = bad arguments or the head cannot be fetched.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2

if [[ $# -lt 1 || "$1" == -h || "$1" == --help ]]; then
  sed -n '2,9p' "$0" | sed 's/^# \?//'
  echo
  echo "Usage: pr-context.sh <number> [out-dir]"
  exit 2
fi

NUM=${1#[#!]}
OUT="${2:-${TMPDIR:-/tmp}/review-pr-$NUM}"
mkdir -p "$OUT"

config=.claude/harness.json
cfg() { [ -f "$config" ] && jq -r "$1 // empty" "$config" 2>/dev/null; }
BASE=$(cfg .baseBranch)
BASE=${BASE:-main}
KEY_PATTERN=$(cfg .issues.keyPattern)
FORGE=$(cfg .forge)
if [ -z "$FORGE" ]; then
  case "$(git remote get-url origin 2>/dev/null)" in
    *github.com*) FORGE=github ;;
    *) FORGE=gitlab ;;
  esac
fi

CLI=0
TITLE=""
BRANCH=""
BODY=""
CHECKS="unknown"
case "$FORGE" in
  github)
    if command -v gh >/dev/null && gh pr view "$NUM" --json number >/dev/null 2>&1; then
      CLI=1
      gh pr view "$NUM" --json number,title,body,headRefName,baseRefName,headRefOid,url,statusCheckRollup >"$OUT/pr.json"
      gh api --paginate "repos/{owner}/{repo}/pulls/$NUM/comments" |
        jq -r '.[] | "\(.path):\(.line // .original_line // "-")  \(.body | gsub("\n"; " ") | .[0:100])"' >"$OUT/comments.txt"
      TITLE=$(jq -r .title "$OUT/pr.json")
      BRANCH=$(jq -r .headRefName "$OUT/pr.json")
      BODY=$(jq -r .body "$OUT/pr.json")
      CHECKS=$(jq -r '[.statusCheckRollup[]? | (.conclusion // .state // "PENDING")] |
        if length == 0 then "none"
        elif any(. == "FAILURE" or . == "ERROR" or . == "CANCELLED") then "failed"
        elif any(. == "PENDING" or . == "IN_PROGRESS" or . == "QUEUED" or . == "") then "running"
        else "passed" end' "$OUT/pr.json")
    fi
    REF="pull/$NUM/head"
    ;;
  gitlab)
    if command -v glab >/dev/null && glab api projects/:id >/dev/null 2>&1; then
      CLI=1
      glab api "projects/:id/merge_requests/$NUM" >"$OUT/pr.json" || exit 2
      glab api --paginate "projects/:id/merge_requests/$NUM/discussions?per_page=100" | jq -s 'add' |
        jq -r '.[] | select(.individual_note | not) | .notes[0]
          | select(.resolvable and (.resolved | not))
          | "\(.position.new_path // "-"):\(.position.new_line // "-")  \(.body | gsub("\n"; " ") | .[0:100])"' \
          >"$OUT/comments.txt"
      TITLE=$(jq -r .title "$OUT/pr.json")
      BRANCH=$(jq -r .source_branch "$OUT/pr.json")
      BODY=$(jq -r .description "$OUT/pr.json")
      CHECKS=$(jq -r '.head_pipeline.status // "none"' "$OUT/pr.json")
    fi
    REF="merge-requests/$NUM/head"
    ;;
  *)
    echo "unknown forge '$FORGE' (github or gitlab)" >&2
    exit 2
    ;;
esac
touch "$OUT/comments.txt"

git fetch -q origin "$BASE" "+$REF:refs/review/pr-$NUM" || exit 2
HEAD_SHA=$(git rev-parse "refs/review/pr-$NUM")
BASE_SHA=$(git merge-base "origin/$BASE" "$HEAD_SHA")

git diff "$BASE_SHA" "$HEAD_SHA" >"$OUT/diff.patch"
git diff --stat=120 "$BASE_SHA" "$HEAD_SHA" >"$OUT/diffstat.txt"
git diff --name-only "$BASE_SHA" "$HEAD_SHA" >"$OUT/files.txt"
git log --format='%h %s' "$BASE_SHA..$HEAD_SHA" >"$OUT/commits.txt"

ISSUE=""
haystack=$(printf '%s\n%s\n%s\n' "$TITLE" "$BRANCH" "$BODY"; git log -1 --format=%B "$HEAD_SHA")
if [ -n "$KEY_PATTERN" ]; then
  ISSUE=$(grep -oE "$KEY_PATTERN" <<<"$haystack" | head -1)
fi
if [ -z "$ISSUE" ]; then
  ISSUE=$(grep -oiE '(closes|fixes|resolves) +[^ ]*#[0-9]+' <<<"$haystack" | head -1)
fi

echo "forge:     $FORGE"
echo "pr:        #$NUM ${TITLE:-(no cli: title unknown)}"
echo "cli:       $([[ $CLI == 1 ]] && echo usable || echo 'unavailable - report in the conversation only')"
echo "issue:     ${ISSUE:-none found in title, branch, description or head commit}"
echo "head_sha:  $HEAD_SHA"
echo "base_sha:  $BASE_SHA"
((CLI)) && echo "checks:    $CHECKS"
((CLI)) && echo "comments:  $(wc -l <"$OUT/comments.txt") existing, in $OUT/comments.txt"
echo "commits:   $(wc -l <"$OUT/commits.txt")"
echo "files:     $(wc -l <"$OUT/files.txt"), $(tail -1 "$OUT/diffstat.txt")"
echo "out:       $OUT"
