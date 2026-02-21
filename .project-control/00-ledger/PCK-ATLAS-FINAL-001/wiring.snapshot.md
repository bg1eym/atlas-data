# Wiring Snapshot — PCK-ATLAS-FINAL-001

## Flow

TG → oc-bind /atlas handler → atlas-adapter runAtlasToday() → spawn(node, [pnpm.cjs, "-C", ATLAS_ROOT, "run", "atlas:run"]) → runtime/atlas/run_atlas.ts → result.json → URL 渲染 (ATLAS_DASHBOARD_URL_BASE, ATLAS_COVER_URL_BASE) → TG 回复 (run_id, dashboardUrl, coverUrl)

## Key Paths

- oc-bind: /atlas command, atlas-adapter.ts (spawn, result.json read)
- atlas-radar: runtime/atlas/run_atlas.ts (result.json write)
- result.json: out/atlas/<run_id>/result.json

## Debug

- /atlas debug: atlas_root_value, atlas_root_exists, node_bin, pnpm_js, node_probe, pnpm_js_probe

## ACTF

- atlas-result-guard.sh: reads result.json, outputs atlas-result-evidence.json
- failure_classifier: ATLAS_PIPELINE_FAILED, ATLAS_EMPTY, EVIDENCE_MISSING
