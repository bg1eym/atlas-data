#!/usr/bin/env bash
# Skills Framework Guard v1.1 (atlas-radar)
# 强制检查：禁止自由搜索来源、禁止误导性措辞、audit 每步 summary。
# 任何不在 TRUSTED_SOURCES 的来源 → BLOCKED exit 42

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}}"
RUN_ID="${SKILLS_RUN_ID:-$(date +%Y%m%d%H%M%S)-$$}"
OUT_BASE="${ROOT}/out/skills/${RUN_ID}"
TRUSTED="${ROOT}/environment/skills/TRUSTED_SOURCES.json"

export ATLAS_RADAR_ROOT="$ROOT"
export OPENCLAW_ROOT="$ROOT"
export SKILLS_RUN_ID="$RUN_ID"
export SKILLS_OUT_BASE="$OUT_BASE"

[ -f "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" 2>/dev/null || true

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  audit_init
fi

if [ ! -f "$TRUSTED" ]; then
  echo "BLOCKED: TRUSTED_SOURCES.json not found at $TRUSTED" >&2
  audit_die_blocked "TRUSTED_SOURCES.json not found at $TRUSTED"
fi

for v in RADAR_MOCK RADAR_DRYRUN RADAR_DRY_RUN RADAR_PREVIEW RADAR_SKIP_CORE TG_MOCK TG_DRYRUN MOCK DRY_RUN PREVIEW; do
  eval "val=\${$v:-}"
  if [ -n "${val:-}" ]; then
    echo "BLOCKED: forbidden env $v is set" >&2
    audit_die_blocked "forbidden env $v is set"
  fi
done

source_in_trusted() {
  local locator="$1"
  if ! command -v jq >/dev/null 2>&1; then
    echo "BLOCKED: jq required for TRUSTED_SOURCES check" >&2
    audit_die_blocked "jq required for TRUSTED_SOURCES check"
  fi
  local found
  found=$(jq -r --arg loc "$locator" '
    .sources[] | select(.locator == $loc or ($loc | startswith(.locator | split("*")[0]))) | .id
  ' "$TRUSTED" 2>/dev/null | head -1)
  [ -n "$found" ]
}

export -f source_in_trusted 2>/dev/null || true

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  audit_step "guard" "PASS" "[]"
  echo "Guard OK. RUN_ID=$RUN_ID OUT_BASE=$OUT_BASE"
fi
