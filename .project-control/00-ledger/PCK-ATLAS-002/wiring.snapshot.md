# Wiring Snapshot — PCK-ATLAS-002

## Entry Point

- **CLI**: `pnpm run atlas:run` (package.json scripts)
- **Pipeline**: `runtime/atlas/run_atlas.ts`
- **TG NL handler**: `runtime/atlas/tg_nl_handler.ts`

## Routing Layer

- **NL router**: `runtime/atlas/tg_nl_router.ts` — `routeAtlasIntent()`; /radar schedule → HELP (Radar 已停用)
- **oc-bind plugin**: `oc-personal-agent-lab/oc-bind/index.ts` — registers `/atlas` command, uses `matchNL`

## Command Handler

- **Atlas handler**: `oc-bind/index.ts` — `handler` for `/atlas`, calls `runAtlasToday()` from `atlas-adapter.ts`
- **Build fingerprint**: `getBuildFingerprint()` in oc-bind — appended to all /atlas replies
- **/atlas debug**: returns fingerprint, plugin dir, env presence (ATLAS_ROOT, ATLAS_DASHBOARD_URL_BASE, ATLAS_COVER_URL_BASE)

## Executor

- **Atlas adapter**: `oc-personal-agent-lab/oc-bind/atlas-adapter.ts` — `runAtlasToday()`, spawns `pnpm run atlas:run`
- **Pipeline**: `runtime/atlas/run_atlas.ts` — `runAtlasPipeline()`

## Diagnostics

- **Audit script**: `tools/atlas-activation-audit.sh` — gateway process, loaded plugin dir, help source, forbidden strings
- **Regression**: `RG-ATLAS-002-build-fingerprint-present.sh` — asserts fingerprint in code + logs

## Environment Variables (Read Locations)

- `ATLAS_ROOT`, `ATLAS_DASHBOARD_URL_BASE`, `ATLAS_COVER_URL_BASE`: oc-bind `index.ts`, `atlas-adapter.ts`
- `PCK_LEDGER_VERSION`: optional override for build fingerprint
- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `DASHBOARD_URL_BASE`: `tg_nl_handler.ts`, `tg_send_readback.ts`
- `INPUT_PACK_DIR`, `RADAR_INPUT_PACK_PATHS`, `PDF_EXTRACT_ALLOW_FALLBACK`: `runtime/radar/pdf_sources_extract.ts`
- `ATLAS_RUN_ID`, `ATLAS_OUT_DIR`, `SKILLS_OUT_BASE`: `run_atlas.ts`, `skills/atlas-fetch/src/index.ts`
