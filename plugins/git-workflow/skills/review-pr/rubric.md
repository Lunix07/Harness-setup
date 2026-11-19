# Review criteria

Five criteria, always all five. An item a change does not touch is skipped
silently. Language idioms and house rules live in the project's
`.claude/review-rubric.md`, read after this file.

## 1. The issue is addressed

- Every requirement in the issue, and every item of its verification steps, maps
  to a hunk or a test in the diff, or the PR description says why it is out of
  scope.
- Where the PR corrects the issue (a wrong count, a stale `file:line`, a premise
  that did not hold), the description says so.
- If the issue came from `docs/known_bugs.md`, the entry is deleted in the diff.
- The tests the issue asks for exist and test the behaviour, not the
  implementation.

## 2. No unforeseen side effects

- **Callers.** For every changed public item, `rg` its callers outside the diff
  and check each still means what it did.
- **Wildcards.** A new enum variant or union member is silently absorbed by
  every catch-all match arm, `default:` case and fallback branch. `rg` them; the
  compiler only catches the exhaustive ones.
- **Wire and storage.** A changed serialised shape, persisted record, API
  payload, migration or generated binding breaks data already stored or a peer
  already deployed. It needs a migration path or an explicit note in the PR.
- **Concurrency and lifetimes.** A stream, subscription, retry loop or
  background task: does it end, back off, report failure, and get cleaned up?
- **Docs drift.** A `file:line`, a count or a table row in `docs/`, a
  `CLAUDE.md` or a rule that the diff made false.
- **Scope.** A change unrelated to the issue belongs on its own branch.

## 3. Developer experience

- An error says what went wrong and with which input, so a caller can act on it
  without reading the source.
- A public name says what the item does; a reader of the call site does not need
  the definition.
- A new concept is findable from a `CLAUDE.md`, a rule or `docs/`. Nothing a
  later contributor must know lives only in the PR.
- Project tasks run through the project's task runner, as its `CLAUDE.md` says.

## 4. Code a human can follow

- A function fits in one reading. One that needs scrolling, or a comment to
  explain its phases, wants splitting into named steps.
- Names carry the meaning; a comment is for a non-obvious _why_, never a
  narration of _what_.
- Control flow is the plainest that works: early returns over nesting, a match
  over a chain of conditionals, no trick where a loop reads better.
- Generic parameters have role names (`State`, `Result`), not single letters,
  outside narrow local utilities.

## 5. Clean code

- Domain enums are matched exhaustively; a wildcard needs a reason.
- Errors are propagated and typed; no swallowed errors, no panics or unchecked
  unwraps outside tests and provably infallible spots.
- Logic exists once: a second copy of a conversion, a helper or a match is a
  finding.
- No dead code, no commented-out code, no TODO without an issue.
- A UI change uses the project's existing components before hand-making one.
