#!/usr/bin/env bash
# Summary gate: first N=50 items must have summary_en and summary_zh non-empty.
# Reads items_civ.json (has summary_zh from classify) or items_normalized + items_civ merged.
# Exit 1 on failure.

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

N="${SUMMARY_GATE_N:-50}"
RUN_ID="${ATLAS_RUN_ID:-}"
if [ -z "$RUN_ID" ]; then
  LATEST=$(ls -t "${ROOT}/out/atlas" 2>/dev/null | head -1)
  [ -z "$LATEST" ] && { echo "FAIL: No out/atlas run found."; exit 1; }
  RUN_ID="$LATEST"
fi

CIV_JSON="${ROOT}/out/atlas/${RUN_ID}/civilization/items_civ.json"
NORM_JSON="${ROOT}/out/atlas/${RUN_ID}/atlas-fetch/items_normalized.json"
if [ ! -f "$CIV_JSON" ]; then
  echo "FAIL: items_civ.json not found: $CIV_JSON"
  exit 1
fi

echo "=== Summary Gate (run_id=$RUN_ID, N=$N) ==="

STATS=$(node -e "
const civ = require('fs').readFileSync('$CIV_JSON', 'utf8');
const data = JSON.parse(civ);
const items = data.items || [];
const firstN = items.slice(0, $N);
let missingEn = 0, missingZh = 0;
const failingIds = [];
for (const it of firstN) {
  const en = (it.summary ?? it.summary_en ?? '').trim();
  const zh = (it.summary_zh ?? '').trim();
  if (!en) { missingEn++; failingIds.push({ id: it.id, field: 'summary_en' }); }
  if (!zh) { missingZh++; failingIds.push({ id: it.id, field: 'summary_zh' }); }
}
console.log(JSON.stringify({ total: firstN.length, missingEn, missingZh, failingIds: failingIds.slice(0, 10) }));
")

MISSING_EN=$(echo "$STATS" | node -e "console.log(JSON.parse(require('fs').readFileSync(0,'utf8')).missingEn)")
MISSING_ZH=$(echo "$STATS" | node -e "console.log(JSON.parse(require('fs').readFileSync(0,'utf8')).missingZh)")
FAILING_IDS=$(echo "$STATS" | node -e "const s=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(JSON.stringify(s.failingIds || []))")

echo "  first N=$N: missing summary_en=$MISSING_EN, missing summary_zh=$MISSING_ZH"
echo "  failing sample ids: $FAILING_IDS"

if [ "$MISSING_EN" -gt 0 ] || [ "$MISSING_ZH" -gt 0 ]; then
  echo "FAIL: All first $N items must have summary_en and summary_zh non-empty (treat \"\" as missing)."
  exit 1
fi

echo "=== Summary Gate PASS ==="
exit 0
