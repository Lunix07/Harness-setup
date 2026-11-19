#!/usr/bin/env bash
# Report whether a code map in docs/references/ still describes the code.
#
# Each map pins the git blob hash of every file its claims depend on. An
# identical hash proves the file is byte-identical, so nothing needs re-reading;
# only a file whose hash moved is worth a diff. `--pin` stamps the hashes from
# HEAD, so they are never typed by hand.
#
# Exit: 0 = fresh, 1 = something moved, 2 = the map or the arguments are wrong.

set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2

MAP=""
PIN=0
for arg in "$@"; do
  case "$arg" in
    --pin) PIN=1 ;;
    -h | --help)
      sed -n '2,9p' "$0" | sed 's/^# \?//'
      echo
      echo "Usage: map-status.sh <docs/references/map-*.md> [--pin]"
      exit 0
      ;;
    -*)
      echo "unknown option: $arg" >&2
      exit 2
      ;;
    *) MAP="$arg" ;;
  esac
done

[ -n "$MAP" ] || {
  echo "Usage: map-status.sh <docs/references/map-*.md> [--pin]" >&2
  exit 2
}
[ -f "$MAP" ] || {
  echo "no such map: $MAP" >&2
  exit 2
}

# --- frontmatter ----------------------------------------------------------
# Everything between the leading `---` and the next one. Deliberately parsed
# with awk: yq is not a tool this repository expects to be installed.
front=$(awk 'NR==1 && $0!="---" {exit 1} NR>1 && $0=="---" {exit} NR>1 {print}' "$MAP")
[ -n "$front" ] || {
  echo "$MAP has no frontmatter" >&2
  exit 2
}

pinned=$(printf '%s\n' "$front" | sed -n 's/^pinned:[[:space:]]*\([0-9a-f]\{7,\}\).*/\1/p')

# `  - <blob> <path>` or, before the first pin, a bare `  - <path>`.
entries=$(printf '%s\n' "$front" |
  awk '/^files:/ {f=1; next} f && /^[[:space:]]+-[[:space:]]/ {sub(/^[[:space:]]+-[[:space:]]+/, ""); print; next} f {f=0}')
[ -n "$entries" ] || {
  echo "$MAP lists no files: in its frontmatter" >&2
  exit 2
}

declare -A want=()
paths=()
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  first=${entry%% *}
  if [ "$first" != "$entry" ] && [[ $first =~ ^[0-9a-f]{7,40}$ ]]; then
    path=${entry#* }
    want[$path]=$first
  else
    path=$entry
    want[$path]=""
  fi
  paths+=("$path")
done <<<"$entries"

# --- current state, two git calls for the whole file set ------------------
declare -A have=()
while read -r _mode _type hash path; do
  have[$path]=${hash:0:12}
done < <(git ls-tree HEAD -- "${paths[@]}")

# ls-tree sees only HEAD, so uncommitted work is invisible without this.
declare -A dirty=()
while IFS= read -r line; do
  [ -n "$line" ] || continue
  dirty[${line:3}]=${line:0:2}
done < <(git status --porcelain -- "${paths[@]}")

# --- pin ------------------------------------------------------------------
if [ "$PIN" -eq 1 ]; then
  if [ ${#dirty[@]} -gt 0 ]; then
    echo "refusing to pin: uncommitted changes to files this map lists" >&2
    for p in "${!dirty[@]}"; do echo "  ${dirty[$p]} $p" >&2; done
    echo "Pinning now would record HEAD hashes for content that is not what you read." >&2
    exit 2
  fi

  missing=()
  for p in "${paths[@]}"; do [ -n "${have[$p]:-}" ] || missing+=("$p"); done
  if [ ${#missing[@]} -gt 0 ]; then
    echo "refusing to pin: not in HEAD" >&2
    for p in "${missing[@]}"; do echo "  $p" >&2; done
    exit 2
  fi

  block=$(git ls-tree HEAD -- "${paths[@]}" | awk '{print "  - " substr($3,1,12) " " $4}')
  head_commit=$(git rev-parse --short=12 HEAD)
  today=$(date +%F)

  tmp=$(mktemp) || exit 2
  awk -v pinned="$head_commit" -v verified="$today" -v block="$block" '
    NR==1 && $0=="---" { fm=1; print; next }
    fm==1 && $0=="---" { fm=2; print; next }
    fm==1 {
      if ($0 ~ /^files:/)              { print "files:"; print block; infiles=1; next }
      if (infiles && $0 ~ /^[[:space:]]+-[[:space:]]/) { next }
      infiles=0
      if ($0 ~ /^pinned:/)   { print "pinned: " pinned;   next }
      if ($0 ~ /^verified:/) { print "verified: " verified; next }
      print; next
    }
    { print }
  ' "$MAP" >"$tmp" && mv "$tmp" "$MAP"

  echo "pinned ${#paths[@]} file(s) at $head_commit"
  exit 0
fi

# --- report ---------------------------------------------------------------
[ -n "$pinned" ] || {
  echo "$MAP has no pinned: commit; run with --pin" >&2
  exit 2
}

stale=0
for p in "${paths[@]}"; do
  if [ -n "${dirty[$p]:-}" ]; then
    echo "DIRTY   $p  (${dirty[$p]}, uncommitted)"
    stale=1
  elif [ -z "${have[$p]:-}" ]; then
    echo "MOVED   $p  (not in HEAD; try: git log --follow --diff-filter=RD -- $p)"
    stale=1
  elif [ -z "${want[$p]}" ]; then
    echo "UNPINNED $p  (run with --pin)"
    stale=1
  elif [ "${have[$p]:0:${#want[$p]}}" != "${want[$p]}" ]; then
    echo "CHANGED $p"
    git diff --stat "$pinned" HEAD -- "$p" | sed 's/^/        /'
    stale=1
  fi
done

if [ "$stale" -eq 0 ]; then
  echo "FRESH   ${#paths[@]} file(s) byte-identical to $pinned; trust the map, read nothing"
  exit 0
fi

echo
echo "Re-read only what is listed above: git diff $pinned HEAD -- <path>"
echo "Then correct the claims that diff touches and re-run with --pin."
exit 1
