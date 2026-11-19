---
name: review-pr
description: Review an open pull request (GitHub) or merge request (GitLab) against the issue it resolves and five review criteria, then comment on it - inline threads on the lines to fix, one summary note. Never approves. Use when the user asks to review a PR/MR by number.
context: fork
argument-hint: "[pr-number]"
allowed-tools: Bash Read Grep Glob
---

# Reviewing a pull or merge request

Review **thoroughly, once**, in this forked context. The diff and file reads
stay here; the main session gets the verdict back.

## Input

```
$ARGUMENTS
```

The pull/merge request number, with or without `#`/`!`. Nothing else is needed.

## 1. Collect

```sh
"${CLAUDE_SKILL_DIR}/scripts/pr-context.sh" <number> "${TMPDIR:-/tmp}/review-pr-<number>"
```

It prints an index: forge, title, issue key, head and base sha, check status,
existing review comments, files. Everything lands in the out directory:
`diff.patch`, `files.txt`, `commits.txt`, `comments.txt`, `pr.json`.

- **`cli: unavailable`**: review all the same, report in the conversation only
  (step 6), write nothing to the forge.
- **Checks failed**: say so in the verdict; do not review line by line what CI
  already rejected.

## 2. Understand what was asked

- Read the issue the PR resolves (`gh issue view`, `glab issue view`, or the
  tracker's MCP server). **It is the yardstick:** the PR is judged against what
  the issue asked for, not against what the reviewer would have built.
- Read the PR description in `pr.json`: its out-of-scope notes and corrections
  to the issue count.
- `rg` the project's `docs/decisions.md`, if any, for the area. A choice
  recorded there is not a finding.

## 3. Read the code

- `Read` one file per touched package first (`offset`/`limit` is enough), so its
  `CLAUDE.md` and `.claude/rules/*` load.
- Read touched files **at the PR head**: `git show <head_sha>:<path>`. Never
  check the branch out and never build; CI builds.
- Read the diff hunk by hunk, then each changed item in its whole file: a hunk
  hides what surrounds it.

## 4. Review

Go through all five sections of [rubric.md](rubric.md), then the project's own
`.claude/review-rubric.md` if it exists (language idioms, house rules). Each
finding needs:

- `path:line` at the PR head;
- a severity: `must-fix` (wrong, breaks, or leaves the issue unsolved),
  `should-fix` (works, but a reader or caller pays for it), `nit`;
- **a concrete failure scenario or a concrete replacement.** A finding with
  neither is taste: drop it.

Then check every finding once more, re-reading the cited line. Drop it when an
existing comment (`comments.txt`), `docs/decisions.md`, the issue or the PR
description already settles it.

## 5. Comment

**A finding on an added line** becomes an inline comment:

```sh
"${CLAUDE_SKILL_DIR}/scripts/post-inline.sh" <number> <path> <line> <body-file>
```

The body leads with the severity in bold, states the problem in one sentence,
then the scenario or the replacement (a `suggestion` block when it is a
drop-in). Write it to a scratch file first.

**A finding on an unchanged or removed line**, or one the script refused, goes
into the summary.

**The summary**, always one, last: `gh pr comment <n> --body-file <file>` or
`glab mr note <iid> -m "$(cat <file>)"`.

1. The verdict: `Changes requested` with the count per severity, or
   `Reviewed, no findings`.
2. One line per criterion, saying what was checked against what. For the issue
   criterion, which requirements were traced to which change.
3. The findings that are not inline, with `path:line`.

**Never approve.** Approval stays a human act.

## 6. Report back

To the main session, a dozen lines at most: the verdict and counts by severity,
the link, and, when nothing was posted, every finding with `path:line`,
severity and its one-sentence problem.
