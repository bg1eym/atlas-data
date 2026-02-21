# Rollback — PCK-ATLAS-008

## Failure Modes Addressed

- **ATLAS_ROOT_INVALID**: Path invalid → discovery fallback (single candidate only)
- **ATLAS_PIPELINE_BLOCKED**: exit 42 → classify with evidence fields
- **ATLAS_DEGRADED**: items_count=0 → still return dashboard URL

## Fix Strategy

- atlas-root-discovery.sh outputs JSON (candidates, selected_root, why_selected)
- atlas-adapter: scripts.atlas:run check, discovery fallback, PDF_EXTRACT_ALLOW_FALLBACK=1
- exit 42 → ATLAS_PIPELINE_BLOCKED with stderr_snippet, stdout_snippet, etc.

## Restore

```bash
# oc-bind: revert atlas-adapter.ts
# atlas-radar: revert tools/atlas-root-discovery.sh
# rm .project-control/00-ledger/PCK-ATLAS-008
# rm .project-control/02-regressions/RG-ATLAS-008-*.sh
# rm .project-control/07-critical-tests/CT-ATLAS-008-*.sh
# rm tools/atlas-acceptance-ATLAS-008.sh
```
