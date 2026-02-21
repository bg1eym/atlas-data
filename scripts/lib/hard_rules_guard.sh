#!/usr/bin/env bash
# Hard Rules Guard v1.3
# Validates HARD_RULES.json presence and forbidden env. Used by skills pipeline.

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}}"
HARD_RULES="${ROOT}/environment/HARD_RULES.json"

# Check HARD_RULES.json exists
if [ ! -f "$HARD_RULES" ]; then
  echo "BLOCKED: HARD_RULES.json not found at $HARD_RULES" >&2
  exit 42
fi

# Check forbidden env (from HARD_RULES.forbidden_env_exact + common)
FORBIDDEN_VARS=$(jq -r '.forbidden_env_exact[]?' "$HARD_RULES" 2>/dev/null | tr '\n' ' ')
for v in $FORBIDDEN_VARS RADAR_DRYRUN RADAR_DRY_RUN MOCK DRY_RUN PREVIEW; do
  eval "val=\${$v:-}"
  if [ -n "${val:-}" ]; then
    echo "BLOCKED: forbidden env $v is set" >&2
    exit 42
  fi
done

# OSS_HARD_LEARNING mode: check required artifacts when OSS_LEARNING_MODE=1 or vendor exists + learn context
if [ "${OSS_LEARNING_MODE:-0}" = "1" ] || [ -n "${OSS_LEARNING_FORCE:-}" ]; then
  OSS_OUT="${ROOT}/out/oss_learning"
  for f in vendor_parity_map.json delta_spec.md ui_parity_checklist.md; do
    if [ ! -f "${OSS_OUT}/$f" ]; then
      echo "BLOCKED (OSS_HARD_LEARNING): missing ${OSS_OUT}/$f" >&2
      exit 42
    fi
  done
  # Check parity_dimensions coverage in vendor_parity_map.json
  if ! jq -e '.mapping | keys | length > 0' "${OSS_OUT}/vendor_parity_map.json" >/dev/null 2>&1; then
    echo "BLOCKED (OSS_HARD_LEARNING): vendor_parity_map.json must have mapping with parity dimensions" >&2
    exit 42
  fi
  # Check delta_spec has "Vendor does not have" or "Not in vendor"
  if ! grep -qE "Vendor does not have|Not in vendor" "${OSS_OUT}/delta_spec.md" 2>/dev/null; then
    echo "BLOCKED (OSS_HARD_LEARNING): delta_spec.md must contain 'Vendor does not have' per delta" >&2
    exit 42
  fi
  echo "OSS hard learning artifacts OK."
fi

echo "Hard rules guard OK."
