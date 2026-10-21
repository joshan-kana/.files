# Git and delivery

**Convention:** Keep changes isolated, reviewable, and recoverable. GitHub tracks code and issues; a successful merge does not imply deployment or live validation.

## Working state

Use a separate temporary **detached worktree** based on the intended source revision; leave the normal checkout untouched. Create or switch branches only in the task worktree. Coordinate concurrent edits through the project's existing agent mail workflow or ordinary contributor coordination before overlapping work.

Clean up disposable worktrees, generated helpers, and temporary logs when the task is complete. Do not delete another contributor's work, outstanding branches, intentional artifacts, or recovery material merely to tidy the filesystem.

## Commits, issues, and PRs

- Keep related changes in a focused PR. Separate mechanical refactors from behavior changes where practical.
- Use issues for trackable repository work, with GitHub Projects providing planning metadata, not a second source of task truth.
- Use native issue relationships for real parent/sub-issue or blocked-by dependencies. Do not fabricate relationships.
- A PR intended to land may begin as draft. Move it to ready for review only after checks and conflict reconciliation.
- Use `Closes #N` when merging should close that issue; otherwise use `Refs #N`.
- Rebase and reconcile against the current target branch rather than choosing one side of a conflict without review.
- Do not rewrite published `main` history to amend an old commit. Follow up with a focused fix instead.
- Never merge a PR or commit on `main` without explicit authorization.

## Delivery and deployment

Review the diff, formatter/linter results, evaluated or built outputs, and any necessary runtime validation. Use force-with-lease rather than an unconditional force-push when updating a rebased PR branch.

Deployment should follow the repository's native deployment policy and the affected host's runbook. A PR can be code-complete and reviewable without having been deployed; describe remaining physical/runtime validation honestly.

See the cross-project [GitHub Project Workflow](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/GITHUB_PROJECT_WORKFLOW.md) and [Operating Style](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/OPERATING_STYLE.md) for the authoritative delivery and approval rules.
