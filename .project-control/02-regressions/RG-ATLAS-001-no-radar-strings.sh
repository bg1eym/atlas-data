#!/usr/bin/env bash
# RG-ATLAS-001: No forbidden radar strings in oc-bind plugin and README/help areas.
# Fails if repo contains: radar:run, OPENCLAW_ROOT, /atlas radar, radar_daily
# Allowlist: none (hard fail)

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OC_BIND_ROOT="${OC_BIND_ROOT:-}"
ATLAS_RADAR_ROOT="${ATLAS_RADAR_ROOT:-$ROOT}"

FORBIDDEN=(
  "radar:run"
  "OPENCLAW_ROOT"
  "/atlas radar"
  "radar_daily"
)

fail() {
  echo "RG-ATLAS-001 FAIL: $*" >&2
  exit 1
}

# Check atlas-radar tg/runtime files
TG_FILES="${ATLAS_RADAR_ROOT}/runtime/atlas/tg_nl_router.ts"
TG_FILES="${TG_FILES} ${ATLAS_RADAR_ROOT}/runtime/atlas/tg_nl_handler.ts"
for f in $TG_FILES; do
  if [ -f "$f" ]; then
    for pat in "${FORBIDDEN[@]}"; do
      if grep -q "$pat" "$f" 2>/dev/null; then
        fail "Forbidden string '$pat' found in $f"
      fi
    done
  fi
done

# Check oc-bind if path provided
if [ -n "${OC_BIND_ROOT:-}" ] && [ -d "$OC_BIND_ROOT" ]; then
  for f in "$OC_BIND_ROOT"/*.ts "$OC_BIND_ROOT"/*.json; do
    [ -f "$f" ] || continue
    for pat in "${FORBIDDEN[@]}"; do
      if grep -q "$pat" "$f" 2>/dev/null; then
        fail "Forbidden string '$pat' found in $f"
      fi
    done
  done
  if [ -f "$OC_BIND_ROOT/../README.md" ]; then
    for pat in "${FORBIDDEN[@]}"; do
      if grep -q "$pat" "$OC_BIND_ROOT/../README.md" 2>/dev/null; then
        fail "Forbidden string '$pat' found in README.md"
      fi
    done
  fi
fi

echo "RG-ATLAS-001 PASS: No forbidden radar strings"
exit 0
