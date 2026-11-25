# Git and delivery

Keep changes isolated, reviewable, and recoverable. Follow the [GitHub project workflow](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/GITHUB_PROJECT_WORKFLOW.md) for issue, project, and pull-request relationships.

## Working changes

Use a topic branch for changes intended for review. Keep unrelated changes separate, coordinate overlapping edits, and preserve existing work when reconciling changes. Do not include temporary or generated artifacts in a change unless they are intentional deliverables.

## History and review

- Keep a pull request focused on one coherent change. Separate mechanical moves from behavioral changes where practical.
- Give each commit a single reviewable purpose.
- Reconcile with the target branch without discarding concurrent changes. Use lease-protected force pushes after an intentional rebase.
- Preserve published default-branch history; make corrections through reviewable follow-up changes.

## Delivery

Review and record the checks described in [validation](validation.md) in the pull request. Deployment follows the applicable operational procedure.
