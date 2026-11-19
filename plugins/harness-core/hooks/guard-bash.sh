#!/usr/bin/env bash
# PreToolUse hook for Bash. Blocks the few commands that are cheap to type and
# expensive to undo:
#
#   - a commit carrying a Co-Authored-By trailer or a session link
#     (guards.forbidAttribution, default true);
#   - a force push to, or a deletion of, a protected branch
#     (guards.protectedBranches, default main and master);
#   - any push straight to a protected branch, unless guards.allowDirectPush;
#   - a recursive rm of /, ~, $HOME, . or .. .
#
# Exit 2 with a reason on stderr blocks the call and hands the reason to Claude,
# so it can change course instead of retrying. This is a seatbelt for honest
# mistakes, not a sandbox: an obfuscated command (eval, a variable as the
# branch name) gets through. Permissions and review stay the real defence.
set -uo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

have_jq || exit 0
command=$(jq -r '.tool_input.command // empty')
[ -n "$command" ] || exit 0

block() {
  echo "Blocked by harness-core guard-bash: $1" >&2
  exit 2
}

mapfile -t protected < <(cfg_list '.guards.protectedBranches' main master)
is_protected() {
  local branch
  for branch in "${protected[@]}"; do [ "$1" = "$branch" ] && return 0; done
  return 1
}

current_branch() {
  git -C "$HARNESS_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null
}

# --- attribution in commit messages -----------------------------------------
if [ "$(cfg '.guards.forbidAttribution' true)" = true ] &&
  printf '%s' "$command" | grep -Eq '(^|[[:space:];&|(])git[[:space:]].*commit'; then
  if printf '%s' "$command" | grep -Eiq 'co-authored-by|claude\.ai/code|generated with \[?claude'; then
    block "commit messages carry no Co-Authored-By trailer, session link or 'Generated with' line. Remove it and commit again."
  fi
fi

# --- push and rm, one simple command at a time --------------------------------
segments=$(printf '%s\n' "$command" | sed -E 's/(&&|\|\||;|\|)/\n/g')

check_push() {
  # $@: the tokens after `push`.
  local force=0 delete=0 skip_next=0 token remote="" refspecs=()
  for token in "$@"; do
    if ((skip_next)); then
      skip_next=0
      continue
    fi
    case "$token" in
      -o | --push-option | --repo | --receive-pack | --exec) skip_next=1 ;;
      --force | --force-with-lease* | --force-if-includes) force=1 ;;
      --delete) delete=1 ;;
      --mirror) block "a --mirror push rewrites every branch, protected ones included." ;;
      --*) ;;
      -*)
        [[ $token == *f* ]] && force=1
        [[ $token == *d* ]] && delete=1
        ;;
      *)
        if [ -z "$remote" ]; then remote=$token; else refspecs+=("$token"); fi
        ;;
    esac
  done

  [ ${#refspecs[@]} -gt 0 ] || refspecs=("$(current_branch)")

  local spec dst spec_force
  for spec in "${refspecs[@]}"; do
    spec_force=$force
    [[ $spec == +* ]] && spec_force=1 && spec=${spec#+}
    dst=${spec##*:}
    [ "$dst" = HEAD ] || [ -z "$dst" ] && dst=$(current_branch)
    dst=${dst#refs/heads/}
    is_protected "$dst" || continue

    ((spec_force)) && block "force push to protected branch '$dst'. Push a branch and open a pull/merge request instead."
    ((delete)) && block "deleting protected branch '$dst'."
    if [ "$(cfg '.guards.allowDirectPush' false)" != true ]; then
      block "direct push to protected branch '$dst'. Branch off it and open a pull/merge request, or ask the user to push it themselves (guards.allowDirectPush in .claude/harness.json turns this off)."
    fi
  done
}

check_rm() {
  # $@: the tokens after `rm`.
  local recursive=0 token targets=()
  for token in "$@"; do
    case "$token" in
      --no-preserve-root) block "rm --no-preserve-root." ;;
      --recursive) recursive=1 ;;
      --*) ;;
      -*) [[ $token == *[rR]* ]] && recursive=1 ;;
      *) targets+=("$token") ;;
    esac
  done
  ((recursive)) || return 0
  for token in "${targets[@]}"; do
    case "$token" in
      / | /\* | \~ | \~/ | \~/\* | '$HOME' | '$HOME/' | '$HOME/*' | '${HOME}' | '${HOME}/' | . | ./ | .. | ../ | \*)
        block "recursive rm of '$token'. Name the exact paths to delete."
        ;;
    esac
  done
}

while IFS= read -r segment; do
  read -ra tokens <<<"$segment"
  # Strip quotes so "$HOME" and '/' compare as written.
  for i in "${!tokens[@]}"; do
    tokens[i]=${tokens[i]//\"/}
    tokens[i]=${tokens[i]//\'/}
  done
  [ ${#tokens[@]} -gt 0 ] || continue
  [ "${tokens[0]}" = sudo ] && tokens=("${tokens[@]:1}")
  [ ${#tokens[@]} -gt 0 ] || continue

  case "${tokens[0]}" in
    rm) check_rm "${tokens[@]:1}" ;;
    git)
      # Skip git's global options (-C <dir>, -c <k=v>, --no-pager...) to the verb.
      i=1
      while [ $i -lt ${#tokens[@]} ]; do
        case "${tokens[i]}" in
          -C | -c | --git-dir | --work-tree) i=$((i + 2)) ;;
          -*) i=$((i + 1)) ;;
          *) break ;;
        esac
      done
      [ "${tokens[i]:-}" = push ] && check_push "${tokens[@]:i+1}"
      ;;
  esac
done <<<"$segments"

exit 0
