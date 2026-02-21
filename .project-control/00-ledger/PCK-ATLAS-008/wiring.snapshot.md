# Wiring Snapshot — PCK-ATLAS-008

## Flow

TG → oc-bind /atlas handler → atlas-adapter runAtlasToday() → spawn(node, [pnpm.cjs, "-C", ATLAS_ROOT, "run", "atlas:run"]) with PDF_EXTRACT_ALLOW_FALLBACK=1 → runtime/atlas/run_atlas.ts → result.json → URL 渲染 → TG 回复

## ATLAS_ROOT Discovery

- When ATLAS_ROOT invalid/empty: run tools/atlas-root-discovery.sh
- Use selected_root ONLY if single unambiguous candidate
- Discovery outputs: candidates[], selected_root, why_selected

## ATLAS_ROOT Validation

- existsSync(root), existsSync(package.json), scripts.atlas:run present

## Exit 42 (BLOCKED) Classification

- failure_mode = ATLAS_PIPELINE_BLOCKED
- Evidence: exit_code, stderr_snippet, stdout_snippet, atlas_root, node_exec, pnpm_js

## Degraded Output

- items_count=0 → ok: true, dashboardUrl present, failure_mode: ATLAS_DEGRADED
- PDF_EXTRACT_ALLOW_FALLBACK=1 in spawn env for local execution
