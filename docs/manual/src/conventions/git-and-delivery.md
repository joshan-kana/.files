# Git and delivery

Keep changes isolated, reviewable, and recoverable. Follow the [GitHub project workflow](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/GITHUB_PROJECT_WORKFLOW.md) for issue, project, and pull-request relationships.

## Working state

Use a separate temporary detached worktree based on the intended revision. Leave the normal checkout untouched and create or switch branches only inside the task worktree. Coordinate overlapping edits through agent mail or the project's established contributor coordination.

Remove disposable worktrees, scratch files, and generated test artifacts after use. Preserve unrelated changes, branches, intentional outputs, and recovery material.

## History and review

- Keep a pull request focused on one coherent change. Separate mechanical moves from behavioral changes where practical.
- Use repository issues to record trackable work, native relationships for true dependencies, and project fields for workflow metadata.
- Draft PRs are appropriate while implementation or verification remains incomplete. Mark ready only when reviewable and sufficiently validated.
- Link closing issues only when the change actually completes them; otherwise record a reference.
- Reconcile with the target branch without discarding concurrent changes. Use lease-protected force pushes after an intentional rebase.
- Do not commit on the primary branch, rewrite its published history, or merge a PR without explicit permission.

## Delivery

Review the diff, affected evaluations, relevant builds, and runtime validation. Delivery and deployment follow their respective operational procedures; a merged PR does not imply live deployment.

Report evidence and outstanding verification plainly, without embedding transient task status in lasting repository documentation.
