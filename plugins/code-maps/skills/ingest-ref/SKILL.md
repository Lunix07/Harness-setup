---
name: ingest-ref
description: Read a dependency's documentation, a URL, a local file or a tracker article once and write a short digest to the references directory, pinned to the dependency version it describes.
disable-model-invocation: true
context: fork
argument-hint: "[source] [slug]"
allowed-tools: WebFetch Read Write Edit Bash
---

# Ingest a reference

Read a source **once**, in this forked context, and leave behind a digest small
enough to load whenever it is relevant. The raw source stays here and is thrown
away; only the digest reaches disk.

The references directory is `references.dir` in `.claude/harness.json`, default
`docs/references`. Below it is written `<refs>`.

## Input

```
$ARGUMENTS
```

The first whitespace-separated token is the **source**, anything after it the
**slug**. The source is one of:

- a URL: fetch it;
- a path in this repository or on disk: read it;
- an article id or title in a tracker or wiki reachable through a connected MCP
  server: resolve it there.

The slug is lowercase, hyphenated, and carries the version when the source is
versioned (`tokio-1.44`, not `tokio`). When only a source was given, derive the
slug and say what you chose. Ask only when the block above is empty.

## Output

Write `<refs>/<slug>.md`:

```markdown
---
source: <URL, path, or article id>
retrieved: <YYYY-MM-DD>
pins: <the exact dependency version this describes, or "n/a">
---

# <Title>

## What this is

Two or three sentences. Why we care, not what the project says about itself.

## The API surface we actually touch

Only what this repository calls (`rg` it). Not the full reference.

## Gotchas

What bit us, or what will. This is the section that earns the file.

## Not covered here

What a reader still has to go to the source for.
```

## Rules

- **Do not reproduce the source at length.** A digest that replaces reading the
  source is a liability, and a stale one is worse than none.
- **Bias toward what bit us.** Signatures go stale fastest and can be read from
  the real source for free; hard-won failure modes cannot be derived.
- Set `pins:` to the exact version the digest describes, read from the
  project's lockfile. A digest without a pin cannot be checked later.
- Append one row to `<refs>/INDEX.md` as the **final** step.
