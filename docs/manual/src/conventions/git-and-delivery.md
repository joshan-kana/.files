# Git and delivery

Keep changes isolated, reviewable, and recoverable. Follow the [GitHub project workflow](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/GITHUB_PROJECT_WORKFLOW.md) for issue, project, and pull-request relationships.

## Working changes

Use a topic branch for changes intended for review. Keep unrelated changes separate, coordinate overlapping edits, and preserve existing work when reconciling changes. Do not include temporary or generated artifacts in a change unless they are intentional deliverables.

## History and review

- Keep a pull request focused on one coherent change. Separate mechanical moves from behavioral changes where practical.
- Use repository issues to record trackable work, native relationships for true dependencies, and project fields for workflow metadata.
- Draft PRs are appropriate while implementation or verification remains incomplete. Mark ready only when reviewable and sufficiently validated.
- Link closing issues only when the change actually completes them; otherwise record a reference.
- Reconcile with the target branch without discarding concurrent changes. Use lease-protected force pushes after an intentional rebase.
- Preserve published default-branch history; make corrections through reviewable follow-up changes.

## Delivery

Review the diff, affected evaluations, relevant builds, and runtime validation. Delivery and deployment follow their respective operational procedures; a merged PR does not imply live deployment.

Record validation results and remaining limitations in the pull request rather than in permanent convention pages.
