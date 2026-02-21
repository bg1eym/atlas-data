#!/usr/bin/env bash
# Parity guard: enforces Open-Source Learning Contract.
# Checks: policy file, PARITY_MAP.md, upstream_evidence, upstream_locator.
# Exit 1 on any failure.

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

echo "=== Parity Guard ==="

# 1) Check environment/policies/OPEN_SOURCE_PARITY.md exists
POLICY="${ROOT}/environment/policies/OPEN_SOURCE_PARITY.md"
if [ ! -f "$POLICY" ]; then
  echo "FAIL: environment/policies/OPEN_SOURCE_PARITY.md does not exist."
  exit 1
fi
echo "  OK: OPEN_SOURCE_PARITY.md exists"

# 2) Check docs/parity/*/PARITY_MAP.md exists
PARITY_MAPS=()
while IFS= read -r -d '' f; do
  PARITY_MAPS+=("$f")
done < <(find "${ROOT}/docs/parity" -name "PARITY_MAP.md" -print0 2>/dev/null || true)

if [ ${#PARITY_MAPS[@]} -eq 0 ]; then
  echo "FAIL: No docs/parity/*/PARITY_MAP.md found."
  echo "  Create docs/parity/<upstream>/PARITY_MAP.md with upstream_locator and capability evidence."
  exit 1
fi
echo "  OK: Found ${#PARITY_MAPS[@]} PARITY_MAP.md"

# 3-5) Validate each PARITY_MAP.md
for PM in "${PARITY_MAPS[@]}"; do
  echo "  Checking $PM ..."

  # 4) upstream_locator at top (within first 15 lines)
  if ! head -15 "$PM" | grep -q "upstream_locator:"; then
    echo "FAIL: $PM must declare upstream_locator at top."
    exit 1
  fi

  # 5) upstream_locator path exists
  LOCATOR_LINE=$(grep -A1 "upstream_locator:" "$PM" | tail -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -z "$LOCATOR_LINE" ]; then
    echo "FAIL: $PM upstream_locator has no path."
    exit 1
  fi
  if [[ "$LOCATOR_LINE" == vendor/* ]]; then
    CHECK_PATH="${ROOT}/${LOCATOR_LINE}"
  else
    CHECK_PATH="${ROOT}/${LOCATOR_LINE}"
  fi
  if [ ! -d "$CHECK_PATH" ]; then
    echo "FAIL: upstream_locator path does not exist: $LOCATOR_LINE"
    exit 1
  fi

  # 3) At least 12 capability titles
  CAP_COUNT=$(grep -c "## Capability:" "$PM" 2>/dev/null || echo 0)
  if [ "$CAP_COUNT" -lt 12 ]; then
    echo "FAIL: $PM must have at least 12 capability titles (found $CAP_COUNT)."
    exit 1
  fi

  # 3) At least 24 upstream_evidence lines (12 capabilities x 2)
  TOTAL_EV=$(grep -c "upstream_evidence:" "$PM" 2>/dev/null || echo 0)
  if [ "$TOTAL_EV" -lt 24 ]; then
    echo "FAIL: $PM must have at least 24 upstream_evidence lines (found $TOTAL_EV)."
    exit 1
  fi

  # 3b) ARCH_NOTES.md must exist alongside PARITY_MAP
  PARITY_DIR=$(dirname "$PM")
  ARCH_NOTES="${PARITY_DIR}/ARCH_NOTES.md"
  if [ ! -f "$ARCH_NOTES" ]; then
    echo "FAIL: ARCH_NOTES.md must exist: $ARCH_NOTES"
    exit 1
  fi
  echo "  OK: ARCH_NOTES.md exists"

  # 3) Each upstream_evidence line must contain path (/) and symbol
  while IFS= read -r line; do
    if echo "$line" | grep -q "upstream_evidence:"; then
      if ! echo "$line" | grep -qE '/'; then
        echo "FAIL: upstream_evidence must contain path (with '/'): $line"
        exit 1
      fi
      if ! echo "$line" | grep -qE '[A-Za-z][A-Za-z0-9_]*'; then
        echo "FAIL: upstream_evidence must contain symbol (function/component/type name): $line"
        exit 1
      fi
    fi
  done < "$PM"
done

echo "=== Parity Guard PASS ==="
exit 0
