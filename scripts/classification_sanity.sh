#!/usr/bin/env bash
# Classification sanity gate (blocking).
# Asserts:
# - top1 radar_category_share <= 0.60
# - top1 source_share <= 0.30
# - official_share <= 0.40
# - unique_sources >= 8
# - categories_present >= 5

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ATLAS_OUT="${ROOT}/out/atlas"

cd "$ROOT"

RUN_ID="${ATLAS_RUN_ID:-}"
if [ -z "$RUN_ID" ]; then
  RUN_ID=$(ls -t "$ATLAS_OUT" 2>/dev/null | head -1 || true)
fi
if [ -z "$RUN_ID" ]; then
  echo "classification_sanity: no runs found"
  exit 21
fi

RUN_DIR="${ATLAS_OUT}/${RUN_ID}"
DIST="${RUN_DIR}/classification_distribution.json"
PROV="${RUN_DIR}/atlas-fetch/provenance.json"
if [ ! -f "$DIST" ]; then
  echo "classification_sanity: missing classification_distribution.json ($DIST)"
  exit 21
fi

TOP1_RADAR_SHARE=$(jq -r '.top1_radar.share // 0' "$DIST")
TOP1_SOURCE_SHARE=$(jq -r '.top1_source.share // 0' "$DIST")
UNIQUE_SOURCES=$(jq -r '(.counts_by_source // {} | keys | length)' "$DIST")
CATEGORIES_PRESENT=$(jq -r '(.counts_by_radar_category // {} | to_entries | map(select(.value > 0)) | length)' "$DIST")
OFFICIAL_SHARE=0
if [ -f "$PROV" ]; then
  OFFICIAL_SHARE=$(jq -r '
    (.coverage // []) as $c
    | if ($c|length)==0 then 0
      else (([$c[] | select((.kind // "") == "official")] | length) / ($c|length))
      end
  ' "$PROV")
fi

echo "classification_sanity:"
echo "  run_id=$RUN_ID"
echo "  top1_radar_share=$TOP1_RADAR_SHARE"
echo "  top1_source_share=$TOP1_SOURCE_SHARE"
echo "  official_share=$OFFICIAL_SHARE"
echo "  unique_sources=$UNIQUE_SOURCES"
echo "  categories_present=$CATEGORIES_PRESENT"

node -e "
const vals = {
  top1Radar: Number('$TOP1_RADAR_SHARE'),
  top1Source: Number('$TOP1_SOURCE_SHARE'),
  officialShare: Number('$OFFICIAL_SHARE'),
  uniqueSources: Number('$UNIQUE_SOURCES'),
  categoriesPresent: Number('$CATEGORIES_PRESENT'),
};
const fails = [];
if (vals.top1Radar > 0.60) fails.push('top1_radar_share>0.60');
if (vals.top1Source > 0.30) fails.push('top1_source_share>0.30');
if (vals.officialShare > 0.40) fails.push('official_share>0.40');
if (vals.uniqueSources < 8) fails.push('unique_sources<8');
if (vals.categoriesPresent < 5) fails.push('categories_present<5');
if (fails.length) {
  console.error('FAIL: classification_sanity ' + fails.join(', '));
  process.exit(21);
}
"

echo "classification_sanity: OK"
exit 0
