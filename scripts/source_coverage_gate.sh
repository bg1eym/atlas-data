#!/usr/bin/env bash
# Source coverage gate: enforce diversity (no "only official blog").
# Reads out/atlas/<run_id>/atlas-fetch/items_normalized.json
# Thresholds: official_share <= 0.40, top1_source_share <= 0.30, >=3 non_official kinds.
# Exit 1 on failure.

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

OFFICIAL_SHARE_MAX="${OFFICIAL_SHARE_MAX:-0.40}"
TOP1_SOURCE_SHARE_MAX="${TOP1_SOURCE_SHARE_MAX:-0.30}"
NON_OFFICIAL_KINDS_MIN=3
UNIQUE_SOURCES_MIN=8
CATEGORIES_PRESENT_MIN=5

# Find latest run
RUN_ID="${ATLAS_RUN_ID:-}"
if [ -z "$RUN_ID" ]; then
  LATEST=$(ls -t "${ROOT}/out/atlas" 2>/dev/null | head -1)
  if [ -z "$LATEST" ]; then
    echo "FAIL: No out/atlas run found. Run: npm run atlas:run"
    exit 1
  fi
  RUN_ID="$LATEST"
fi

ITEMS_JSON="${ROOT}/out/atlas/${RUN_ID}/atlas-fetch/items_normalized.json"
if [ ! -f "$ITEMS_JSON" ]; then
  echo "FAIL: items_normalized.json not found: $ITEMS_JSON"
  exit 1
fi

echo "=== Source Coverage Gate (run_id=$RUN_ID) ==="

# Use node to parse JSON and compute stats
STATS=$(node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('$ITEMS_JSON', 'utf8'));
const items = data.items || [];

// Fallback: map source_name to kind when kind missing
const OFFICIAL_SOURCES = new Set([
  'OpenAI Blog', 'Anthropic News', 'DeepMind Blog', 'OpenAI GitHub Releases',
  'EU Commission', 'FTC News'
]);

const byKind = {};
const bySource = {};
for (const it of items) {
  let kind = it.kind;
  if (!kind) {
    kind = OFFICIAL_SOURCES.has(it.source_name) ? 'official' : 'news';
  }
  byKind[kind] = (byKind[kind] || 0) + 1;
  bySource[it.source_name || 'unknown'] = (bySource[it.source_name || 'unknown'] || 0) + 1;
}

const total = items.length;
const officialCount = byKind['official'] || 0;
const officialShare = total > 0 ? officialCount / total : 0;

const sources = Object.entries(bySource).sort((a, b) => b[1] - a[1]);
const top1 = sources[0];
const top1Share = total > 0 && top1 ? top1[1] / total : 0;

const nonOfficialKinds = Object.keys(byKind).filter(k => k !== 'official').length;
const uniqueSources = Object.keys(bySource).length;
const byCategory = {};
for (const it of items) {
  const c = it.category_hint || 'uncategorized';
  byCategory[c] = (byCategory[c] || 0) + 1;
}
const categoriesPresent = Object.keys(byCategory).filter(c => c !== 'uncategorized' && byCategory[c] > 0).length;

console.log(JSON.stringify({
  total,
  byKind,
  bySource: Object.fromEntries(sources.slice(0, 10)),
  officialShare,
  top1Source: top1 ? top1[0] : '',
  top1Count: top1 ? top1[1] : 0,
  top1Share,
  nonOfficialKinds,
  uniqueSources,
  categoriesPresent,
}));
")

TOTAL=$(echo "$STATS" | node -e "const s=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(s.total)")
OFFICIAL_SHARE=$(echo "$STATS" | node -e "const s=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(s.officialShare)")
TOP1_SHARE=$(echo "$STATS" | node -e "const s=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(s.top1Share)")
NON_OFFICIAL_KINDS=$(echo "$STATS" | node -e "const s=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(s.nonOfficialKinds)")
UNIQUE_SOURCES=$(echo "$STATS" | node -e "const s=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(s.uniqueSources)")
CATEGORIES_PRESENT=$(echo "$STATS" | node -e "const s=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(s.categoriesPresent)")

echo "  total items: $TOTAL"
echo "  by_kind: $(echo "$STATS" | node -e "const s=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(JSON.stringify(s.byKind))")"
echo "  official_share: $OFFICIAL_SHARE (max $OFFICIAL_SHARE_MAX)"
echo "  top1_source_share: $TOP1_SHARE (max $TOP1_SOURCE_SHARE_MAX)"
echo "  non_official_kinds: $NON_OFFICIAL_KINDS (min $NON_OFFICIAL_KINDS_MIN)"
echo "  unique_sources: $UNIQUE_SOURCES (min $UNIQUE_SOURCES_MIN)"
echo "  categories_present: $CATEGORIES_PRESENT (min $CATEGORIES_PRESENT_MIN)"

FAIL=0
if node -e "if($OFFICIAL_SHARE > $OFFICIAL_SHARE_MAX) process.exit(1)" 2>/dev/null; then true; else
  echo "FAIL: official_share $OFFICIAL_SHARE > $OFFICIAL_SHARE_MAX"
  FAIL=1
fi
if node -e "if($TOP1_SHARE > $TOP1_SOURCE_SHARE_MAX) process.exit(1)" 2>/dev/null; then true; else
  echo "FAIL: top1_source_share $TOP1_SHARE > $TOP1_SOURCE_SHARE_MAX"
  FAIL=1
fi
if [ "$NON_OFFICIAL_KINDS" -lt "$NON_OFFICIAL_KINDS_MIN" ]; then
  echo "FAIL: non_official_kinds $NON_OFFICIAL_KINDS < $NON_OFFICIAL_KINDS_MIN"
  FAIL=1
fi
if [ "$UNIQUE_SOURCES" -lt "$UNIQUE_SOURCES_MIN" ]; then
  echo "FAIL: unique_sources $UNIQUE_SOURCES < $UNIQUE_SOURCES_MIN"
  FAIL=1
fi
if [ "$CATEGORIES_PRESENT" -lt "$CATEGORIES_PRESENT_MIN" ]; then
  echo "FAIL: categories_present $CATEGORIES_PRESENT < $CATEGORIES_PRESENT_MIN"
  FAIL=1
fi

if [ $FAIL -eq 1 ]; then
  echo ""
  echo "Top sources:"
  echo "$STATS" | node -e "
    const s=JSON.parse(require('fs').readFileSync(0,'utf8'));
    const total = s.total || 1;
    for (const [name, count] of Object.entries(s.bySource || {})) {
      const pct = (count/total*100).toFixed(1);
      console.log('  ' + name + ': ' + count + ' (' + pct + '%)');
    }
  "
  exit 1
fi

echo "=== Source Coverage Gate PASS ==="
exit 0
