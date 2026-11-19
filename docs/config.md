# `.claude/harness.json` reference

One file per project, checked in, read by the harness-core hooks and the
git-workflow and code-maps skills. Every key is optional; the default applies
when a key, the file, or `jq` is missing.

| Key                         | Default                         | Read by                    | Meaning                                                                                                                  |
| --------------------------- | ------------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `baseBranch`                | `main`                          | git-workflow               | Branch off it, merge it in, target it                                                                                    |
| `forge`                     | from `origin`'s URL             | open-pr, review-pr         | `github` or `gitlab`                                                                                                     |
| `tools`                     | `[]`                            | check-tools hook           | CLI tools this project expects, on top of `git`, `jq`, `rg`                                                              |
| `issues.tracker`            | `none`                          | start-issue                | `github`, `gitlab`, `youtrack`, `linear`, `jira`, `none`. The last three go through their MCP server                     |
| `issues.keyPattern`         | `""`                            | start-issue, commit, review-pr | Extended regex for an issue key, e.g. `PROJ-[0-9]+`                                                                  |
| `issues.branchTemplate`     | `feature/{key}-{slug}`          | start-issue                | `{key}` issue key, `{slug}` short title                                                                                  |
| `issues.agentTag`           | unset                           | start-issue                | Tag or label added to issues an agent works                                                                              |
| `commit.types`              | `feat fix chore docs refactor test` | commit                 | Conventional Commit types in use                                                                                         |
| `commit.everyLineConventional` | `true`                       | commit                     | `false` allows a prose body                                                                                              |
| `commit.beforeCommit`       | unset                           | commit                     | Command to run before committing, usually the formatter                                                                  |
| `guards.protectedBranches`  | `["main", "master"]`            | guard-bash hook            | No force push or deletion, ever                                                                                          |
| `guards.allowDirectPush`    | `false`                         | guard-bash hook            | `true` lets a plain push to a protected branch through (solo repos)                                                      |
| `guards.forbidAttribution`  | `true`                          | guard-bash hook            | Block commits carrying `Co-Authored-By`, a `claude.ai/code` link or "Generated with Claude"                              |
| `postEdit[]`                | `[]`                            | post-edit hook             | `{ "glob": "*.ts", "command": "deno check {file}" }`. `glob` is a bash pattern on the project-relative path (`*` crosses `/`); `{file}` is that path, shell-quoted; runs from the project root; must finish in seconds |
| `references.dir`            | `docs/references`               | code-maps                  | Where digests, code maps and their `INDEX.md` live                                                                       |

## Trust

`postEdit` and `commit.beforeCommit` are commands from the project's own
checked-in file. Claude Code only runs in a folder after you trust it, and the
same trust already lets a project's `.claude/settings.json` define hooks, so
this adds no new exposure. Still: read `.claude/harness.json` before trusting a
repository you did not write.
