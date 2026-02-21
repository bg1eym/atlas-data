upstream_locator:
  vendor/situation-monitor

## Capability: Source catalog (FEEDS)
- upstream_evidence: vendor/situation-monitor/src/lib/config/feeds.ts FEEDS
- upstream_evidence: vendor/situation-monitor/src/lib/config/feeds.ts FeedSource
- our_mapping: runtime/radar/sources_catalog.ts
- parity_status: PARTIAL
- behavior_notes: FEEDS Record<NewsCategory, FeedSource[]>, we use radar_categories + sources by kind

## Capability: Intel sources (INTEL_SOURCES)
- upstream_evidence: vendor/situation-monitor/src/lib/config/feeds.ts INTEL_SOURCES
- upstream_evidence: vendor/situation-monitor/src/lib/config/feeds.ts IntelSource
- our_mapping: runtime/radar/sources_catalog.ts
- parity_status: PARTIAL
- behavior_notes: type think-tank/defense/regional/osint, we map to kind news/community/report/kol

## Capability: Adapter fetch (fetchSource)
- upstream_evidence: vendor/situation-monitor/src/lib/api/news.ts fetchCategoryNews
- upstream_evidence: vendor/situation-monitor/src/lib/api/news.ts transformGdeltArticle
- our_mapping: skills/atlas-fetch/src/index.ts fetchSource
- parity_status: PARITY
- behavior_notes: rss/html/github adapters, normalize to common schema

## Capability: Normalize to common schema
- upstream_evidence: vendor/situation-monitor/src/lib/api/news.ts NewsItem
- upstream_evidence: vendor/situation-monitor/src/lib/api/news.ts transformGdeltArticle
- our_mapping: skills/atlas-fetch/src/adapters/rss.ts normalizeRss
- parity_status: PARITY
- behavior_notes: id, title, link, source, category, timestamp

## Capability: Deduplication
- upstream_evidence: vendor/situation-monitor/src/lib/services/deduplicator.ts RequestDeduplicator
- upstream_evidence: vendor/situation-monitor/src/lib/services/deduplicator.ts dedupe
- our_mapping: MISSING
- parity_status: MISSING
- behavior_notes: in-flight request dedupe; we do not yet dedupe items by URL

## Capability: Rank/limit (slice)
- upstream_evidence: vendor/situation-monitor/src/lib/components/panels/NewsPanel.svelte items.slice
- upstream_evidence: vendor/situation-monitor/src/lib/api/news.ts maxrecords
- our_mapping: runtime/atlas/fetch_policy.ts
- parity_status: PARTIAL
- behavior_notes: NewsPanel slice(0,15), GDELT maxrecords=20; we apply per_source_limit

## Capability: Classify (keywords)
- upstream_evidence: vendor/situation-monitor/src/lib/config/keywords.ts containsAlertKeyword
- upstream_evidence: vendor/situation-monitor/src/lib/config/keywords.ts detectTopics
- our_mapping: runtime/atlas/civilization/classify.ts
- parity_status: PARITY
- behavior_notes: keyword-based tagging, we add radar_categories + civ tags

## Capability: Coverage report
- upstream_evidence: vendor/situation-monitor/src/lib/api/news.ts fetchCategoryNews
- upstream_evidence: skills/atlas-fetch provenance coverage
- our_mapping: skills/atlas-fetch/src/index.ts coverage
- parity_status: PARITY
- behavior_notes: status ok/empty/error per source

## Capability: Panel layout
- upstream_evidence: vendor/situation-monitor/src/lib/components/common/Panel.svelte Panel
- upstream_evidence: vendor/situation-monitor/src/lib/components/common/Panel.svelte panel-header
- our_mapping: ui/atlas-viewer/src/Dashboard/Panel.svelte
- parity_status: PARITY
- behavior_notes: panel-title-row, panel-count badge

## Capability: Dashboard grid
- upstream_evidence: vendor/situation-monitor/src/lib/components/layout/Dashboard.svelte dashboard-grid
- upstream_evidence: vendor/situation-monitor/src/lib/components/layout/Dashboard.svelte column-count
- our_mapping: ui/atlas-viewer/src/Dashboard/DashboardView.svelte
- parity_status: PARITY
- behavior_notes: responsive column-count breakpoints

## Capability: NewsItem card (drilldown item)
- upstream_evidence: vendor/situation-monitor/src/lib/components/common/NewsItem.svelte NewsItem
- upstream_evidence: vendor/situation-monitor/src/lib/components/common/NewsItem.svelte item-title
- our_mapping: ui/atlas-viewer/src/Dashboard/ItemCard.svelte
- parity_status: PARITY
- behavior_notes: item-source, item-title, item-meta

## Capability: Category drilldown (NewsPanel)
- upstream_evidence: vendor/situation-monitor/src/lib/components/panels/NewsPanel.svelte category
- upstream_evidence: vendor/situation-monitor/src/lib/components/panels/NewsPanel.svelte items.slice
- our_mapping: ui/atlas-viewer/src/Dashboard/CivilizationDrilldown.svelte
- parity_status: PARITY
- behavior_notes: category filter, source filter, keyword, structural only

## Capability: Header
- upstream_evidence: vendor/situation-monitor/src/lib/components/layout/Header.svelte header
- upstream_evidence: vendor/situation-monitor/src/lib/components/layout/Header.svelte logo
- our_mapping: ui/atlas-viewer/src/Dashboard/Header.svelte
- parity_status: PARITY
- behavior_notes: sticky, meta items
