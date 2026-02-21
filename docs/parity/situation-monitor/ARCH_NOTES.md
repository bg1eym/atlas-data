# situation-monitor Architecture Notes

upstream_locator: vendor/situation-monitor

## Data flow (source catalog → adapter → normalize → dedupe → rank/limit → classify → render → drilldown)

### 1. Source catalog
- upstream_evidence: vendor/situation-monitor/src/lib/config/feeds.ts FEEDS
- upstream_evidence: vendor/situation-monitor/src/lib/config/feeds.ts FeedSource
- Record<NewsCategory, FeedSource[]>, each FeedSource has name, url. INTEL_SOURCES adds type, topics.

### 2. Adapter (fetch)
- upstream_evidence: vendor/situation-monitor/src/lib/api/news.ts fetchCategoryNews
- upstream_evidence: vendor/situation-monitor/src/lib/config/api.ts fetchWithProxy
- Fetches via GDELT API; our atlas-fetch uses rss/html/github adapters per skills/atlas-fetch/src/index.ts fetchSource.

### 3. Normalize
- upstream_evidence: vendor/situation-monitor/src/lib/api/news.ts transformGdeltArticle
- upstream_evidence: vendor/situation-monitor/src/lib/api/news.ts NewsItem
- Maps raw article to { id, title, link, source, category, timestamp, isAlert, region, topics }.

### 4. Dedupe
- upstream_evidence: vendor/situation-monitor/src/lib/services/deduplicator.ts RequestDeduplicator
- upstream_evidence: vendor/situation-monitor/src/lib/services/deduplicator.ts dedupe
- In-flight request deduplication; news store appendItems filters by existingIds.

### 5. Rank/limit
- upstream_evidence: vendor/situation-monitor/src/lib/api/news.ts maxrecords
- upstream_evidence: vendor/situation-monitor/src/lib/components/panels/NewsPanel.svelte items.slice
- GDELT maxrecords=20; NewsPanel shows slice(0,15). We apply per_source_limit in fetch_policy.

### 6. Classify
- upstream_evidence: vendor/situation-monitor/src/lib/config/keywords.ts containsAlertKeyword
- upstream_evidence: vendor/situation-monitor/src/lib/config/keywords.ts detectTopics
- Enrich with isAlert, region, topics. We add radar_categories, civ tags in classify.ts.

### 7. Render
- upstream_evidence: vendor/situation-monitor/src/lib/components/panels/NewsPanel.svelte
- upstream_evidence: vendor/situation-monitor/src/lib/components/common/NewsItem.svelte
- Panel wraps news-list; each item rendered as NewsItem card.

### 8. Drilldown
- upstream_evidence: vendor/situation-monitor/src/lib/components/panels/NewsPanel.svelte category
- upstream_evidence: vendor/situation-monitor/src/lib/stores/news.ts getItems
- Category-scoped items; click item opens link. We use CivilizationDrilldown with filters.
