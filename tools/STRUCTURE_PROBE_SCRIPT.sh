#!/usr/bin/env bash
# PCK-STRUCT-AUDIT-001: Structural Enforcement Probe
# Temporarily renames critical-tests.sh and failure-classifier.cjs, runs regress, restores.
# Proves whether structural enforcement is real or decorative.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
GATES="${ROOT}/.project-control/04-gates"
ACTF="${ROOT}/.project-control/07-critical-tests"

CRITICAL="${GATES}/critical-tests.sh"
CLASSIFIER="${ACTF}/failure-classifier.cjs"

restore() {
  [ -f "${CRITICAL}.bak" ] && mv "${CRITICAL}.bak" "${CRITICAL}" || true
  [ -f "${CLASSIFIER}.bak" ] && mv "${CLASSIFIER}.bak" "${CLASSIFIER}" || true
}
trap restore EXIT

echo "=== PROBE: Rename critical-tests.sh ==="
[ -f "${CRITICAL}" ] && mv "${CRITICAL}" "${CRITICAL}.bak"
echo "Running regress.sh..."
set +e; bash "${GATES}/regress.sh" 2>&1; REGRESS_EXIT=$?; set -e
[ $REGRESS_EXIT -eq 0 ] && echo "EXIT: 0 (BYPASS)" || echo "EXIT: non-zero (BLOCKED)"
restore
[ -f "${CRITICAL}" ] || { echo "Restore failed for critical-tests"; exit 1; }

echo ""
echo "=== PROBE: Rename failure-classifier.cjs ==="
[ -f "${CLASSIFIER}" ] && mv "${CLASSIFIER}" "${CLASSIFIER}.bak"
echo "Running regress.sh..."
set +e; bash "${GATES}/regress.sh" 2>&1; REGRESS_EXIT=$?; set -e
[ $REGRESS_EXIT -eq 0 ] && echo "EXIT: 0 (BYPASS)" || echo "EXIT: non-zero (BLOCKED)"
restore

echo ""
echo "=== PROBE COMPLETE ==="
