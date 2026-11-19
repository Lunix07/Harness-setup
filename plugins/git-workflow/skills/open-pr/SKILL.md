---
name: open-pr
description: Open or update a pull request (GitHub) or merge request (GitLab) for the current branch against the project's base branch, with gh, glab, or git push options when glab is unusable. Use when the user asks to open, create, raise or update a PR/MR, or to push the work for review.
---

# Opening a pull or merge request

Read `.claude/harness.json`: `baseBranch` (default `main`) and `forge`. Without
`forge`, `git remote get-url origin` decides: `github.com` is GitHub, anything
else is tried as GitLab.

## Before pushing

- The branch is not the base branch. If it is, stop: `/start-issue` first.
- `git fetch origin <base>`; if the branch is behind, merge `origin/<base>` in.
  Never merge the other direction.
- Pushing runs the project's pre-push hook; let it run.

## The description

This is where the reasoning goes; it is deliberately kept out of the commit
messages. Write it to a scratch file:

```markdown
<What changed and why, two or three sentences.>

Closes <issue key or URL>.

## How to verify
- <steps a reviewer can follow>

## Out of scope
- <what was deliberately left out, and where it is recorded>
```

**No `Co-Authored-By`, no session link, no "Generated with" line.**

## GitHub

```sh
git push -u origin HEAD
gh pr create --base <base> --title "<conventional-commit subject>" --body-file <file>
```

Update an open one with `gh pr edit <n> --title/--body-file`. Checks:
`gh pr checks <n>`, logs: `gh run view <run-id> --log-failed`.

## GitLab with `glab`

`glab` is usable when `command -v glab && glab api projects/:id` both succeed.
Do not judge by `glab auth status`: a repo-scoped token answers it with 403 and
still works for every call below.

```sh
git push -u origin HEAD
glab mr create --source-branch "$(git branch --show-current)" \
  --target-branch <base> --remove-source-branch \
  --title "<subject>" --description "$(cat <file>)" --yes
```

Update with `glab mr update <iid> --title/--description`. Pipelines:
`glab ci view`, `glab ci trace <job>`, or
`glab api "projects/:id/pipelines?ref=<branch>"` when the branch name has a `#`.

## GitLab without `glab`: push options

```sh
git push -o merge_request.create -o merge_request.target=<base> \
  -o merge_request.title="<subject>" \
  -o merge_request.description="<one line>" origin HEAD
```

To change an open merge request, put the same `merge_request.*` options on a
later push without `merge_request.create`. Push options only ride on a push
that moves the ref, so it needs a new commit, and they carry no newlines: the
description stays one line.

## After

- Give the user the link.
- When the checks are green, `/review-pr <number>` reviews it.
- If working out how existing code behaved cost real effort on this branch,
  offer the user a filled-in `/map-code <slug> <subject>` line (code-maps
  plugin): it is the last moment that knowledge is free.
