---
name: start-issue
description: Before the first edit of a piece of work, open or take its issue in the project's tracker and create its branch from a fresh base branch, in a worktree when other work runs in parallel. Use when the user asks to start, implement or pick up a change, feature or fix, or names an issue to work on.
argument-hint: "[issue-key or short description]"
---

# Starting implementation work

Run this **before the first edit**, not after. A branch created afterwards is a
branch created too late.

Read `.claude/harness.json`: `baseBranch` (default `main`), `issues.tracker`,
`issues.keyPattern`, `issues.branchTemplate` (default `feature/{key}-{slug}`),
`issues.agentTag`.

## 1. The issue

`$ARGUMENTS` is an issue key, or a description of the change, or empty.

| `issues.tracker` | Read or create with                                  |
| ---------------- | ---------------------------------------------------- |
| `github`         | `gh issue view <n>` / `gh issue create`              |
| `gitlab`         | `glab issue view <n>` / `glab issue create`          |
| `youtrack`, `linear`, `jira` | that tracker's MCP server, if one is connected |
| `none` or unset  | no issue; the branch is named from the description   |

- A new issue describes the scoped change: what, why, how to verify.
- If it tackles an entry in `docs/known_bugs.md`, end that entry with
  `Tracked as <key>.`
- If `issues.agentTag` is set, add exactly that tag or label. If it is missing
  or cannot be set, stop and say so; do not substitute a similar one.
- Move the issue to "in progress" if the tracker has such a state. Do not assign
  it and do not resolve it.

**If the tracker is unreachable**, say so. **Never invent an issue key** and
never name a branch after an issue that does not exist.

## 2. Worktree or the main checkout

Decide before branching. `git worktree list` and the user's words say whether
other work runs in parallel.

- **Nothing else runs:** branch in the main checkout.
- **Another session or agent works in this repository, or the user says so:**
  branch into a worktree (`EnterWorktree`, or `git worktree add`) so two
  sessions never switch branches under each other. Build caches are per
  worktree; check free disk space before a heavy build.

Unsure: ask in one line, do not guess.

## 3. The branch

```sh
git fetch origin <base>
git switch -c <branch> origin/<base>
```

`<branch>` from `issues.branchTemplate`: `{key}` the issue key (or dropped with
its separator when there is none), `{slug}` three to five lowercase hyphenated
words from the title.

Only now start editing.

## After the pull request

- Once it is open, move the issue to the tracker's review state, if any.
- After the user merges it, close the issue with a comment naming the pull
  request and the merge commit, then clean up:
  - this work's worktree: `git worktree remove <path>`, then `git branch -D`;
  - any other worktree whose branch is merged into `origin/<base>`;
  - leave alone a `locked` worktree (an agent runs in it) and one with
    uncommitted or unpushed work: name it to the user instead.

## Exceptions

Explicit user instructions override this sequence. If the user says to work on
the current branch, do that.
