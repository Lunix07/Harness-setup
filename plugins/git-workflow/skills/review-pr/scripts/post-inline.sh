#!/usr/bin/env bash
# Post one review comment on an added line of a pull request (GitHub) or merge
# request (GitLab). Needs a usable gh or glab.
#
# The line is a line number in the file at the PR head, and it must be an added
# line of the diff: both forges reject a position outside the diff. Such a
# finding goes into the summary instead.
#
# Exit: 0 = posted (prints the comment id), 1 = the forge refused it,
# 2 = bad arguments.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2

if [[ $# -ne 4 || ! -f "$4" ]]; then
  sed -n '2,10p' "$0" | sed 's/^# \?//'
  echo
  echo "Usage: post-inline.sh <number> <path> <new-line> <body-file>"
  exit 2
fi

NUM=${1#[#!]}
FILE_PATH=$2
LINE=$3
BODY_FILE=$4

FORGE=$([ -f .claude/harness.json ] && jq -r '.forge // empty' .claude/harness.json)
if [ -z "$FORGE" ]; then
  case "$(git remote get-url origin 2>/dev/null)" in
    *github.com*) FORGE=github ;;
    *) FORGE=gitlab ;;
  esac
fi

if [ "$FORGE" = github ]; then
  HEAD_SHA=$(gh pr view "$NUM" --json headRefOid -q .headRefOid) || exit 1
  RESPONSE=$(jq -n --rawfile body "$BODY_FILE" --arg sha "$HEAD_SHA" \
    --arg path "$FILE_PATH" --argjson line "$LINE" \
    '{body: $body, commit_id: $sha, path: $path, line: $line, side: "RIGHT"}' |
    gh api -X POST "repos/{owner}/{repo}/pulls/$NUM/comments" --input - 2>&1) || {
    echo "refused: $RESPONSE" >&2
    exit 1
  }
  jq -r .id <<<"$RESPONSE"
  exit 0
fi

REFS=$(glab api "projects/:id/merge_requests/$NUM" | jq -c .diff_refs) || exit 1
PAYLOAD=$(jq -n --rawfile body "$BODY_FILE" --argjson refs "$REFS" \
  --arg path "$FILE_PATH" --argjson line "$LINE" \
  '{body: $body,
    position: ($refs + {position_type: "text", old_path: $path, new_path: $path, new_line: $line})}') || exit 2
RESPONSE=$(glab api -X POST "projects/:id/merge_requests/$NUM/discussions" \
  -H "Content-Type: application/json" --input - <<<"$PAYLOAD" 2>&1) || {
  echo "refused: $RESPONSE" >&2
  exit 1
}
jq -r .id <<<"$RESPONSE"
