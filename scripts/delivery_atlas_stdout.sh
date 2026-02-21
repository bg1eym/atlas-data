#!/usr/bin/env bash
# Capture raw stdout for atlas acceptance runs.
# Saves to out/atlas/DELIVERY_RAW_STDOUT/

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
OUT_DIR="${ROOT}/out/atlas/DELIVERY_RAW_STDOUT"
mkdir -p "$OUT_DIR"
cd "$ROOT"

echo "=== Capturing atlas acceptance stdout to $OUT_DIR ==="

# 1) acceptance_atlas_local.sh (no token) => expect PASS
echo "Run 1: acceptance_atlas_local.sh (no token)"
set +e
env -u TELEGRAM_BOT_TOKEN -u TELEGRAM_CHAT_ID bash "$ROOT/scripts/acceptance_atlas_local.sh" 2>&1 | tee "$OUT_DIR/atlas_local_no_token.txt"
EC1=${PIPESTATUS[0]}
set -e
echo "Exit: $EC1 (expected 0 for PASS)"

# 2) acceptance_atlas_tg_e2e.sh (no token) => expect BLOCKED(42)
echo ""
echo "Run 2: acceptance_atlas_tg_e2e.sh (no token)"
set +e
env -u TELEGRAM_BOT_TOKEN -u TELEGRAM_CHAT_ID bash "$ROOT/scripts/acceptance_atlas_tg_e2e.sh" 2>&1 | tee "$OUT_DIR/atlas_tg_e2e_no_token.txt"
EC2=${PIPESTATUS[0]}
set -e
echo "Exit: $EC2 (expected 42 for BLOCKED)"

# 3) acceptance_atlas_tg_e2e.sh (RADAR_MOCK=1) => expect BLOCKED(42)
echo ""
echo "Run 3: acceptance_atlas_tg_e2e.sh (RADAR_MOCK=1)"
set +e
RADAR_MOCK=1 TELEGRAM_BOT_TOKEN=x TELEGRAM_CHAT_ID=y bash "$ROOT/scripts/acceptance_atlas_tg_e2e.sh" 2>&1 | tee "$OUT_DIR/atlas_tg_e2e_forbidden_env.txt"
EC3=${PIPESTATUS[0]}
set -e
echo "Exit: $EC3 (expected 42 for BLOCKED)"

echo ""
echo "Saved to $OUT_DIR"
