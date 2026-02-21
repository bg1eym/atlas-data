# Rollback — PCK-BOOTSTRAP-000

## Restore to Current State

To restore the repository to the state captured at bootstrap:

```bash
git checkout HEAD -- .
```

Or, if a specific commit was tagged at bootstrap:

```bash
git checkout <bootstrap_commit_sha>
```

## Scope

This rollback restores to the git HEAD at the time of PCK-BOOTSTRAP-000 creation. No business logic changes were made during bootstrap; only structural control artifacts were added under `.project-control/`.
