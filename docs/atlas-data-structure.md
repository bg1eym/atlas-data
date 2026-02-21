# atlas-data Repo Structure (PCK-ATLAS-006B)

GitHub Pages repo serving static JSON + run folders for public Atlas dashboard.

## Required Structure

```
out/
  atlas/
    latest.json      # Single source of truth: { run_id, published_at, ... }
    index.json       # Recent N runs: { runs: [{ run_id, published_at, ... }] }
    <run_id>/        # Run folder (result.json, render_meta.json, etc.)
      result.json
      render_meta.json
      atlas-fetch/
      civilization/
      audit/
      ...
```

## latest.json

```json
{
  "run_id": "atlas-mlv9r111-9892wc",
  "published_at": "2026-02-21T12:00:00.000Z",
  "generated_at": "2026-02-20T19:15:04.700Z"
}
```

## index.json

```json
{
  "runs": [
    { "run_id": "atlas-mlv9r111-9892wc", "published_at": "2026-02-21T12:00:00.000Z" },
    { "run_id": "atlas-mlv989q0-7xbjag", "published_at": "2026-02-20T10:00:00.000Z" }
  ]
}
```

Keep last 30 runs. Newest first.

## Default Public URL

- **Data base:** `https://bg1eym.github.io/atlas-data/out/atlas`
- **latest.json:** `https://bg1eym.github.io/atlas-data/out/atlas/latest.json`
- **index.json:** `https://bg1eym.github.io/atlas-data/out/atlas/index.json`
