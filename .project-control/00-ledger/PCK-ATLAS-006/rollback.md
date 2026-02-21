# Rollback — PCK-ATLAS-006

## Failure Modes Addressed

- **ATLAS_ROOT_INVALID**: Path does not exist or lacks package.json → return before spawn
- **SPAWN_FAILED_ENOENT**: spawn throws ENOENT → classify with node_bin_used, gateway_node_exec, atlas_root_value
- **BINARY_NOT_EXECUTABLE**: fs.access(X_OK/R_OK) before spawn

## Fix Strategy

- process.execPath as #2 in node resolution (after NODE_BIN, before /opt/homebrew)
- ATLAS_ROOT validation before any spawn
- Spawn error handler: map ENOENT to SPAWN_FAILED_ENOENT with evidence

## Restore

```bash
# oc-bind: revert atlas-adapter.ts, index.ts
# atlas-radar: rm tools/atlas-root-discovery.sh tools/atlas-acceptance-ATLAS-005.sh
# rm .project-control/00-ledger/PCK-ATLAS-006
# rm .project-control/02-regressions/RG-ATLAS-005-*.sh
```
