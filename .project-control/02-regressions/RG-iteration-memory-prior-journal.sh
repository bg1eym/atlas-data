#!/usr/bin/env bash
# RG: Iteration Memory Gate — Prior Run Journal must exist for non-BOOTSTRAP.
# Prevents: tasks modifying business logic without reading prior evidence.
# Runs iteration-memory.sh; if it fails, this regression fails.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
GATE="${ROOT}/.project-control/04-gates/iteration-memory.sh"

if [ ! -f "${GATE}" ]; then
  echo "RG-iteration-memory-prior-journal FAIL: iteration-memory.sh not found: ${GATE}" >&2
  exit 1
fi

if [ ! -x "${GATE}" ]; then
  echo "RG-iteration-memory-prior-journal FAIL: iteration-memory.sh not executable" >&2
  exit 1
fi

if ! "${GATE}"; then
  echo "RG-iteration-memory-prior-journal FAIL: iteration-memory gate failed" >&2
  exit 1
fi

echo "RG-iteration-memory-prior-journal PASS"
