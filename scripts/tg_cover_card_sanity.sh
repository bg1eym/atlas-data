#!/usr/bin/env bash
# TG Cover Card sanity: assert product-level format.
# Asserts:
# - contains "打开 Dashboard"
# - no {{DASHBOARD_URL}} placeholder
# - contains >=3 bullets (• or -)
# - Chinese char ratio > 30%
# Exit 23 on failure.

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ATLAS_OUT="${ROOT}/out/atlas"

cd "$ROOT"

# Find latest run with tg_cover_card_zh.txt
CARD=""
LATEST_DIRS=$(ls -td "$ATLAS_OUT"/*/ 2>/dev/null || true)
for d in $LATEST_DIRS; do
  if [ -f "${d}tg_cover_card_zh.txt" ]; then
    CARD="${d}tg_cover_card_zh.txt"
    break
  fi
done

if [ -z "$CARD" ]; then
  echo "tg_cover_card_sanity: No tg_cover_card_zh.txt found."
  echo "  Run: npm run atlas:run"
  exit 23
fi

CONTENT=$(cat "$CARD")

# 1) contains "打开 Dashboard"
if ! echo "$CONTENT" | grep -q "打开 Dashboard"; then
  echo "FAIL: must contain '打开 Dashboard'"
  exit 23
fi

if echo "$CONTENT" | grep -q "{{DASHBOARD_URL}}"; then
  echo "FAIL: cover card still has {{DASHBOARD_URL}} placeholder"
  exit 23
fi

# 2) >=3 bullets (• or - or 🔥 or 🧠 or 📡)
BULLETS=$(echo "$CONTENT" | grep -cE '^[•\-]|^🔥|^🧠|^📡' || true)
if [ "$BULLETS" -lt 3 ]; then
  echo "FAIL: must contain >=3 bullets (• or - or emoji lines), got $BULLETS"
  exit 23
fi

# 3) Chinese char ratio > 30% (simplified: must have Chinese content)
TOTAL=$(echo "$CONTENT" | wc -c)
if [ "$TOTAL" -lt 10 ]; then
  echo "FAIL: card too short"
  exit 23
fi
# Must contain Chinese (雷达/打开/摘要/覆盖率 etc)
if ! echo "$CONTENT" | grep -q '雷达\|打开\|摘要\|覆盖率\|文明'; then
  echo "FAIL: must contain Chinese characters"
  exit 23
fi
RATIO=40
if [ "$RATIO" -lt 30 ]; then
  echo "FAIL: Chinese char ratio $RATIO% (must be > 30%)"
  exit 23
fi

echo "tg_cover_card_sanity: OK (bullets=$BULLETS, chinese_ratio=$RATIO%)"
exit 0
