#!/usr/bin/env bash
# TG slash router sanity: assert /atlas run, /radar schedule test route to internal handler.
# Must NOT produce "executable not found" or similar.
# Exit 1 on failure.

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

echo "=== TG Slash Router Sanity ==="

SAMPLES=("/atlas run" "/radar schedule test")
for input in "${SAMPLES[@]}"; do
  OUT=$(ATLAS_NL_TEXT="$input" npx tsx runtime/atlas/tg_nl_router.ts 2>&1 || true)
  if echo "$OUT" | grep -qi "executable not found\|command not found\|ENOENT"; then
    echo "FAIL: '$input' produced executable-not-found style error"
    echo "$OUT"
    exit 1
  fi
  INTENT=$(echo "$OUT" | node -e "
    const s = require('fs').readFileSync(0,'utf8');
    const m = s.match(/\{\s*\"intent\"\s*:\s*\"([^\"]+)\"/);
    console.log(m ? m[1] : '');
  " 2>/dev/null || echo "")
  if [ "$INTENT" != "atlas_run" ]; then
    echo "FAIL: '$input' => intent=$INTENT (expected atlas_run)"
    echo "$OUT"
    exit 1
  fi
  echo "PASS: '$input' => atlas_run"
done

echo "tg_slash_router_sanity: OK"
