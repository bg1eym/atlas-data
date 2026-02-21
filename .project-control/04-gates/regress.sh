#!/usr/bin/env bash
# PCK Regression Gate — Execute all scripts in 02-regressions/.
# Fail if any exit 1.
# PCK v5: Gate Chain Lock + PCK_SKIP_ACTF requires ALLOW_SKIP_ACTF.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
REGRESS_DIR="${ROOT}/.project-control/02-regressions"
GATES="${ROOT}/.project-control/04-gates"
ACTF="${ROOT}/.project-control/07-critical-tests"

# Gate Chain Lock (Section 1C): verify mandatory scripts exist before any execution
CRITICAL="${GATES}/critical-tests.sh"
CLASSIFIER="${ACTF}/failure-classifier.cjs"
ITERATION_MEMORY="${GATES}/iteration-memory.sh"

if [ ! -f "${CRITICAL}" ] || [ ! -x "${CRITICAL}" ]; then
  echo "REGRESS FAIL: critical-tests.sh missing or not executable: ${CRITICAL}" >&2
  exit 1
fi
if [ ! -f "${CLASSIFIER}" ]; then
  echo "REGRESS FAIL: failure-classifier.cjs missing: ${CLASSIFIER}" >&2
  exit 1
fi
if [ ! -f "${ITERATION_MEMORY}" ] || [ ! -x "${ITERATION_MEMORY}" ]; then
  echo "REGRESS FAIL: iteration-memory.sh missing or not executable: ${ITERATION_MEMORY}" >&2
  exit 1
fi

if [ ! -d "${REGRESS_DIR}" ]; then
  echo "REGRESS FAIL: 02-regressions directory not found: ${REGRESS_DIR}" >&2
  exit 1
fi

FAILED=0
for script in "${REGRESS_DIR}"/*.sh; do
  if [ -f "${script}" ] && [ -x "${script}" ]; then
    if ! "${script}"; then
      echo "REGRESS FAIL: ${script}" >&2
      FAILED=1
    fi
  fi
done

if [ "${FAILED}" -eq 1 ]; then
  exit 1
fi

# ACTF critical tests (Section 1A: PCK_SKIP_ACTF requires ALLOW_SKIP_ACTF)
if [ "${PCK_SKIP_ACTF:-0}" = "1" ]; then
  ALLOW_SKIP="${ROOT}/.project-control/ALLOW_SKIP_ACTF"
  if [ ! -f "${ALLOW_SKIP}" ]; then
    echo "REGRESS FAIL: PCK_SKIP_ACTF=1 but ALLOW_SKIP_ACTF file missing" >&2
    echo "WARNING: ACTF skip requires .project-control/ALLOW_SKIP_ACTF with reason, approved_by, timestamp" >&2
    exit 1
  fi
  if ! jq -e '.reason != null and .approved_by != null and .timestamp != null' "${ALLOW_SKIP}" >/dev/null 2>&1; then
    echo "REGRESS FAIL: ALLOW_SKIP_ACTF must contain reason, approved_by, timestamp" >&2
    exit 1
  fi
  echo "ACTF SKIPPED (PCK_SKIP_ACTF=1; ALLOW_SKIP_ACTF present; record in Run Journal)" >&2
else
  if ! "${CRITICAL}"; then
    echo "REGRESS FAIL: critical-tests.sh" >&2
    exit 1
  fi
fi

echo "=== Regress PASS ==="
