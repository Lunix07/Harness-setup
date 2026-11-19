---
name: reference
description: Check the project's references directory (digests of external docs and pinned code maps) before exploring code or reading a dependency's documentation, and verify a code map's freshness in one script call. Use before spawning an exploration agent, before tracing how a feature works across several files, and before reading a library's docs.
---

# Reference digests and code maps

The references directory (`references.dir` in `.claude/harness.json`, default
`docs/references`) holds two kinds of file: digests of external documentation
somebody already read once, and maps of this codebase somebody already
investigated once. Both exist so nobody pays for that reading twice.

## Index

Read `<refs>/INDEX.md`, then only the row that matches the task. If there is no
index, there are no references; carry on.

## External digests

- Read only the matching row. Loading one that is not relevant is pure cost.
- Check the digest's `pins:` against the lockfile. A digest pinned to a version
  no longer in use is a hint, not a fact.
- **If a digest contradicts the source, the source wins.** Then fix the digest.

## Code maps

A code map (`map-<slug>.md`) pins the git blob hash of every file its claims
depend on, so its staleness is checkable rather than guessable:

```sh
"${CLAUDE_PLUGIN_ROOT}/skills/map-code/scripts/map-status.sh" <refs>/map-<slug>.md
```

- `FRESH`: every pinned file is **byte-identical** to the pinned commit. Trust
  the map and open nothing.
- Otherwise the script names the files that moved, with a diffstat; nothing else
  needs re-reading. `git diff <pinned> HEAD -- <path>` for the detail.
- **If a map contradicts the code, the code wins.** Correct the claims that
  file's diff touches and re-run with `--pin`. Refresh, do not rewrite: the
  gotchas are the parts that did not go stale.

## Offer the index before the work is reported done

`/map-code` and `/ingest-ref` are user-invoked only: a file reaches the
references directory only if the user types the command, and they cannot know
it is worth typing unless told.

Make the offer when a session spawned an exploration agent, traced a path across
three or more packages, surfaced a gotcha written down nowhere, or read a
dependency's docs cold. Close that turn with it, arguments filled in:

> This session traced `<subject>` across `<n>` packages. Worth indexing so it is
> not re-derived? Run:
> `/map-code <slug> <one line naming the code path and both its ends>`

Once per subject, last thing in the turn, dropped without argument if declined.
