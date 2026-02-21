#!/usr/bin/env bash
# OSS Hard-Learning: Acceptance Contract
# Gates: required_artifacts exist, parity_dimensions covered, delta has "Not in vendor"
# Exit 1 if any check fails

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OUT_DIR="${ROOT}/out/oss_learning"
POLICY="${ROOT}/environment/oss_learning/OSS_LEARNING_POLICY.json"

FAIL=0

# 1) Required artifacts exist
REQUIRED=("vendor_parity_map.json" "ui_parity_checklist.md" "delta_spec.md")
for f in "${REQUIRED[@]}"; do
  if [ ! -f "${OUT_DIR}/$f" ]; then
    echo "FAIL: missing required artifact: out/oss_learning/$f" >&2
    FAIL=1
  fi
done

# 2) vendor_parity_map.json covers parity_dimensions
if [ -f "${OUT_DIR}/vendor_parity_map.json" ]; then
  DIMS=$(jq -r '.parity_dimensions[]?' "${OUT_DIR}/vendor_parity_map.json" 2>/dev/null || true)
  VENDOR_REF="${ROOT}/environment/oss_learning/VENDOR_REFERENCE.json"
  EXPECTED_DIMS=$(jq -r '.parity_dimensions[]?' "$VENDOR_REF" 2>/dev/null || echo "Layout")
  for d in $EXPECTED_DIMS; do
    if ! echo "$DIMS" | grep -qF "$d" 2>/dev/null; then
      MAP_KEYS=$(jq -r '.mapping | keys[]?' "${OUT_DIR}/vendor_parity_map.json" 2>/dev/null || true)
      if ! echo "$MAP_KEYS" | grep -qF "$d" 2>/dev/null; then
        echo "FAIL: parity dimension '$d' not covered in vendor_parity_map.json" >&2
        FAIL=1
      fi
    fi
  done
fi

# 3) delta_spec.md each delta has "Not in vendor" or "Vendor does not have"
if [ -f "${OUT_DIR}/delta_spec.md" ]; then
  if ! grep -qE "Vendor does not have|Not in vendor" "${OUT_DIR}/delta_spec.md" 2>/dev/null; then
    echo "FAIL: delta_spec.md must contain 'Vendor does not have' or 'Not in vendor' per delta" >&2
    FAIL=1
  fi
fi

if [ $FAIL -eq 1 ]; then
  exit 1
fi

echo "OSS acceptance contract OK."
