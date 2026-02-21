#!/usr/bin/env bash
# Fetch health gate: computes health rates from coverage_stats.json.
# Does not hard-fail pipeline. Writes DEGRADED summary and exits 0.

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

OVERALL_OK_RATE_MIN="${FETCH_HEALTH_OVERALL_OK_RATE_MIN:-0.65}"
NEWS_OK_RATE_MIN="${FETCH_HEALTH_NEWS_OK_RATE_MIN:-0.40}"
BLOCKED_SHARE_MAX="${FETCH_HEALTH_BLOCKED_SHARE_MAX:-0.20}"

RUN_ID="${ATLAS_RUN_ID:-}"
if [ -z "$RUN_ID" ]; then
  LATEST=$(ls -t "${ROOT}/out/atlas" 2>/dev/null | head -1)
  if [ -z "$LATEST" ]; then
    echo "fetch_health_gate: SKIP no run under out/atlas"
    exit 0
  fi
  RUN_ID="$LATEST"
fi

STATS_JSON="${ROOT}/out/atlas/${RUN_ID}/coverage_stats.json"
SR_JSON="${ROOT}/out/atlas/${RUN_ID}/atlas-fetch/sources_raw.json"
if [ ! -f "$STATS_JSON" ] && [ ! -f "$SR_JSON" ]; then
  echo "fetch_health_gate: SKIP no coverage_stats.json or sources_raw.json"
  exit 0
fi

echo "=== Fetch Health Gate (run_id=$RUN_ID) ==="

RESULT=$(node -e "
const fs = require('fs');
const statsPath = '$STATS_JSON';
const srPath = '$SR_JSON';
let stats = null;
if (fs.existsSync(statsPath)) {
  stats = JSON.parse(fs.readFileSync(statsPath, 'utf8'));
} else {
  const sr = JSON.parse(fs.readFileSync(srPath, 'utf8'));
  const coverage = sr.coverage || [];
  let ok = 0, blocked = 0;
  const byKind = {};
  for (const c of coverage) {
    const kind = c.kind || 'unknown';
    byKind[kind] = byKind[kind] || { ok: 0, total: 0, ok_rate: 0 };
    byKind[kind].total++;
    if (c.status === 'ok') { ok++; byKind[kind].ok++; }
    if (c.status === 'blocked') blocked++;
  }
  for (const k of Object.keys(byKind)) {
    const r = byKind[k];
    r.ok_rate = r.total ? r.ok / r.total : 0;
  }
  stats = {
    run_id: '$RUN_ID',
    total_sources: coverage.length,
    ok_sources: ok,
    overall_ok_rate: coverage.length ? ok / coverage.length : 0,
    blocked_share: coverage.length ? blocked / coverage.length : 0,
    by_kind: byKind,
    by_adapter: {},
    top_failed_sources: coverage.filter(c => c.status !== 'ok').slice(0, 10).map(c => ({
      source_id: c.source_id,
      source_name: c.source_name || c.source_id,
      bucket: c.bucket || c.status || 'unknown',
      reason: c.reason || 'unknown',
    })),
  };
}
const overall = Number(stats.overall_ok_rate || 0);
const news = Number((stats.by_kind && stats.by_kind.news && stats.by_kind.news.ok_rate) || 0);
const blocked = Number(stats.blocked_share || 0);
const degraded = !(overall >= $OVERALL_OK_RATE_MIN && news >= $NEWS_OK_RATE_MIN && blocked <= $BLOCKED_SHARE_MAX);
const out = {
  run_id: stats.run_id || '$RUN_ID',
  overall_ok_rate: overall,
  news_ok_rate: news,
  blocked_share: blocked,
  thresholds: {
    overall_ok_rate_min: $OVERALL_OK_RATE_MIN,
    news_ok_rate_min: $NEWS_OK_RATE_MIN,
    blocked_share_max: $BLOCKED_SHARE_MAX,
  },
  verdict: degraded ? 'DEGRADED' : 'PASS',
  top_failed_sources: stats.top_failed_sources || [],
};
process.stdout.write(JSON.stringify(out));
")

OVERALL=$(echo "$RESULT" | node -e "const s=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(s.overall_ok_rate)")
NEWS=$(echo "$RESULT" | node -e "const s=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(s.news_ok_rate)")
BLOCKED=$(echo "$RESULT" | node -e "const s=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(s.blocked_share)")
VERDICT=$(echo "$RESULT" | node -e "const s=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(s.verdict)")

echo "  overall_ok_rate: $OVERALL (min $OVERALL_OK_RATE_MIN)"
echo "  news_ok_rate:    $NEWS (min $NEWS_OK_RATE_MIN)"
echo "  blocked_share:   $BLOCKED (max $BLOCKED_SHARE_MAX)"
echo "  verdict:         $VERDICT"

AUDIT_DIR="${ROOT}/out/atlas/${RUN_ID}/audit"
mkdir -p "$AUDIT_DIR"
echo "$RESULT" | node -e "
const fs = require('fs');
const s = JSON.parse(fs.readFileSync(0, 'utf8'));
const outPath = '$AUDIT_DIR/fetch_health_gate_summary.json';
fs.writeFileSync(outPath, JSON.stringify({
  gate: 'fetch_health_gate',
  generated_at: new Date().toISOString(),
  ...s,
}, null, 2));
console.log('  audit:', outPath);
"

if [ "$VERDICT" = "DEGRADED" ]; then
  echo "=== Fetch Health Gate DEGRADED (non-blocking) ==="
else
  echo "=== Fetch Health Gate PASS ==="
fi
exit 0
