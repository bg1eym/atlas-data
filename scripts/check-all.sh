#!/usr/bin/env bash
# Global verification: runs UI contract test.
# Fails overall if contract test fails.
# Requires: dev server running (npm run ui:dev) and at least one run in out/atlas.

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

echo "=== Check All ==="

# P0.1: Policy doc must exist
if [ ! -f "${ROOT}/environment/policies/OPEN_SOURCE_PARITY.md" ]; then
  echo "FAIL: environment/policies/OPEN_SOURCE_PARITY.md missing"
  exit 1
fi

# P0.2: Parity guard (highest priority - must pass before any business checks)
if [ ! -f "${ROOT}/scripts/parity_guard.sh" ]; then
  echo "FAIL: scripts/parity_guard.sh missing"
  exit 1
fi
bash "${ROOT}/scripts/parity_guard.sh" || exit 1

# Input pack gate (blocking)
bash "${ROOT}/scripts/input_pack_gate.sh"

# Classification sanity (blocking)
bash "${ROOT}/scripts/classification_sanity.sh"

# Summary gate (requires items_civ.json from a run)
bash "${ROOT}/scripts/summary_gate.sh"

# Drilldown integrity gate
bash "${ROOT}/scripts/drilldown_integrity_gate.sh"

# TG cover card sanity
bash "${ROOT}/scripts/tg_cover_card_sanity.sh"

# NL router sanity
bash "${ROOT}/scripts/nl_router_sanity.sh"

# TG slash router sanity
bash "${ROOT}/scripts/tg_slash_router_sanity.sh"

# Verdict semantics gate (blocking)
bash "${ROOT}/scripts/verdict_semantics_gate.sh"

echo "=== Check All PASS ==="
