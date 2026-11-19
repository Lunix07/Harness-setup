---
name: harness-init
description: Set a project up for this harness - write .claude/harness.json (base branch, forge, issue tracker, required tools, post-edit checks, guards) and create the missing project memory files (CLAUDE.md sections, docs/known_bugs.md, docs/decisions.md, docs/references/INDEX.md). Use when the user wants a repository set up, onboarded or initialised for Claude, or asks to configure the harness for a project.
disable-model-invocation: true
argument-hint: "[--check]"
---

# Set a project up for the harness

Adds what is missing and **never overwrites** what is there. Running it twice is
safe; the second run reports "nothing to do".

`$ARGUMENTS` = `--check`: report what is missing or stale and change nothing.

## 1. Detect

From the project root, without asking:

- **Stack and tools:** `Cargo.toml` → `cargo`; `deno.json(c)` → `deno`;
  `package.json` → the package manager its lockfile names; `pyproject.toml` →
  `uv` or `python`; `go.mod` → `go`; `moon.yml`/`.moon/` → `moon`; `justfile` →
  `just`; `treefmt.toml` → `treefmt`. A task runner, if present, is what the
  checks and the CLAUDE.md command table go through.
- **Forge:** `git remote get-url origin`. `github.com` → `github`; a host with a
  usable `glab` (`glab api projects/:id`) → `gitlab`.
- **Base branch:** `git symbolic-ref refs/remotes/origin/HEAD`, else `main`.
- **Existing harness files:** `.claude/harness.json`, `CLAUDE.md`,
  `CLAUDE.local.md`, `.claude/settings.json`, `.claude/rules/`, `docs/`.

## 2. Ask only what detection cannot answer

One `AskUserQuestion` call, at most three questions, each with the detected
value as the recommended option:

- the issue tracker (`github`, `gitlab`, `youtrack`, `linear`, `jira`, `none`)
  and, if it uses keys, the key pattern (`LAB-[0-9]+`);
- whether pushes straight to the base branch are allowed here (a solo repo: yes;
  a team repo: no);
- which post-edit check to run, from the commands detected (a type-check is the
  usual pick; a full test suite is too slow for every edit).

## 3. Write `.claude/harness.json`

Start from [templates/harness.json](templates/harness.json); the full reference
is `docs/config.md` in the harness repository. Keep only keys whose value
differs from the default or that a skill needs to read. A `postEdit` command
must finish in seconds and must be the project's own task runner when there is
one.

If the file exists: merge new keys in, change no existing value, show the diff.

## 4. Create the memory files that are missing

Each from its template in [templates/](templates/), only if absent:

| File                           | Template             | Holds                                         |
| ------------------------------ | -------------------- | --------------------------------------------- |
| `CLAUDE.md`                    | `CLAUDE.md`          | Commands, always-on rules, where things are   |
| `docs/known_bugs.md`           | `known_bugs.md`      | Defects found and not fixed, by area          |
| `docs/decisions.md`            | `decisions.md`       | One dated line per decision a user made       |
| `docs/references/INDEX.md`     | `references-INDEX.md`| Digests and code maps (code-maps plugin)      |

When `CLAUDE.md` exists, do not rewrite it. Compare it with the template's
sections and **offer** the missing ones as a diff; add them only on a yes.

Fill the `CLAUDE.md` command table from what step 1 found, verified by running
`<runner> --help` or listing the tasks. A command you did not see work is not
written down.

## 5. Report

A short list: what was created, what was merged, what was left alone, and the
one or two things the user should fill in by hand (usually the "Where things
are" table). Suggest `.claude/settings.local.json` and `CLAUDE.local.md` go in
`.gitignore` if they are not.
