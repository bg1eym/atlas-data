#!/usr/bin/env bash
# Blocking gate for input pack extraction quality.

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

EXTRACTED="${ROOT}/out/radar_sources/extracted_sources.json"
RUN_ID="${ATLAS_RUN_ID:-}"
if [ -z "$RUN_ID" ]; then
  RUN_ID=$(ls -t "${ROOT}/out/atlas" 2>/dev/null | head -1 || true)
fi

MIN_PER_CATEGORY="${INPUT_PACK_MIN_SOURCES_PER_CATEGORY:-3}"
MIN_KOLS="${INPUT_PACK_MIN_KOLS:-4}"

AUDIT_DIR="${ROOT}/out/radar_sources/audit"
if [ -n "$RUN_ID" ] && [ -d "${ROOT}/out/atlas/${RUN_ID}" ]; then
  AUDIT_DIR="${ROOT}/out/atlas/${RUN_ID}/audit"
fi
mkdir -p "$AUDIT_DIR"
OUT_SUMMARY="${AUDIT_DIR}/input_pack_gate_summary.json"

if [ ! -f "$EXTRACTED" ]; then
  jq -n --arg verdict "FAIL" --arg reason "missing_extracted_sources" \
    '{gate:"input_pack_gate", verdict:$verdict, reason:$reason, generated_at:(now|todate)}' > "$OUT_SUMMARY"
  echo "FAIL: extracted_sources.json missing"
  exit 1
fi

RESULT=$(node -e "
const fs = require('fs');
const p = '$EXTRACTED';
const minCat = Number('$MIN_PER_CATEGORY');
const minKols = Number('$MIN_KOLS');
const j = JSON.parse(fs.readFileSync(p,'utf8'));
const cats = Array.isArray(j.radar_categories) ? j.radar_categories : [];
const sources = Array.isArray(j.sources) ? j.sources : [];
const kols = Array.isArray(j.kols) ? j.kols : [];
const byCat = {};
for (const c of cats) byCat[c.id] = 0;
for (const s of sources) byCat[s.category_id] = (byCat[s.category_id] || 0) + 1;
const tooLow = Object.entries(byCat).filter(([,n]) => n < minCat).map(([id,n]) => ({id,count:n}));
const verdict = (sources.length > 0 && kols.length >= minKols && tooLow.length === 0) ? 'PASS' : 'FAIL';
process.stdout.write(JSON.stringify({
  gate: 'input_pack_gate',
  verdict,
  generated_at: new Date().toISOString(),
  category_count: cats.length,
  source_count: sources.length,
  kol_count: kols.length,
  min_per_category: minCat,
  min_kols: minKols,
  by_category: byCat,
  too_low_categories: tooLow,
  parser: j._meta?.parser || 'unknown',
  inputs: j._meta?.inputs || [],
}));
")

echo "$RESULT" > "$OUT_SUMMARY"
VERDICT=$(echo "$RESULT" | node -e "const s=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(s.verdict)")
echo "=== Input Pack Gate ==="
echo "$RESULT" | node -e "const s=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log('  sources=' + s.source_count + ' kols=' + s.kol_count + ' parser=' + s.parser)"
echo "  audit: $OUT_SUMMARY"
if [ "$VERDICT" != "PASS" ]; then
  echo "FAIL: input_pack_gate"
  exit 1
fi
echo "PASS: input_pack_gate"
