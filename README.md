# harness-setup

My personal [Claude Code](https://code.claude.com) harness: the skills, hooks,
agents and project conventions I want in every repository I work in, packaged as
a plugin marketplace so any project can install the parts it needs in two
commands.

It is opinionated: issue first, then a branch, then the edit; Conventional
Commits; no AI attribution in history; investigate once and keep a verifiable
map; spend tokens on judgement, not on re-reading.

## Contents

| Plugin                                     | What it gives a project                                                                                                        |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| [`harness-core`](plugins/harness-core)     | Guard hooks, a missing-tool check, a configurable post-edit check, the `scout` search agent, and `/harness-init`               |
| [`git-workflow`](plugins/git-workflow)     | `/start-issue`, `/commit`, `/open-pr`, `/review-pr`, for GitHub and GitLab                                                     |
| [`code-maps`](plugins/code-maps)           | `/map-code`, `/ingest-ref` and the `reference` skill: knowledge digests whose staleness is checked by git blob hashes          |
| [`mentor`](plugins/mentor)                 | `engineering-mentor`: answers that explain one layer below the abstraction and name the principle that transfers               |

Every plugin is independent: install `git-workflow` alone and it works, it just
reads its settings from defaults instead of `.claude/harness.json`.

## Install

Requirements: Claude Code, `git`, `jq` and `rg` (ripgrep). `gh` for GitHub
projects, `glab` for GitLab projects (optional there: push options work
without it). `shellcheck` to work on this repository.

**Once per machine**, add the marketplace:

```text
/plugin marketplace add Lunix07/Harness-setup
```

(or `/plugin marketplace add ~/Desktop/claude-harness` to use a local checkout
while developing it).

**Per project**, install what it needs, then set it up:

```text
/plugin install harness-core@harness-setup
/plugin install git-workflow@harness-setup
/plugin install code-maps@harness-setup
/harness-init
```

Choose the scope when installing: **user** (every project on this machine),
**project** (written to the repo's `.claude/settings.json`, so teammates are
offered it too) or **local** (this repo, only for you).

**Updating:** `/plugin marketplace update harness-setup`, then restart Claude
Code. Pin a project to a release by adding the marketplace at a tag
(`Lunix07/Harness-setup#harness-core--v0.1.0`).

## Components

### harness-core

**Hooks** (all read `.claude/harness.json`, all fall back to defaults without it):

| Hook                   | Event                         | Does                                                                                                                                                                                                                                                         |
| ---------------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `check-tools.sh`       | SessionStart                  | Names the expected CLI tools that are not on `PATH` (`git`, `jq`, `rg` plus the project's `tools`), so Claude does not plan around them                                                                                                                      |
| `guard-bash.sh`        | PreToolUse `Bash`             | Blocks commits carrying `Co-Authored-By`/session links; force pushes, deletions and (unless allowed) direct pushes to protected branches; recursive `rm` of `/`, `~`, `$HOME`, `.`, `..`. The reason goes back to Claude so it changes course |
| `post-edit.sh`         | PostToolUse `Edit\|Write`     | Runs the project's `postEdit` checks on the edited file (type-check, lint) and feeds failures back to Claude immediately                                                                                                                                      |

**Agent** `scout` (Haiku, read-only): "where is X", answered as `file:line` plus
one line each. The cheap default for search, so the session model is spent on
judgement.

**Skill** `/harness-init`: detects the stack, forge and base branch, asks at
most three questions, writes `.claude/harness.json`, and creates whichever of
`CLAUDE.md`, `docs/known_bugs.md`, `docs/decisions.md`,
`docs/references/INDEX.md` are missing. Never overwrites; `--check` only
reports.

### git-workflow

| Skill          | Triggers on                                     | Does                                                                                                                         |
| -------------- | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `/start-issue` | "start/implement/pick up X"                     | Opens or takes the issue (GitHub, GitLab, or a tracker MCP), branches from a fresh base, in a worktree if work runs in parallel |
| `/commit`      | "commit this"                                   | Conventional Commits where every line is one, one commit per theme, the project's pre-commit command first                   |
| `/open-pr`     | "open a PR/MR"                                  | Pushes and opens or updates the PR with `gh`, `glab`, or GitLab push options                                                  |
| `/review-pr N` | "review PR N"                                   | Forked review against the issue and a five-criterion rubric (plus the project's `.claude/review-rubric.md`); inline comments and one summary; never approves |

### code-maps

| Skill                       | Does                                                                                                                                                                        |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/map-code <slug> <what>`   | Investigates once in a forked context, writes `docs/references/map-<slug>.md` and pins the git blob hash of every load-bearing file. User-invoked only                         |
| `/ingest-ref <source> <slug>` | Reads a URL, file or article once and writes a version-pinned digest. User-invoked only                                                                                    |
| `reference`                 | Model-invoked: checks the index before exploring, verifies a map with `map-status.sh` (`FRESH` means read nothing), and offers a filled-in `/map-code` line after expensive investigations |

### mentor

`engineering-mentor`: classifies a question (mechanical, conceptual, complex,
urgent) and teaches only as much as that deserves: one layer below the
abstraction, then the general principle and where else it shows up.

## Configuration

One file per project, `.claude/harness.json`, written by `/harness-init` and
read by the hooks and skills. Every key is optional. Full reference:
[docs/config.md](docs/config.md).

```json
{
  "baseBranch": "main",
  "forge": "github",
  "tools": ["deno", "cargo"],
  "issues": { "tracker": "github", "keyPattern": "", "branchTemplate": "feature/{key}-{slug}" },
  "commit": { "types": ["feat", "fix", "chore"], "beforeCommit": "deno fmt" },
  "guards": { "protectedBranches": ["main"], "allowDirectPush": false },
  "postEdit": [{ "glob": "*.ts", "command": "deno check {file}" }]
}
```

## Working on this repository

```sh
scripts/validate.sh                       # everything below, plus manifests, versions, frontmatter, privacy
tests/hooks/run.sh                        # hook table tests
claude --plugin-dir plugins/harness-core  # try a plugin without installing it
claude plugin eval plugins/git-workflow   # do the skills trigger on the prompts they should?
```

Design rules and the reasoning behind them: [docs/principles.md](docs/principles.md).
Conventions for changing things: [CLAUDE.md](CLAUDE.md).

### Versioning

Each plugin has its own [semver](https://semver.org) version, in its
`plugin.json` **and** its marketplace entry (`validate.sh` fails when they
differ).

- **patch**: wording, a fixed bug, a tightened check that blocks nothing new;
- **minor**: a new skill, hook, agent or config key;
- **major**: a removed or renamed skill, a config key whose meaning changed, a
  guard that now blocks something it allowed.

Every change gets a line under `Unreleased` in [CHANGELOG.md](CHANGELOG.md). To
release: move the lines under the new version, bump both version fields, commit,
then `claude plugin tag plugins/<name>` (creates `<name>--v<version>`) and push
the tag.
