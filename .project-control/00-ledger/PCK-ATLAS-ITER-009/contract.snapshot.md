# Contract Snapshot — PCK-BOOTSTRAP-000

## Slash Commands

| Command | Description |
|---------|-------------|
| /atlas today | Run Atlas pipeline, return cover image + dashboard URL |
| /atlas help | Show help text |

## NL Examples (Natural Language)

- atlas
- 看板
- dashboard
- situation monitor
- 发我 atlas 看板
- 今日 atlas
- 今天的文明态势雷达
- 给我最新AI时政雷达
- 生成今日 atlas
- 打开 dashboard

## Help Output

```
📡 Atlas Dashboard

**NL:** atlas / 看板 / dashboard / situation monitor / 发我 atlas / 今日 atlas

**Slash:** /atlas today | /atlas help
```

## Output Format

- Cover card: Chinese text + inline button "🟦 打开 Dashboard"
- Dashboard URL: template `{{run_id}}` interpolated
- result.json: `{ run_id, item_count, coverage, dashboard_rel_path, cover_rel_path_or_url, cover_missing }`

## Forbidden Patterns

(Initially empty)
