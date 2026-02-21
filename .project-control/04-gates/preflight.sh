#!/usr/bin/env bash
# PCK Preflight Gate — Verify ledger and snapshots exist and are valid.
# Exit 1 on failure. Print actionable message.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LEDGER="${ROOT}/.project-control/00-ledger"
CONTRACTS="${ROOT}/.project-control/01-contracts"
GATES="${ROOT}/.project-control/04-gates"

fail() {
  echo "PREFLIGHT FAIL: $*" >&2
  exit 1
}

# 1. Verify latest ledger version exists
LATEST=$(ls -1 "${LEDGER}" 2>/dev/null | grep -E '^PCK-' | sort -V | tail -1)
if [ -z "${LATEST:-}" ]; then
  fail "No ledger version found under ${LEDGER}. Expected at least one PCK-* directory."
fi

VERSION_DIR="${LEDGER}/${LATEST}"
if [ ! -d "${VERSION_DIR}" ]; then
  fail "Ledger version dir does not exist: ${VERSION_DIR}"
fi

# 2. Verify required snapshot files exist
for f in meta.json config.snapshot.json contract.snapshot.md wiring.snapshot.md rollback.md; do
  if [ ! -f "${VERSION_DIR}/${f}" ]; then
    fail "Required snapshot file missing: ${VERSION_DIR}/${f}"
  fi
done

# 3. Verify meta.json has task_id + intent
TASK_ID=$(jq -r '.task_id // empty' "${VERSION_DIR}/meta.json" 2>/dev/null || true)
INTENT=$(jq -r '.intent // empty' "${VERSION_DIR}/meta.json" 2>/dev/null || true)
if [ -z "${TASK_ID:-}" ]; then
  fail "meta.json must have task_id. Path: ${VERSION_DIR}/meta.json"
fi
if [ -z "${INTENT:-}" ]; then
  fail "meta.json must have intent. Path: ${VERSION_DIR}/meta.json"
fi

# 4. If base_version != null, verify referenced version exists
BASE_VER=$(jq -r '.base_version // "null"' "${VERSION_DIR}/meta.json" 2>/dev/null || true)
if [ "${BASE_VER}" != "null" ] && [ -n "${BASE_VER:-}" ]; then
  BASE_DIR="${LEDGER}/${BASE_VER}"
  if [ ! -d "${BASE_DIR}" ]; then
    fail "base_version ${BASE_VER} references non-existent ledger: ${BASE_DIR}"
  fi
fi

# 5. (Section 1B) For non-BOOTSTRAP: Run Journal must exist, >= 1KB, contain failure_mode
RUNS="${ROOT}/.project-control/03-runs"
if [ "${BASE_VER}" != "null" ] && [ -n "${BASE_VER:-}" ] && [ "${BASE_VER}" != "PCK-BOOTSTRAP-000" ]; then
  BASE_SUFFIX="${BASE_VER#PCK-}"
  if [ -z "${BASE_SUFFIX}" ] || [ "${BASE_SUFFIX}" = "${BASE_VER}" ]; then
    fail "Cannot derive run journal suffix from base_version: ${BASE_VER}"
  fi
  PRIOR_JOURNAL=$(ls -1 "${RUNS}/${BASE_SUFFIX}"-*.md 2>/dev/null | head -1)
  if [ -z "${PRIOR_JOURNAL:-}" ] || [ ! -f "${PRIOR_JOURNAL}" ]; then
    fail "Prior Run Journal missing for ${BASE_VER}. Expected: ${RUNS}/${BASE_SUFFIX}-*.md"
  fi
  SIZE=$(stat -f %z "${PRIOR_JOURNAL}" 2>/dev/null || stat -c %s "${PRIOR_JOURNAL}" 2>/dev/null || echo 0)
  if [ "${SIZE:-0}" -lt 1024 ]; then
    fail "Prior Run Journal too small (< 1KB): ${PRIOR_JOURNAL} (${SIZE} bytes)"
  fi
  if ! grep -qE 'failure_mode\s*[:=]' "${PRIOR_JOURNAL}" 2>/dev/null; then
    fail "Prior Run Journal missing failure_mode. Add '## Failure Classification' with failure_mode to: ${PRIOR_JOURNAL}"
  fi
fi

echo "=== Preflight PASS ==="
echo "Latest ledger: ${LATEST}"
