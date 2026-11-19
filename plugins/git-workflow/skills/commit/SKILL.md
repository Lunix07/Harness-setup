---
name: commit
description: Write and make a Conventional Commits commit where every line, subject and body alike, is itself a conventional commit, split one commit per theme. Use whenever the user asks to commit, write a commit message, or split changes into commits.
---

# Commit messages

[Conventional Commits](https://www.conventionalcommits.org/), and **every line
is one**: the subject and each body line alike. The log is lifted into release
notes, so a line that cannot stand on its own as a release-note bullet does not
belong in the message.

```
fix(persistence): map unique constraint violations to validation errors
```

```
feat(scripting): select a script version on the detail page

feat(api): return version and created flag from uploads
fix(frontend): make the version selector an island so it hydrates
```

## Project settings

Read `.claude/harness.json` if it exists:

- `commit.types`: the types in use (default `feat`, `fix`, `chore`, `docs`,
  `refactor`, `test`).
- `commit.everyLineConventional`: `false` allows a plain-prose body.
- `commit.beforeCommit`: run it before `git commit` (usually the formatter), so
  the pre-commit hook does not bounce the commit.
- `issues.keyPattern`: when the branch name carries an issue key, put it in the
  subject's scope or at its end, `(KEY-12)`.

## Rules

- Scope optional, lowercase. Subject imperative, no trailing period, about 72
  characters or less.
- **Be brief.** Most commits need no body. Add one only for a separable change,
  and then as further conventional-commit lines, never prose paragraphs.
- Reasoning goes in the pull request, or as a comment next to the code it
  explains. Not into the commit message.
- **Never add a `Co-Authored-By` trailer, a session link or a "Generated with"
  line.** The harness-core guard blocks such a commit.
- Stage paths by name. `git add -A` sweeps in scratch files and secrets.

## One commit per theme

Even when the changes interleave line by line. To split them: snapshot the
working tree to a scratch directory, reduce the tree to one theme, check it
builds, commit, restore the snapshot, repeat. `git add -p` is interactive and
does not work here.

## Before committing

1. `git status` and `git diff --staged --stat`: nothing unintended staged, no
   `.env`, key or credential file.
2. Run `commit.beforeCommit` if set.
3. Commit with a heredoc so line breaks survive:

   ```sh
   git commit -F- <<'MSG'
   feat(api): return version and created flag from uploads
   MSG
   ```

4. If a hook rejects the commit, fix the cause and make a **new** commit. Never
   `--no-verify`, never `--amend` a commit that is already pushed.
