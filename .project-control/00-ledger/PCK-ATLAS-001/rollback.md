# Rollback — PCK-ATLAS-001

## Restore to PCK-BOOTSTRAP-000

To revert PCK-ATLAS-001 changes:

```bash
git checkout HEAD -- runtime/atlas/tg_nl_router.ts runtime/atlas/tg_nl_handler.ts
# oc-bind (if in same repo): git checkout HEAD -- oc-bind/index.ts
```

Or restore from backup of ledger PCK-BOOTSTRAP-000.

## Forbidden Patterns (RG-ATLAS-001)

- radar:run, OPENCLAW_ROOT, /atlas radar, radar_daily

## Scope

- tg_nl_router.ts: removed "atlas radar" from RUN_KEYWORDS; /radar schedule no longer routes to atlas_run
- tg_nl_handler.ts: /radar → "Radar 已停用" message
- oc-bind/index.ts: added run_id to TG response
