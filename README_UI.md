# Atlas Radar Viewer UI

Local, read-only UI for visualizing atlas-radar run snapshots.

## How to Run

```bash
cd ui/atlas-viewer
npm install
npm run dev
```

Open http://localhost:5173 in a browser.

## How It Finds `out/atlas`

The UI reads from `out/atlas/` relative to the **atlas-radar repo root** (parent of `ui/`). The Vite dev server resolves this as:

```
<repo_root>/out/atlas/
```

When running `npm run dev` from `ui/atlas-viewer/`, the config uses `resolve(__dirname, "../..")` to find the repo root, then serves files from `out/atlas/`.

## Security Model (Read-Only)

- **No writes**: The UI does not write, modify, or delete any files.
- **No network**: The UI does not make external network requests (except the dev server itself).
- **No spawn**: The UI does not run `atlas-fetch`, `run_atlas`, or any other scripts.
- **Path safety**: The `/api/atlas/` endpoint:
  - Only serves files under `<repo>/out/atlas/`
  - Rejects path traversal (`..`, absolute paths)
  - Only allows `.json` and `.txt` extensions
  - Excludes `DELIVERY_RAW_STDOUT` from run listing

## Build

```bash
cd ui/atlas-viewer
npm run build
```

Output in `dist/`. **Note**: The `/api/atlas/` file endpoint is only available in dev mode (`npm run dev`). The production build produces static assets; to serve them with the file API, you would need a custom server that includes the same read-only middleware.

## Screenshots

Run the UI and capture screenshots to `out/ui_screenshots/` for documentation. Example:

```
out/ui_screenshots/
  run-browser.png
  run-overview.png
  rendered-preview.png
  items-table.png
```

## Smoke Test

```bash
bash scripts/ui_smoke_test.sh
```

Verifies:
- UI build passes
- Required files are readable via the API

## TG Setup (Atlas NL E2E)

Set these env vars before running TG natural-language acceptance:

```bash
export TELEGRAM_BOT_TOKEN="<your_bot_token>"
export TELEGRAM_CHAT_ID="<target_chat_id>"
export DASHBOARD_URL_BASE="http://localhost:5173/?run_id={{run_id}}"
```

Notes:
- Do not commit real secrets.
- `DASHBOARD_URL_BASE` supports either `{{run_id}}` placeholder or a plain base URL (the script auto-appends `run_id`).
- `scripts/acceptance_atlas_tg_nl_e2e.sh` returns `42` when TG creds are missing.

## P2 UI Checklist (Manual)

After opening any run in the UI:

- [ ] **Left sidebar**: Radar categories (from extracted_sources.json radar_categories) are visible
- [ ] **Right panel**: Clicking a category shows Sources list grouped by kind (News/Community/Reports/KOL/Official)
- [ ] **Right panel**: Latest items for the category are shown as cards (not table only)
- [ ] **Drilldown**: Civilization view supports category filter + source filter + keyword + structural only
