#!/usr/bin/env bash
# Atlas Final Acceptance — One-shot verification (local, no TG).
# 1) preflight 2) regress 3) convergence 4) atlas-final-activation-audit
# Output: tools/_out/atlas-final-acceptance.txt

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUT_DIR="${ROOT}/tools/_out"
OUT_FILE="${OUT_DIR}/atlas-final-acceptance.txt"

mkdir -p "${OUT_DIR}"
: > "$OUT_FILE"

run() {
  echo "=== $* ===" | tee -a "$OUT_FILE"
  if "$@" 2>&1 | tee -a "$OUT_FILE"; then
    return 0
  else
    return 1
  fi
}

FAILED=0

run bash "${ROOT}/.project-control/04-gates/preflight.sh" || FAILED=1
run bash "${ROOT}/.project-control/04-gates/regress.sh" || FAILED=1
run bash "${ROOT}/.project-control/04-gates/convergence.sh" || FAILED=1
run bash "${ROOT}/tools/atlas-final-activation-audit.sh" || FAILED=1

# Verify audit conclusion
AUDIT_JSON="${OUT_DIR}/atlas-activation-audit.json"
if [ -f "$AUDIT_JSON" ]; then
  RC=$(python3 -c "import json; print(json.load(open('$AUDIT_JSON')).get('conclusion',{}).get('root_cause',''))" 2>/dev/null || echo "")
  if [ "$RC" = "UNKNOWN" ]; then
    echo "ACCEPTANCE FAIL: audit conclusion.root_cause is UNKNOWN" | tee -a "$OUT_FILE"
    FAILED=1
  fi
fi

# Verify classification (when ATLAS_* configured)
CLASS_JSON="${ROOT}/.project-control/07-critical-tests/_out/classification.json"
if [ -f "$CLASS_JSON" ] && [ -n "${ATLAS_ROOT:-}" ]; then
  MODE=$(python3 -c "import json; print(json.load(open('$CLASS_JSON')).get('failure_mode',''))" 2>/dev/null || echo "")
  if [ "$MODE" != "OK" ]; then
    echo "ACCEPTANCE: classification.failure_mode=$MODE (expected OK when atlas configured)" | tee -a "$OUT_FILE"
  fi
fi

if [ "$FAILED" -eq 1 ]; then
  echo "ACCEPTANCE FAIL" | tee -a "$OUT_FILE"
  exit 1
fi

echo "ACCEPTANCE PASS" | tee -a "$OUT_FILE"
exit 0
