# Wiring Snapshot — PCK-ATLAS-005

## Entry Point

- **CLI**: `pnpm run atlas:run` (package.json scripts)
- **Pipeline**: `runtime/atlas/run_atlas.ts`
- **TG NL handler**: `runtime/atlas/tg_nl_handler.ts`

## Routing Layer

- **NL router**: `runtime/atlas/tg_nl_router.ts` — `routeAtlasIntent()`; /radar schedule → HELP (Radar 已停用)
- **oc-bind plugin**: `oc-personal-agent-lab/oc-bind/index.ts` — registers `/atlas` command, uses `matchNL`

## Command Handler

- **Atlas handler**: `oc-personal-agent-lab/oc-bind/index.ts` — `handler` for `/atlas`, calls `runAtlasToday()` from `atlas-adapter.ts`
- **Build fingerprint**: `getBuildFingerprint()` in oc-bind — appended to all /atlas replies
- **/atlas debug**: fingerprint, plugin dir, env presence, PATH, node_bin, pnpm_js, node_probe, pnpm_js_probe

## Executor (Shebang-Proof)

- **Atlas adapter**: `oc-personal-agent-lab/oc-bind/atlas-adapter.ts` — `runAtlasToday()`, spawns **node** with **pnpm.cjs** (已绕过 shebang)
- **spawn**: `spawn(nodeBin, [pnpmJs, "-C", atlasRoot, "run", "atlas:run"], { shell: false })`
- **node resolution**: NODE_BIN env → /opt/homebrew/bin/node → /usr/local/bin/node → /usr/bin/node
- **pnpm.cjs resolution**: PNPM_JS env → /opt/homebrew/lib/node_modules/pnpm/bin/pnpm.cjs → /usr/local/lib/node_modules/pnpm/bin/pnpm.cjs
- **Pipeline**: `runtime/atlas/run_atlas.ts` — `runAtlasPipeline()`

## PCK Gates

- **preflight.sh**: ledger + meta.json + snapshots
- **regress.sh**: 02-regressions/*.sh
- **convergence.sh**: contract diff vs previous; blocks unless structural_scope contains contract:update
- **iteration-memory.sh**: A) latest ledger + meta.json; B) prior Run Journal exists (non-BOOTSTRAP); C) base_version references prior ledger

## Diagnostics

- **Audit script**: `tools/atlas-activation-audit.sh`
- **Regression**: `RG-ATLAS-002`, `RG-ATLAS-003-*`, `RG-ATLAS-004-shebang-proof.sh`
- **Harness**: `oc-personal-agent-lab/tools/atlas-node-probe.cjs`, `atlas-node-spawn-test.cjs`
- **Mistake Book**: `.project-control/02-regressions/mistake-book.md`

## Environment Variables (Read Locations)

- `ATLAS_ROOT`, `ATLAS_DASHBOARD_URL_BASE`, `ATLAS_COVER_URL_BASE`: oc-bind `index.ts`, `atlas-adapter.ts`
- `NODE_BIN`, `PNPM_JS`: shebang-proof overrides
- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `DASHBOARD_URL_BASE`: `tg_nl_handler.ts`, `tg_send_readback.ts`
- `INPUT_PACK_DIR`, `RADAR_INPUT_PACK_PATHS`, `PDF_EXTRACT_ALLOW_FALLBACK`: `runtime/radar/pdf_sources_extract.ts`
- `ATLAS_RUN_ID`, `ATLAS_OUT_DIR`, `SKILLS_OUT_BASE`: `run_atlas.ts`, `skills/atlas-fetch/src/index.ts`
