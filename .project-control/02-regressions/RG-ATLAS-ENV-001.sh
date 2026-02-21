#!/usr/bin/env bash
# RG-ATLAS-ENV-001: Static checks for CT-ATLAS-ENV-001 and atlas-env-audit.sh.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ACTF_DIR="${ROOT}/.project-control/07-critical-tests"
REGRESS_DIR="${ROOT}/.project-control/02-regressions"

fail() { echo "RG-ATLAS-ENV-001 FAIL: $*" >&2; exit 1; }

# CT-ATLAS-ENV-001.sh exists
[ -f "${ACTF_DIR}/CT-ATLAS-ENV-001.sh" ] || fail "CT-ATLAS-ENV-001.sh not found"

# Referenced in test-matrix.json
grep -q "CT-ATLAS-ENV-001" "${ACTF_DIR}/test-matrix.json" 2>/dev/null || fail "CT-ATLAS-ENV-001 not in test-matrix.json"

# Referenced in critical-tests.sh
grep -q "CT-ATLAS-ENV-001" "${ROOT}/.project-control/04-gates/critical-tests.sh" 2>/dev/null || fail "CT-ATLAS-ENV-001 not in critical-tests.sh"

# tools/atlas-env-audit.sh exists
[ -f "${ROOT}/tools/atlas-env-audit.sh" ] || fail "atlas-env-audit.sh not found"

# atlas-env-audit.sh writes tools/_out/atlas-env-audit.json
mkdir -p "${ROOT}/tools/_out"
bash "${ROOT}/tools/atlas-env-audit.sh" >/dev/null 2>&1 || true
[ -f "${ROOT}/tools/_out/atlas-env-audit.json" ] || fail "atlas-env-audit.sh did not produce tools/_out/atlas-env-audit.json"

echo "RG-ATLAS-ENV-001 PASS"
exit 0
