# Rollback — PCK-ATLAS-ITER-009

## Restore

```bash
rm tools/atlas-env-audit.sh
rm .project-control/07-critical-tests/CT-ATLAS-ENV-001.sh
rm .project-control/02-regressions/RG-ATLAS-ENV-001.sh
# Revert critical-tests.sh (remove CT-ATLAS-ENV-001)
# Revert test-matrix.json (remove CT-ATLAS-ENV-001)
# Revert oc-bind index.ts and atlas-debug-simulate.ts (remove gateway_node_exec, hint)
rm -rf .project-control/00-ledger/PCK-ATLAS-ITER-009
```
