# harness-setup

A Claude Code plugin marketplace: `.claude-plugin/marketplace.json` lists the
plugins under `plugins/`. Each plugin is `.claude-plugin/plugin.json` plus any
of `skills/<name>/SKILL.md`, `agents/*.md`, `hooks/hooks.json`, `evals/`.

## Commands

| Intent                         | Command                                     |
| ------------------------------ | ------------------------------------------- |
| Validate everything            | `scripts/validate.sh`                       |
| Hook tests only                | `tests/hooks/run.sh`                        |
| Try a plugin without installing | `claude --plugin-dir plugins/<name>`        |
| Skill trigger evals            | `claude plugin eval plugins/<name>`         |
| Always-on token cost           | `claude --plugin-dir plugins/<name> plugin details <name>` |

Run `scripts/validate.sh` before every commit.

## Always on

- **This repository is public.** No email addresses, employer or customer
  names, internal URLs, hostnames or tokens, in files or commit messages.
  `validate.sh` scans for emails and for the words in the gitignored
  `.privacy-denylist`.
- **Every change gets a CHANGELOG.md line under `Unreleased`**, in its plugin's
  section. Versions are bumped at release, in `plugin.json` and the marketplace
  entry together. See "Versioning" in the README for patch/minor/major.
- **Nothing project-specific in a skill.** A value that differs between projects
  is a `.claude/harness.json` key with a default, documented in
  `docs/config.md`.
- **Scripts bundled with a skill** are referenced as `${CLAUDE_SKILL_DIR}/...`
  (or `${CLAUDE_PLUGIN_ROOT}/...` from another skill of the same plugin), never
  by a path inside some project's `.claude/`.
- **Hooks:** bash plus `jq`, degrade to a no-op without `jq`, exit 2 with the
  reason on stderr to block. A new hook behaviour gets cases in
  `tests/hooks/run.sh` in the same change.
- **A new model-invoked skill gets an eval case** in its plugin's `evals/` that
  checks it fires.
- Commits are Conventional Commits, every line one, no attribution trailers.
- The README's component tables describe every skill, hook and agent. Adding
  one without its row is unfinished work.
