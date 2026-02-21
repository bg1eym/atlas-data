# Wiring Snapshot — PCK-ATLAS-006

## Flow

TG → oc-bind /atlas handler → atlas-adapter runAtlasToday() → spawn(node, [pnpm.cjs, "-C", ATLAS_ROOT, "run", "atlas:run"]) → runtime/atlas/run_atlas.ts → result.json → URL 渲染 → TG 回复

## Node Resolution (PCK-ATLAS-006)

1. NODE_BIN env
2. process.execPath (gateway's node) — critical for launchd
3. /opt/homebrew/bin/node, /usr/local/bin/node, /usr/bin/node

## ATLAS_ROOT Validation

- Before spawn: existsSync(root), existsSync(package.json)
- Failure modes: ATLAS_ROOT_INVALID (path missing/lacks package.json)

## Spawn Error Classification

- SPAWN_FAILED_ENOENT: includes node_bin_used, gateway_node_exec, atlas_root_value
- BINARY_NOT_EXECUTABLE: fs.access(X_OK) node, fs.access(R_OK) pnpm.cjs

## Debug (/atlas debug)

- process_execPath, atlas_root_value, atlas_root_exists, atlas_root_has_pkg_json, atlas_root_has_script_atlas_run
- node_bin_used, node_access, pnpm_js_used, pnpm_js_access
- pnpm_version_probe
