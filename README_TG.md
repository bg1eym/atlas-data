# Atlas TG Setup

## Canonical entrypoint

**`pnpm atlas:run`** — Full pipeline: fetch → classify → render dashboard.

Runs:
1. `runtime/radar/pdf_sources_extract.ts` + `scripts/generate_sources_config.ts`
2. `runtime/atlas/run_atlas.ts` (fetch, filter, civilization, cover card)

After success, writes `out/atlas/<run_id>/result.json`:
```json
{
  "run_id": "atlas-xxx",
  "item_count": 42,
  "coverage": { "overall_ok_rate": 0.95, "pipeline_verdict": "OK" },
  "dashboard_rel_path": "atlas-xxx",
  "cover_rel_path_or_url": null,
  "cover_missing": true
}
```

oc-bind (TG plugin) reads this and maps to public URLs via `ATLAS_DASHBOARD_URL_BASE`, `ATLAS_COVER_URL_BASE`.

## Input Pack (sources & KOLs)

Default directory: `environment/input_pack/`

Expected files (any supported extension):
- `ai_radar_sources.(pdf|txt|md|yaml|json)` — sources
- `ai_kols.(pdf|txt|md|yaml|json)` — KOLs

Override via env:
```bash
export INPUT_PACK_DIR="/path/to/your/input_pack"
```

Search order: `INPUT_PACK_DIR` (if set) → `<repo>/environment/input_pack`

## Required env vars (TG / oc-bind)

Configure in one of:
- **OpenClaw TG skill**: `$CODEX_HOME/skills/tg-skill/.env` or `environment/.env`
- **Service env injection**: systemd `Environment=` or Docker `env` / `environment`
- **Shell**: `export` before running handler

```bash
export TELEGRAM_BOT_TOKEN="123456:your_token"
export TELEGRAM_CHAT_ID="-100xxxxxxxxxx"
export ATLAS_ROOT="/path/to/atlas-radar"
export ATLAS_DASHBOARD_URL_BASE="https://<domain>/atlas/{{run_id}}/"
export ATLAS_COVER_URL_BASE="https://<domain>/atlas/{{run_id}}/cover.png"
```

## NL trigger examples

- `/atlas today` — slash command
- `发我 atlas 看板` — natural language
- `atlas` / `看板` / `dashboard` / `situation monitor`
- `今日 atlas` / `打开 dashboard`

## Run TG NL E2E acceptance

```bash
bash scripts/acceptance_atlas_tg_nl_e2e.sh
```

Expected:
- no creds -> exit `42` with `BLOCKED`
- with creds -> `PASS` and writes `out/atlas/<run_id>/tg/*`

## Notes

- TG: `/atlas today` or NL phrases → runs `pnpm atlas:run`, returns `sendPhoto(coverUrl)` + dashboard URL text.
- If `cover_missing` in result.json: sends message with dashboard URL + "cover not available".
- URL templates must contain `{{run_id}}`; unresolved placeholders are treated as failure.
