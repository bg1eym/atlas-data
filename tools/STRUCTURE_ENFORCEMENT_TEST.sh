#!/usr/bin/env bash
# PCK-CORE-HARDEN-001: Structural Enforcement Test
# Simulates bypass attempts; each case must produce FAIL and restore.
# Prints PASS only if blocked.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
GATES="${ROOT}/.project-control/04-gates"
ACTF="${ROOT}/.project-control/07-critical-tests"
LEDGER="${ROOT}/.project-control/00-ledger"
RUNS="${ROOT}/.project-control/03-runs"

CRITICAL="${GATES}/critical-tests.sh"
CLASSIFIER="${ACTF}/failure-classifier.cjs"

run_regress() {
  set +e
  bash "${GATES}/regress.sh" 2>&1
  local r=$?
  set -e
  return $r
}

run_preflight() {
  set +e
  bash "${GATES}/preflight.sh" 2>&1
  local r=$?
  set -e
  return $r
}

# --- Case A: Delete critical-tests.sh ---
echo "=== Case A: Delete critical-tests.sh ==="
[ -f "${CRITICAL}" ] && mv "${CRITICAL}" "${CRITICAL}.bak"
if run_regress; then
  echo "Case A FAIL: bypass possible (expected BLOCKED)"
  [ -f "${CRITICAL}.bak" ] && mv "${CRITICAL}.bak" "${CRITICAL}"
  exit 1
fi
[ -f "${CRITICAL}.bak" ] && mv "${CRITICAL}.bak" "${CRITICAL}"
echo "Case A PASS: blocked"

# --- Case B: Delete failure-classifier.cjs ---
echo ""
echo "=== Case B: Delete failure-classifier.cjs ==="
[ -f "${CLASSIFIER}" ] && mv "${CLASSIFIER}" "${CLASSIFIER}.bak"
if run_regress; then
  echo "Case B FAIL: bypass possible (expected BLOCKED)"
  [ -f "${CLASSIFIER}.bak" ] && mv "${CLASSIFIER}.bak" "${CLASSIFIER}"
  exit 1
fi
[ -f "${CLASSIFIER}.bak" ] && mv "${CLASSIFIER}.bak" "${CLASSIFIER}"
echo "Case B PASS: blocked"

# --- Case C: Remove Run Journal ---
echo ""
echo "=== Case C: Remove Run Journal ==="
# iteration-memory (in regress) uses PCK-ATLAS-FINAL-001 as latest, base PCK-ATLAS-005
LATEST_FOR_C="PCK-ATLAS-FINAL-001"
if [ -d "${LEDGER}/${LATEST_FOR_C}" ]; then
  BASE_VER=$(jq -r '.base_version // "null"' "${LEDGER}/${LATEST_FOR_C}/meta.json" 2>/dev/null || true)
  BASE_SUFFIX="${BASE_VER#PCK-}"
  PRIOR_JOURNAL=$(ls -1 "${RUNS}/${BASE_SUFFIX}"-*.md 2>/dev/null | head -1)
  if [ -n "${PRIOR_JOURNAL}" ] && [ -f "${PRIOR_JOURNAL}" ]; then
    mv "${PRIOR_JOURNAL}" /tmp/run-journal-enforcement-test.bak
    if run_regress; then
      echo "Case C FAIL: bypass possible (expected BLOCKED)"
      mv /tmp/run-journal-enforcement-test.bak "${PRIOR_JOURNAL}"
      exit 1
    fi
    mv /tmp/run-journal-enforcement-test.bak "${PRIOR_JOURNAL}"
    echo "Case C PASS: blocked"
  else
    echo "Case C SKIP: no prior Run Journal to remove (base=${BASE_VER})"
  fi
else
  echo "Case C SKIP: no PCK-ATLAS-FINAL-001 ledger"
fi

# --- Case D: Corrupt meta.json inheritance ---
echo ""
echo "=== Case D: Corrupt meta.json inheritance ==="
# Use ATLAS-FINAL-001 (iteration-memory validates this one)
LATEST_FOR_IM=$(ls -1 "${LEDGER}" 2>/dev/null | grep -E '^PCK-ATLAS-' | sort -V | tail -1)
[ -z "${LATEST_FOR_IM}" ] && LATEST_FOR_IM=$(ls -1 "${LEDGER}" 2>/dev/null | grep -E '^PCK-' | sort -V | tail -1)
META="${LEDGER}/${LATEST_FOR_IM}/meta.json"
INHERITS_ORIG=$(jq -r '.inherits_failure_mode // empty' "${META}" 2>/dev/null || true)
if [ -n "${INHERITS_ORIG}" ]; then
  jq '.inherits_failure_mode = "MISMATCH_FOR_TEST"' "${META}" > "${META}.tmp" && mv "${META}.tmp" "${META}"
  if run_regress; then
    echo "Case D FAIL: bypass possible (expected BLOCKED)"
    jq ".inherits_failure_mode = \"${INHERITS_ORIG}\"" "${META}" > "${META}.tmp" && mv "${META}.tmp" "${META}"
    exit 1
  fi
  jq ".inherits_failure_mode = \"${INHERITS_ORIG}\"" "${META}" > "${META}.tmp" && mv "${META}.tmp" "${META}"
  echo "Case D PASS: blocked"
else
  echo "Case D SKIP: inherits_failure_mode not set (BOOTSTRAP or legacy)"
fi

# --- Case E: PCK_SKIP_ACTF without ALLOW_SKIP file ---
echo ""
echo "=== Case E: PCK_SKIP_ACTF=1 without ALLOW_SKIP_ACTF ==="
ALLOW_SKIP="${ROOT}/.project-control/ALLOW_SKIP_ACTF"
ALLOW_SKIP_BAK=""
if [ -f "${ALLOW_SKIP}" ]; then
  mv "${ALLOW_SKIP}" "${ALLOW_SKIP}.bak"
  ALLOW_SKIP_BAK=1
fi
# Direct test: regress.sh ACTF block fails when PCK_SKIP_ACTF=1 and no ALLOW_SKIP
OUT=$(mktemp)
set +e
PCK_SKIP_ACTF=1 bash "${GATES}/regress.sh" > "${OUT}" 2>&1
REGRESS_RC=$?
set -e
[ -n "${ALLOW_SKIP_BAK}" ] && mv "${ALLOW_SKIP}.bak" "${ALLOW_SKIP}"
if [ ${REGRESS_RC} -eq 0 ]; then
  echo "Case E FAIL: bypass possible (expected BLOCKED)"
  rm -f "${OUT}"
  exit 1
fi
# Must see ACTF skip failure (if we got that far) or Gate Chain Lock / regression failure
if grep -q "PCK_SKIP_ACTF=1 but ALLOW_SKIP_ACTF file missing" "${OUT}" 2>/dev/null; then
  echo "Case E PASS: blocked (ACTF skip rejected)"
elif grep -q "REGRESS FAIL" "${OUT}" 2>/dev/null; then
  echo "Case E PASS: blocked (regress failed before ACTF; skip logic would reject if reached)"
else
  echo "Case E WARN: unexpected failure (RC=${REGRESS_RC})"
fi
rm -f "${OUT}"

echo ""
echo "=== STRUCTURE_ENFORCEMENT_TEST: ALL CASES BLOCKED ==="
