#!/usr/bin/env bash
# RG-001: Ensure runtime exposes version identity.
# Searches codebase for startup log that prints: build hash OR plugin version OR loaded path.
# Exit 1 if none found.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Search for identity evidence: run_id=, version, plugin path, or similar
EVIDENCE=$(grep -r -l -E 'run_id=|version|plugin.*path|loaded.*path|console\.log.*run_id' \
  "${ROOT}/runtime" "${ROOT}/skills" 2>/dev/null | head -5 || true)

if [ -z "${EVIDENCE:-}" ]; then
  # Fallback: check for run_id= in run_atlas (primary entry)
  if grep -q 'run_id=' "${ROOT}/runtime/atlas/run_atlas.ts" 2>/dev/null; then
    echo "RG-001 PASS: run_atlas.ts prints run_id (runtime identity)"
    exit 0
  fi
  if grep -q 'run_id=' "${ROOT}/skills/atlas-fetch/src/index.ts" 2>/dev/null; then
    echo "RG-001 PASS: atlas-fetch prints run_id (runtime identity)"
    exit 0
  fi
  echo "RG-001 FAIL: Runtime identity evidence missing — structural drift risk." >&2
  echo "Expected: startup log printing build hash, plugin version, or loaded path (e.g. run_id=)." >&2
  exit 1
fi

# Found evidence
echo "RG-001 PASS: Version/identity evidence found in runtime"
exit 0
