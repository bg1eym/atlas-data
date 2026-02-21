#!/usr/bin/env bash
# PCK Convergence Gate — Compare latest vs previous contract.snapshot.md.
# If changed AND structural_scope does NOT contain "contract:update", exit 1.
# File-diff based. No heuristics.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LEDGER="${ROOT}/.project-control/00-ledger"

# Get latest and previous versions (POSIX-compatible)
VERSIONS=$(ls -1 "${LEDGER}" 2>/dev/null | grep -E '^PCK-' | sort -V)
LATEST=$(echo "${VERSIONS}" | tail -1)
PREVIOUS=""
if [ "$(echo "${VERSIONS}" | wc -l)" -gt 1 ]; then
  PREVIOUS=$(echo "${VERSIONS}" | tail -2 | head -1)
fi

if [ -z "${LATEST:-}" ]; then
  echo "CONVERGENCE FAIL: No ledger version found" >&2
  exit 1
fi

LATEST_CONTRACT="${LEDGER}/${LATEST}/contract.snapshot.md"
if [ ! -f "${LATEST_CONTRACT}" ]; then
  echo "CONVERGENCE FAIL: Latest contract.snapshot.md not found: ${LATEST_CONTRACT}" >&2
  exit 1
fi

# If no previous version, nothing to compare — pass
if [ -z "${PREVIOUS:-}" ]; then
  echo "=== Convergence PASS (no previous version to compare) ==="
  exit 0
fi

PREV_CONTRACT="${LEDGER}/${PREVIOUS}/contract.snapshot.md"
if [ ! -f "${PREV_CONTRACT}" ]; then
  echo "=== Convergence PASS (previous contract missing, skip diff) ==="
  exit 0
fi

# Check if contract changed (file diff)
if diff -q "${PREV_CONTRACT}" "${LATEST_CONTRACT}" >/dev/null 2>&1; then
  echo "=== Convergence PASS (contract unchanged) ==="
  exit 0
fi

# Contract changed — check structural_scope for contract:update
SCOPE=$(jq -r '.structural_scope | join(" ")' "${LEDGER}/${LATEST}/meta.json" 2>/dev/null || echo "")
if echo "${SCOPE}" | grep -q 'contract:update'; then
  echo "=== Convergence PASS (contract:update in structural_scope) ==="
  exit 0
fi

echo "CONVERGENCE FAIL: contract.snapshot.md changed but structural_scope does not contain 'contract:update'" >&2
echo "Latest: ${LATEST}" >&2
echo "Add 'contract:update' to structural_scope in meta.json if this change is intentional." >&2
exit 1
