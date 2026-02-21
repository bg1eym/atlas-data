# Wiring Snapshot — PCK-ATLAS-ITER-009

## Flow

tools/atlas-env-audit.sh → tools/_out/atlas-env-audit.json → CT-ATLAS-ENV-001 (fails unless root_cause=OK)

## atlas-env-audit.sh

- Collects: openclaw plugin installPath, gateway launchd env (ATLAS_ROOT, ATLAS_DASHBOARD_URL_BASE, ATLAS_COVER_URL_BASE)
- Validates: path exists, package.json exists, scripts.atlas:run exists
- Discovery: search $HOME/Projects and $HOME for repos with atlas:run
- conclusion.root_cause: OK | ATLAS_ROOT_INVALID | ATLAS_ROOT_UNKNOWN | GATEWAY_ENV_MISSING
- conclusion.next_fix: PlistBuddy command to set ATLAS_ROOT

## /atlas debug

- Fields: atlas_root_value, atlas_root_exists, atlas_root_has_pkg_json, atlas_root_has_script_atlas_run, gateway_node_exec
- If atlas_root_exists=false: hint "Run: bash tools/atlas-env-audit.sh"
