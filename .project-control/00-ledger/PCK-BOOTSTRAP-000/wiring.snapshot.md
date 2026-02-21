# Wiring Snapshot — PCK-BOOTSTRAP-000

## Entry Point

- **CLI**: `pnpm run atlas:run` (package.json scripts)
- **Pipeline**: `runtime/atlas/run_atlas.ts`
- **TG NL handler**: `runtime/atlas/tg_nl_handler.ts`

## Routing Layer

- **NL router**: `runtime/atlas/tg_nl_router.ts` — `route(text) -> { action, confidence, reason }`
- **oc-bind plugin**: `oc-personal-agent-lab/oc-bind/index.ts` — registers `/atlas` command, uses `matchNL`

## Command Handler

- **Atlas handler**: `oc-bind/index.ts` — `handler` for `/atlas`, calls `runAtlasToday()` from `atlas-adapter.ts`

## Executor

- **Atlas adapter**: `oc-personal-agent-lab/oc-bind/atlas-adapter.ts` — `runAtlasToday()`, spawns `pnpm run atlas:run`
- **Pipeline**: `runtime/atlas/run_atlas.ts` — `runAtlasPipeline()`

## Environment Variables (Read Locations)

- `ATLAS_ROOT`, `ATLAS_DASHBOARD_URL_BASE`, `ATLAS_COVER_URL_BASE`: oc-bind `index.ts`, `atlas-adapter.ts`
- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `DASHBOARD_URL_BASE`: `tg_nl_handler.ts`, `tg_send_readback.ts`
- `INPUT_PACK_DIR`, `RADAR_INPUT_PACK_PATHS`, `PDF_EXTRACT_ALLOW_FALLBACK`: `runtime/radar/pdf_sources_extract.ts`
- `ATLAS_RUN_ID`, `ATLAS_OUT_DIR`, `SKILLS_OUT_BASE`: `run_atlas.ts`, `skills/atlas-fetch/src/index.ts`
