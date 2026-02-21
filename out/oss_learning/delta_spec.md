# Delta Spec (Not in Vendor)

## Rule

Each delta must include:
- **Feature**: Description
- **Vendor does not have**: Evidence (file path or behavior)
- **Acceptance**: Testable criterion

## Deltas

### D1: Atlas-specific data (render_meta, coverage, items)

- **Vendor does not have**: situation-monitor uses Fed/news/sectors; we use Atlas run outputs
- **Acceptance**: Dashboard shows item_count, coverage, filter_report from our API

### D2: Atlas API integration (/api/atlas)

- **Vendor does not have**: situation-monitor uses external APIs; we use local Vite plugin
- **Acceptance**: curl /api/atlas returns runs; /api/atlas/<run_id>/render_meta.json returns 200

### D3: Run selector (sidebar)

- **Vendor does not have**: situation-monitor has single dashboard; we have multiple runs
- **Acceptance**: Sidebar shows run list; selecting run loads dashboard

## Template for new deltas

```markdown
### Dn: <title>

- **Vendor does not have**: <evidence>
- **Acceptance**: <testable>
```
