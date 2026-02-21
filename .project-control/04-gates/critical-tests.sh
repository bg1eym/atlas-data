#!/usr/bin/env bash
# ACTF Critical Tests Gate — Run structural + execution + classifier.
# Exit 4 if failure_mode != OK.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ACTF_DIR="${ROOT}/.project-control/07-critical-tests"
OUT_DIR="${ACTF_DIR}/_out"

export PCK_ROOT="${ROOT}"
cd "${ROOT}"

# 1. structural-guard.sh
"${ACTF_DIR}/structural-guard.sh" || true

# 2. execution-sim.sh (ACTF_CMD may be unset → probe only)
"${ACTF_DIR}/execution-sim.sh" || true

# 2a. CT-ATLAS-ENV-001 (gateway ATLAS_ROOT audit)
"${ACTF_DIR}/CT-ATLAS-ENV-001.sh" || true

# 2b. CT-ATLAS-008 run-today-local (adapter simulate)
if [ -n "${ATLAS_ROOT:-}" ] && [ -d "${ATLAS_ROOT}" ]; then
  "${ACTF_DIR}/CT-ATLAS-008-run-today-local.sh" || true
fi

# 2c. atlas-result-guard (only when ACTF_CMD ran atlas:run)
# Clear stale atlas-result-evidence when not running atlas test
if [ -z "${ACTF_CMD:-}" ] || ! echo "${ACTF_CMD}" | grep -q "atlas:run"; then
  rm -f "${OUT_DIR}/atlas-result-evidence.json"
else
  if [ -n "${ATLAS_ROOT:-}" ] && [ -d "${ATLAS_ROOT}" ]; then
    "${ACTF_DIR}/atlas-result-guard.sh" || true
  fi
fi

# 3. classifier
node "${ACTF_DIR}/failure-classifier.cjs"

# 4. Check classification
CLASS_FILE="${OUT_DIR}/classification.json"
if [ ! -f "${CLASS_FILE}" ]; then
  echo "ACTF FAIL: classification.json not found" >&2
  exit 4
fi

FAILURE_MODE=$(python3 -c "import json; print(json.load(open('${CLASS_FILE}')).get('failure_mode','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")

if [ "${FAILURE_MODE}" != "OK" ]; then
  echo "=== ACTF FAIL ===" >&2
  head -200 "${CLASS_FILE}" | cat
  exit 4
fi

echo "=== ACTF PASS ==="
