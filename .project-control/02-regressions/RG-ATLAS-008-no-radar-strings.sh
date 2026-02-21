#!/usr/bin/env bash
# RG-ATLAS-008: No forbidden radar strings (same as RG-ATLAS-005).
# Forbid: radar:run, OPENCLAW_ROOT, /atlas radar, radar_daily, ACTION_RADAR

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OC_BIND_ROOT="${OC_BIND_ROOT:-}"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"
ATLAS_RADAR_ROOT="${ATLAS_RADAR_ROOT:-$ROOT}"

FORBIDDEN=("radar:run" "OPENCLAW_ROOT" "/atlas radar" "radar_daily" "ACTION_RADAR")

fail() { echo "RG-ATLAS-008-no-radar-strings FAIL: $*" >&2; exit 1; }

PLUGIN_DIR=""
[ -n "${OC_BIND_ROOT:-}" ] && [ -d "$OC_BIND_ROOT" ] && PLUGIN_DIR="$OC_BIND_ROOT"
[ -z "$PLUGIN_DIR" ] && [ -f "$OPENCLAW_JSON" ] && PLUGIN_DIR=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // empty' "$OPENCLAW_JSON" 2>/dev/null || true)

for f in "${ATLAS_RADAR_ROOT}/runtime/atlas/tg_nl_router.ts" "${ATLAS_RADAR_ROOT}/runtime/atlas/tg_nl_handler.ts"; do
  [ -f "$f" ] || continue
  for pat in "${FORBIDDEN[@]}"; do
    grep -q "$pat" "$f" 2>/dev/null && fail "Forbidden '$pat' in $f"
  done
done

if [ -n "$PLUGIN_DIR" ] && [ -d "$PLUGIN_DIR" ]; then
  for f in "$PLUGIN_DIR"/*.ts "$PLUGIN_DIR"/*.json; do
    [ -f "$f" ] || continue
    for pat in "${FORBIDDEN[@]}"; do
      grep -q "$pat" "$f" 2>/dev/null && fail "Forbidden '$pat' in $f"
    done
  done
fi

echo "RG-ATLAS-008-no-radar-strings PASS"
exit 0
