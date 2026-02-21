#!/usr/bin/env bash
# Deterministic sanity checks for Atlas TG NL router.

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
cd "$ROOT"

SAMPLES=(
  "今天的文明态势雷达"
  "给我最新AI时政雷达"
  "生成一份文明态势看板并发TG"
  "打开dashboard"
  "/atlas run"
)

echo "=== nl_router_sanity ==="
for s in "${SAMPLES[@]}"; do
  OUT=$(ATLAS_NL_TEXT="$s" npx tsx runtime/atlas/tg_nl_router.ts)
  INTENT=$(echo "$OUT" | jq -r '.intent // ""')
  if [ "$INTENT" != "atlas_run" ]; then
    echo "FAIL: input='$s' intent='$INTENT'"
    exit 1
  fi
  echo "PASS: '$s' => $INTENT"
done

HELP_CASE="明天天气怎么样"
HELP_OUT=$(ATLAS_NL_TEXT="$HELP_CASE" npx tsx runtime/atlas/tg_nl_router.ts)
HELP_INTENT=$(echo "$HELP_OUT" | jq -r '.intent // ""')
if [ "$HELP_INTENT" != "help" ]; then
  echo "FAIL: help case intent='$HELP_INTENT'"
  exit 1
fi
echo "PASS: '$HELP_CASE' => $HELP_INTENT"

echo "nl_router_sanity: OK"
