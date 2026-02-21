#!/usr/bin/env bash
# RG-ATLAS-007: Human-Simulation Convergence Validation
# Runs atlas-007-human-simulation.sh; FAIL if convergence_status != "converged"

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SIM_SCRIPT="${ROOT}/tools/atlas-007-human-simulation.sh"
EVIDENCE_JSON="${ROOT}/tools/_out/atlas-007-evidence.json"

fail() {
  echo "RG-ATLAS-007 FAIL: $*" >&2
  exit 1
}

if [ ! -f "$SIM_SCRIPT" ]; then
  fail "atlas-007-human-simulation.sh not found: $SIM_SCRIPT"
fi

# Run human simulation (script exits 1 if not converged)
if ! bash "$SIM_SCRIPT"; then
  STATUS=$(jq -r '.convergence_status // "unknown"' "$EVIDENCE_JSON" 2>/dev/null || echo "unknown")
  fail "convergence_status=$STATUS (not converged)"
fi

echo "RG-ATLAS-007 PASS: human-simulation converged"
exit 0
