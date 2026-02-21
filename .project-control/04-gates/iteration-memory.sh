#!/usr/bin/env bash
# PCK Iteration Memory Gate v2 — Enforce evidence-first workflow + semantic binding.
# A) Latest ledger exists and meta.json present
# B) Run Journal exists for previous iteration (unless BOOTSTRAP)
# C) Extract failure_mode, root_cause, recommended_fix → iteration-context.json
# D) Validate meta.json: inherits_failure_mode, declared_fix_target, verification_strategy

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LEDGER="${ROOT}/.project-control/00-ledger"
RUNS="${ROOT}/.project-control/03-runs"
CONTEXT_JSON="${ROOT}/.project-control/iteration-context.json"

fail() {
  echo "ITERATION-MEMORY FAIL: $*" >&2
  exit 1
}

# A) Latest ledger exists and meta.json present
LATEST=$(ls -1 "${LEDGER}" 2>/dev/null | grep -E '^PCK-ATLAS-' | sort -V | tail -1)
if [ -z "${LATEST:-}" ]; then
  LATEST=$(ls -1 "${LEDGER}" 2>/dev/null | grep -E '^PCK-' | sort -V | tail -1)
fi
if [ -z "${LATEST:-}" ]; then
  fail "No ledger version found under ${LEDGER}. Run preflight first."
fi

VERSION_DIR="${LEDGER}/${LATEST}"
META="${VERSION_DIR}/meta.json"
if [ ! -f "${META}" ]; then
  fail "meta.json missing: ${META}"
fi

# B+C) For non-BOOTSTRAP: Run Journal must exist for base_version
BASE_VER=$(jq -r '.base_version // "null"' "${META}" 2>/dev/null || true)
if [ "${BASE_VER}" = "null" ] || [ -z "${BASE_VER:-}" ]; then
  echo "=== Iteration Memory PASS (BOOTSTRAP / no base_version, skip prior-run check) ==="
  exit 0
fi

if [ "${BASE_VER}" = "PCK-BOOTSTRAP-000" ]; then
  echo "=== Iteration Memory PASS (base is BOOTSTRAP, skip prior-run check) ==="
  exit 0
fi

# Extract task suffix from base_version
BASE_SUFFIX="${BASE_VER#PCK-}"
if [ -z "${BASE_SUFFIX}" ] || [ "${BASE_SUFFIX}" = "${BASE_VER}" ]; then
  fail "Cannot derive run journal suffix from base_version: ${BASE_VER}"
fi

PRIOR_JOURNAL=$(ls -1 "${RUNS}/${BASE_SUFFIX}"-*.md 2>/dev/null | head -1)
if [ -z "${PRIOR_JOURNAL:-}" ] || [ ! -f "${PRIOR_JOURNAL}" ]; then
  fail "Prior Run Journal missing for ${BASE_VER}. Expected: ${RUNS}/${BASE_SUFFIX}-*.md"
fi

if [ ! -s "${PRIOR_JOURNAL}" ]; then
  fail "Prior Run Journal is empty: ${PRIOR_JOURNAL}"
fi

# Section 2A: Extract failure_mode, root_cause, recommended_fix from prior journal
extract_field() {
  grep -E "^${1}\s*[:=]" "${PRIOR_JOURNAL}" 2>/dev/null | head -1 | sed -E "s/^${1}[[:space:]]*[:=][[:space:]]*//" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || echo ""
}
PRIOR_FAILURE_MODE=$(extract_field "failure_mode")
PRIOR_ROOT_CAUSE=$(extract_field "root_cause")
PRIOR_RECOMMENDED_FIX=$(extract_field "recommended_fix")

# Normalize empty to empty string
PRIOR_FAILURE_MODE="${PRIOR_FAILURE_MODE:-}"
PRIOR_ROOT_CAUSE="${PRIOR_ROOT_CAUSE:-}"
PRIOR_RECOMMENDED_FIX="${PRIOR_RECOMMENDED_FIX:-}"

# Write iteration-context.json
export PRIOR_FAILURE_MODE PRIOR_ROOT_CAUSE PRIOR_RECOMMENDED_FIX PRIOR_JOURNAL BASE_VER CONTEXT_JSON
python3 -c "
import json, os
ctx = {
  'prior_failure_mode': os.environ.get('PRIOR_FAILURE_MODE', ''),
  'prior_root_cause': os.environ.get('PRIOR_ROOT_CAUSE', ''),
  'prior_recommended_fix': os.environ.get('PRIOR_RECOMMENDED_FIX', ''),
  'prior_journal': os.environ.get('PRIOR_JOURNAL', ''),
  'base_version': os.environ.get('BASE_VER', '')
}
with open(os.environ.get('CONTEXT_JSON', ''), 'w') as f:
  json.dump(ctx, f, indent=2)
"

# Section 2B: Task Declaration Binding — validate meta.json fields
INHERITS=$(jq -r '.inherits_failure_mode // empty' "${META}" 2>/dev/null || true)
DECLARED_FIX=$(jq -r '.declared_fix_target // empty' "${META}" 2>/dev/null || true)
VERIFICATION=$(jq -r '.verification_strategy // empty' "${META}" 2>/dev/null || true)

if [ -z "${DECLARED_FIX:-}" ]; then
  fail "meta.json must have declared_fix_target. Path: ${META}"
fi

if [ -z "${INHERITS:-}" ]; then
  fail "meta.json must have inherits_failure_mode. Path: ${META}"
fi
if [ "${INHERITS}" != "${PRIOR_FAILURE_MODE}" ]; then
  fail "inherits_failure_mode (${INHERITS}) does not match prior failure_mode (${PRIOR_FAILURE_MODE}) in ${PRIOR_JOURNAL}"
fi

# Section 2C: Fix Coverage Validation — verification_strategy must include test reference
if [ -z "${VERIFICATION:-}" ]; then
  fail "meta.json must have verification_strategy (include test/regression reference)"
fi
if ! echo "${VERIFICATION}" | grep -qE 'RG-|test|regression|ACTF'; then
  fail "verification_strategy must include test reference (RG-*, test, regression, or ACTF). Got: ${VERIFICATION}"
fi

echo "=== Iteration Memory PASS ==="
echo "Latest ledger: ${LATEST}"
echo "Base version: ${BASE_VER}"
echo "Prior run journal: ${PRIOR_JOURNAL}"
echo "Prior failure_mode: ${PRIOR_FAILURE_MODE}"
