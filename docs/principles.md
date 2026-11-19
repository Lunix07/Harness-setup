# Design principles

Why the harness looks the way it does. Each rule came from a session that went
wrong without it.

## Context is the budget

- **A skill's description is always loaded; its body only when it fires.** Put
  the trigger conditions in the description and everything else in the body or
  in files next to it. `claude plugin details <plugin>` shows the always-on cost.
- **Investigate once, keep the result, and make staleness checkable.** A code
  map pinned to blob hashes costs one script call to trust; re-deriving it costs
  40 to 100k tokens. A digest without a pin is a guess.
- **Fork the expensive readers.** `/map-code`, `/ingest-ref` and `/review-pr`
  run with `context: fork`: the file reads end with the fork, the main session
  gets a dozen lines.
- **Pick the cheapest model that can do the job.** Search is `scout` on Haiku.
  The session model is for judgement.

## Mechanism over instruction

- **A rule a hook can enforce goes in a hook.** "Never force-push main" in a
  CLAUDE.md is a request; in `guard-bash.sh` it is a fact. Prose is for what
  needs judgement.
- **A hook explains itself.** Exit 2 with a reason on stderr, so Claude changes
  course instead of retrying the same call.
- **Feedback at the moment of the mistake.** A type error reported by
  `post-edit.sh` right after the edit costs one fix; found at commit time it
  costs a re-read of everything since.
- **Hooks are seatbelts, not sandboxes.** They catch honest mistakes. Permission
  rules and review remain the defence against anything deliberate.

## Portable by configuration

- **Nothing project-specific in a skill body.** Branch names, trackers, forges,
  commands and paths come from `.claude/harness.json`, with defaults that work
  without it.
- **Plugins stand alone.** Each one works installed without the others.
- **Never overwrite what a project already has.** `/harness-init` adds missing
  files and offers missing sections as a diff.

## The project's memory lives in the project

Four files carry what a session learns, so the next one starts from it:

| File                        | Holds                                                    |
| --------------------------- | -------------------------------------------------------- |
| `CLAUDE.md`                 | How to build and test, always-on rules, where things are |
| `docs/known_bugs.md`        | Defects seen and not fixed, by area                      |
| `docs/decisions.md`         | Decisions the user made: never asked twice               |
| `docs/references/INDEX.md`  | Digests and code maps                                    |

## Tested like code

- Hooks have table tests (`tests/hooks/run.sh`): a guard that blocks the wrong
  thing stalls every session, and one that blocks nothing is worse than none.
- Skills have trigger evals (`plugins/*/evals/`): a skill whose description
  does not fire on the prompts it is for does not exist.
- `scripts/validate.sh` runs all of it, plus manifest, version and privacy
  checks, locally and in CI.
