#!/usr/bin/env bash
# OSS Hard-Learning: Emit Cursor Task
# Output: out/cursor_tasks/<ts>.txt or environment/skills/request.txt
# Combines parity_map + delta_spec into executable Cursor task

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OUT_DIR="${ROOT}/out/oss_learning"
TASKS_DIR="${ROOT}/out/cursor_tasks"
TEMPLATE="${ROOT}/environment/oss_learning/CURSOR_TASK_TEMPLATE.md"

mkdir -p "$TASKS_DIR"

PARITY_MAP="${OUT_DIR}/vendor_parity_map.json"
DELTA_SPEC="${OUT_DIR}/delta_spec.md"

if [ ! -f "$PARITY_MAP" ]; then
  echo "Run 20_parity_map.sh first" >&2
  exit 1
fi

if [ ! -f "$DELTA_SPEC" ]; then
  echo "Run 30_delta_spec.sh first" >&2
  exit 1
fi

TS=$(date +%Y%m%d_%H%M%S)
OUT_FILE="${TASKS_DIR}/oss_task_${TS}.txt"

{
  echo "# OSS Hard-Learning Cursor Task"
  echo ""
  echo "## Parity First (from vendor_parity_map.json)"
  jq -r '.mapping | to_entries[] | "- \(.key): vendor=\(.value.vendor_ref) our=\(.value.our_ref)"' "$PARITY_MAP" 2>/dev/null || true
  echo ""
  echo "## Delta Only (from delta_spec.md)"
  cat "$DELTA_SPEC"
  echo ""
  echo "## Acceptance"
  echo "- bash scripts/oss/90_acceptance_contract.sh => exit 0"
  echo "- bash scripts/ui_smoke_test.sh => exit 0"
} > "$OUT_FILE"

echo "Cursor task written to $OUT_FILE"
