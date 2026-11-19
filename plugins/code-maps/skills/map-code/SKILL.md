---
name: map-code
description: Investigate one thing in this repository once and write a verifiable code map to the references directory, pinned to git blob hashes so its staleness is checked rather than guessed.
disable-model-invocation: true
context: fork
argument-hint: "[slug] [what to investigate]"
allowed-tools: Bash Read Write Edit Grep Glob
---

# Map a piece of this codebase

Investigate **once**, in this forked context, and leave behind a map small
enough to load whenever it is relevant. The file reads and greps stay here and
end with the fork; only the map reaches disk. This is `/ingest-ref` pointed at
our own code instead of a dependency's docs.

The references directory is `references.dir` in `.claude/harness.json`, default
`docs/references`. Below it is written `<refs>`.

## Input

```
$ARGUMENTS
```

The first whitespace-separated token is the **slug**; everything after it is
**what to investigate**.

```
/map-code user-input how a requestX() call reaches the browser and back
          └─ slug ─┘ └─────────────── what to investigate ───────────┘
```

The slug is lowercase and hyphenated and names the subject, not the task:
`user-input`, not `issue-423`. Ask only when the block above is empty or holds
a slug alone.

## Is it worth a map?

A map earns a file only when re-deriving it needs a sweep across several files.

- **Yes:** how a request travels four layers; which of eight call sites is
  authoritative; the wire shape a generated type gets wrong.
- **No, put it in `CLAUDE.md`:** stable orientation, always true, cheap to
  state. Where a package lives. How a route resolves.
- **No, put it in `.claude/rules/`:** an invariant that belongs to a path glob.
- **No, write nothing:** anything one `rg` answers.

If it overlaps something already in `CLAUDE.md` or a rule, fix that file
instead. A second copy drifts.

## Output

Write `<refs>/map-<slug>.md`:

```markdown
---
kind: code-map
pinned: pending
verified: pending
files:
  - src/…/some_file.rs
  - web/…/some_file.ts
---

# <Title>

## What this covers

Two or three sentences, then what it deliberately omits.

## <One section per layer or concept>

`file:line` plus a one-line description of the shape. No code excerpts unless
the shape is not obvious from the name.

## Wire shapes

The actual JSON, observed. Only if the subject crosses a serialisation boundary.

## Gotchas

What bit us, or what will. This is the section that earns the file.

## Not covered here

What a reader must still go and read.
```

List the paths under `files:` with no hashes; the script fills them in.

## Pin it

```sh
"${CLAUDE_SKILL_DIR}/scripts/map-status.sh" <refs>/map-<slug>.md --pin
```

Hashes are never typed by hand. The pin refuses while a listed file has
uncommitted changes: commit first, or leave the map unpinned and say so. Then
append one row to `<refs>/INDEX.md` (create it with a `| File | Kind | Covers |`
table if missing) as the **final** step.

## Rules

- **Pin the load-bearing files, not every file that mentions the subject.** The
  test: _would a change here falsify a claim this map makes_. A map pinning
  every file that greps for the topic reports churn on every check and gets
  ignored.
- **`file:line` and shapes, not code.** Signatures are free to read from the
  real file and go stale fastest; a hard-won failure mode cannot be re-derived
  at all. Bias the whole map toward the second.
- **Observed wire shapes are worth more than the types they come from.**
  Serialisers and generated bindings disagree in ways no check catches.
- **A gitignored or generated file cannot be pinned.** Pin its source instead.
- **Refresh, do not rewrite.** When the script reports `CHANGED`, read that
  file's diff, correct only the claims it touches, and re-`--pin`. A wholesale
  rewrite throws away the gotchas, which are the parts that never went stale.
- If the map contradicts the code, the code wins; then fix the map.
