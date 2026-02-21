#!/usr/bin/env bash
# Load Runtime: 只加载 verify PASS 的技能
# 输出: runtime/skills/skills_enabled.json

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}}"
RUN_ID="${SKILLS_RUN_ID:-}"
OUT_BASE="${SKILLS_OUT_BASE:-$ROOT/out/skills/$RUN_ID}"
VERIFY_REPORT="${OUT_BASE}/verify/verify_report.json"
PLAN_FILE="${OUT_BASE}/plan/plan.json"
CAP_DIR="${OUT_BASE}/capabilities"
SECURITY_DIR="${OUT_BASE}/security"
RUNTIME_SKILLS="${ROOT}/runtime/skills"
ENABLED_FILE="${RUNTIME_SKILLS}/skills_enabled.json"

[ -f "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" 2>/dev/null || true
[ -f "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" 2>/dev/null || true

mkdir -p "$RUNTIME_SKILLS"

main() {
  [ -f "$VERIFY_REPORT" ] || { echo "BLOCKED: verify_report.json not found. Run 30_verify.sh first." >&2; audit_die_blocked "verify_report.json not found"; }

  local enabled="[]"
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  while read -r sid verdict; do
    [ "$verdict" != "PASS" ] && continue
    local rev=""
    local caps="[]"
    [ -f "$SECURITY_DIR/${sid}_review.json" ] && rev=$(jq -r '.pinned_revision // ""' "$SECURITY_DIR/${sid}_review.json")
    [ -f "$CAP_DIR/${sid}.json" ] && caps=$(jq '.capabilities' "$CAP_DIR/${sid}.json")
    enabled=$(echo "$enabled" | jq --arg s "$sid" --arg r "$rev" --argjson c "$caps" --arg t "$now" \
      '. + [{"skill_id":$s,"pinned_revision":$r,"capabilities":$c,"enabled_at":$t}]')
  done < <(jq -r '.[] | "\(.skill_id) \(.verdict)"' "$VERIFY_REPORT" 2>/dev/null)

  echo "$enabled" | jq '{enabled: ., updated_at: "'"$now"'"}' > "$ENABLED_FILE"
  type audit_step &>/dev/null && audit_step "load_runtime" "PASS" "$ENABLED_FILE"
  echo "Wrote $ENABLED_FILE"
  cat "$ENABLED_FILE"
  audit_die_pass
}

main "$@"
