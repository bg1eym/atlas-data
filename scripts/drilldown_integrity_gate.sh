#!/usr/bin/env bash
# Drilldown integrity gate: verify data consistency for drilldown filtering.
# - Each source in coverage has source_name and has items with matching source_name
# - Items have category_hint for radar filter
# - civilization/items_civ exists for civ drilldown
# Exit 1 on failure.

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

RUN_ID="${ATLAS_RUN_ID:-}"
if [ -z "$RUN_ID" ]; then
  LATEST=$(ls -t "${ROOT}/out/atlas" 2>/dev/null | head -1)
  [ -z "$LATEST" ] && { echo "FAIL: No out/atlas run found."; exit 1; }
  RUN_ID="$LATEST"
fi

PROV="${ROOT}/out/atlas/${RUN_ID}/atlas-fetch/provenance.json"
ITEMS="${ROOT}/out/atlas/${RUN_ID}/atlas-fetch/items_normalized.json"
CIV="${ROOT}/out/atlas/${RUN_ID}/civilization/items_civ.json"

echo "=== Drilldown Integrity Gate (run_id=$RUN_ID) ==="

[ ! -f "$PROV" ] && { echo "FAIL: provenance.json not found"; exit 1; }
[ ! -f "$ITEMS" ] && { echo "FAIL: items_normalized.json not found"; exit 1; }
[ ! -f "$CIV" ] && { echo "FAIL: items_civ.json not found"; exit 1; }

node -e "
const fs = require('fs');
const prov = JSON.parse(fs.readFileSync('$PROV', 'utf8'));
const itemsData = JSON.parse(fs.readFileSync('$ITEMS', 'utf8'));
const items = itemsData.items || [];
const coverage = prov.coverage || [];

const bySource = new Map();
for (const it of items) {
  const s = it.source_name || 'unknown';
  bySource.set(s, (bySource.get(s) || 0) + 1);
}

let fail = 0;
for (const c of coverage) {
  const name = c.source_name || c.source_id;
  if (!name) {
    console.error('FAIL: coverage entry missing source_name/source_id');
    fail = 1;
    break;
  }
  const count = bySource.get(name) || 0;
  if (c.status === 'ok' && count === 0) {
    console.error('FAIL: source', name, 'has status ok but 0 items with matching source_name');
    fail = 1;
  }
}

const withCategory = items.filter(i => (i.category_hint || '').trim().length > 0).length;
if (withCategory === 0 && items.length > 0) {
  console.error('FAIL: no items have category_hint for radar filter');
  fail = 1;
}

if (fail) process.exit(1);
console.log('  OK: coverage has source_name; items match; category_hint present');
"

echo "=== Drilldown Integrity Gate PASS ==="
exit 0
