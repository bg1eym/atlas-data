#!/usr/bin/env bash
# RG-ACTF-001: ACTF evidence and classifier presence + dynamic run
# Static: 07-critical-tests files exist, critical-tests.sh exists, regress calls it
# Dynamic: Run critical-tests (no ACTF_CMD), verify classification.json exists with failure_mode

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ACTF_DIR="${ROOT}/.project-control/07-critical-tests"
GATES_DIR="${ROOT}/.project-control/04-gates"
REGRESS="${GATES_DIR}/regress.sh"

# Static: 4 core files
for f in test-matrix.json structural-guard.sh execution-sim.sh failure-classifier.cjs; do
  if [ ! -f "${ACTF_DIR}/${f}" ]; then
    echo "RG-ACTF-001 FAIL: ${ACTF_DIR}/${f} missing" >&2
    exit 1
  fi
done

# Static: critical-tests.sh exists
if [ ! -f "${GATES_DIR}/critical-tests.sh" ]; then
  echo "RG-ACTF-001 FAIL: critical-tests.sh missing" >&2
  exit 1
fi

# Static: regress.sh calls critical-tests.sh
if ! grep -q "critical-tests.sh" "${REGRESS}" 2>/dev/null; then
  echo "RG-ACTF-001 FAIL: regress.sh does not call critical-tests.sh" >&2
  exit 1
fi

# Dynamic: run critical-tests without ACTF_CMD (probe only)
export PCK_ROOT="${ROOT}"
export ACTF_CMD=""
unset ACTF_CMD
cd "${ROOT}"
if ! "${GATES_DIR}/critical-tests.sh" >/dev/null 2>&1; then
  echo "RG-ACTF-001 FAIL: critical-tests.sh failed (probe mode)" >&2
  exit 1
fi

# Verify classification.json exists and has failure_mode
CLASS_FILE="${ACTF_DIR}/_out/classification.json"
if [ ! -f "${CLASS_FILE}" ]; then
  echo "RG-ACTF-001 FAIL: classification.json not generated" >&2
  exit 1
fi

if ! python3 -c "
import json
j = json.load(open('${CLASS_FILE}'))
if 'failure_mode' not in j:
    raise SystemExit(1)
" 2>/dev/null; then
  echo "RG-ACTF-001 FAIL: classification.json missing failure_mode" >&2
  exit 1
fi

echo "RG-ACTF-001 PASS"
