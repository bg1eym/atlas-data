#!/usr/bin/env bash
# Verdict semantics gate: fixture run with TG env missing must produce
#   pipeline_verdict=OK
#   delivery_verdict=NOT_CONFIGURED
# Exit 1 on failure.

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

echo "=== Verdict Semantics Gate ==="

# Unset TG env to simulate "TG not configured" local run
export TELEGRAM_BOT_TOKEN=""
export TELEGRAM_CHAT_ID=""
export DASHBOARD_URL_BASE=""
export PDF_EXTRACT_ALLOW_FALLBACK="1"

# Run atlas pipeline (local only, no TG)
RUN_OUT=$(npm run atlas:run 2>&1)
RUN_ID=$(echo "$RUN_OUT" | grep -oE 'run_id=atlas-[a-z0-9-]+' | head -1 | cut -d= -f2)

if [ -z "$RUN_ID" ]; then
  echo "FAIL: could not extract run_id from atlas:run output"
  echo "$RUN_OUT" | tail -20
  exit 1
fi

AUDIT="${ROOT}/out/atlas/${RUN_ID}/audit/summary.json"
if [ ! -f "$AUDIT" ]; then
  echo "FAIL: audit/summary.json not found at $AUDIT"
  exit 1
fi

PIPELINE=$(jq -r '.pipeline_verdict // .verdict // empty' "$AUDIT")
DELIVERY=$(jq -r '.delivery_verdict // empty' "$AUDIT")

if [ "$PIPELINE" != "OK" ]; then
  echo "FAIL: pipeline_verdict must be OK (got: $PIPELINE)"
  jq . "$AUDIT"
  exit 1
fi

if [ "$DELIVERY" != "NOT_CONFIGURED" ]; then
  echo "FAIL: delivery_verdict must be NOT_CONFIGURED when TG env missing (got: $DELIVERY)"
  jq . "$AUDIT"
  exit 1
fi

echo "  pipeline_verdict=$PIPELINE"
echo "  delivery_verdict=$DELIVERY"
echo "verdict_semantics_gate: OK"
