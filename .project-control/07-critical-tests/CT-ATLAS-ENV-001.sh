#!/usr/bin/env bash
# CT-ATLAS-ENV-001: Gateway ATLAS_ROOT must point to valid atlas-radar repo.
# Runs tools/atlas-env-audit.sh. Fails unless conclusion.root_cause == "OK".

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
AUDIT_SCRIPT="${ROOT}/tools/atlas-env-audit.sh"
OUT_JSON="${ROOT}/tools/_out/atlas-env-audit.json"

[ -f "$AUDIT_SCRIPT" ] || { echo "CT-ATLAS-ENV-001 FAIL: atlas-env-audit.sh not found"; exit 1; }

bash "$AUDIT_SCRIPT" >/dev/null 2>&1 || true

[ -f "$OUT_JSON" ] || { echo "CT-ATLAS-ENV-001 FAIL: $OUT_JSON not produced"; exit 1; }

ROOT_CAUSE=$(jq -r '.conclusion.root_cause // "UNKNOWN"' "$OUT_JSON")

if [ "$ROOT_CAUSE" != "OK" ]; then
  echo "CT-ATLAS-ENV-001 FAIL: root_cause=$ROOT_CAUSE"
  echo "Evidence: $OUT_JSON"
  echo "Summary: ATLAS_ROOT invalid or gateway env missing. Run: bash tools/atlas-env-audit.sh"
  exit 1
fi

echo "CT-ATLAS-ENV-001 PASS: root_cause=OK"
echo "Evidence: $OUT_JSON"
exit 0
