# <Project>

<One paragraph: what this project is, its main parts, and how they talk to each
other.>

## Commands

Always use these, never the bare tool underneath when a task runner exists: the
runner encodes dependency order and caching that a direct call skips.

| Intent       | Command |
| ------------ | ------- |
| Build/check  |         |
| Lint         |         |
| Test         |         |
| Format       |         |
| Run locally  |         |

## Always on

- `<base branch>` is the base branch. Branch off it, merge it in, target it in
  pull requests. Never merge the other direction.
- A defect you find but are not fixing goes in
  [`docs/known_bugs.md`](docs/known_bugs.md), in its area's section, not into the
  branch you are on. Delete the entry when it is fixed.
- A decision the user made goes in [`docs/decisions.md`](docs/decisions.md),
  one dated line. Never ask again what it answers.
- Never let a command dump its full output into the conversation: pipe builds
  and test runs through `tail`/`rg`, or redirect to a scratch file.
- Only add dependencies that are clearly popular. Ask before adding anything
  exotic.

## Where things are

| Area | Path | Read first |
| ---- | ---- | ---------- |
|      |      |            |

## Budget your subagents

- Check [`docs/references/INDEX.md`](docs/references/INDEX.md) first: a code map
  may already answer the question.
- Verify every path before handing it to an agent.
- Ask for `file:line` plus a one-line description, not code excerpts.
- One topic per agent. Run exhaustive greps yourself.
- Pass `model` on every spawn: `haiku` for search (or the `scout` agent),
  `sonnet` for work that follows a written brief, the session model only for
  judgement.

## Further reading

- [docs/known_bugs.md](docs/known_bugs.md): known defects, by area.
- [docs/decisions.md](docs/decisions.md): decisions already made.
- [docs/references/INDEX.md](docs/references/INDEX.md): digests and code maps.
