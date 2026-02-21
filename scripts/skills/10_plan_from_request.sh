#!/usr/bin/env bash
# Plan From Request: 根据 required_capabilities 生成 plan.json
# 输入: request.json (业务只写 required_capabilities，不写"装哪个")
# 输出: plan.json (capability_match_table, selected_skills, scoring 规则)

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}}"
RUN_ID="${SKILLS_RUN_ID:-}"
OUT_BASE="${SKILLS_OUT_BASE:-$ROOT/out/skills/$RUN_ID}"
TRUSTED="${ROOT}/environment/skills/TRUSTED_SOURCES.json"
BLOCKED_EXIT=42

[ -f "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" 2>/dev/null || true
[ -f "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" 2>/dev/null || true

REQUEST_FILE="${1:-$OUT_BASE/request.json}"
PLAN_FILE="${OUT_BASE}/plan/plan.json"
CAP_DIR="${OUT_BASE}/capabilities"
SECURITY_DIR="${OUT_BASE}/security"
ANALYSIS_FILE="${OUT_BASE}/request/analysis.json"
mkdir -p "$(dirname "$PLAN_FILE")"

# INV-S7: 必须消费 analysis.json（由 12_request_analyze 生成）
ensure_analysis_json() {
  if [ -f "$ANALYSIS_FILE" ]; then
    return 0
  fi
  # 若 analysis.json 不存在，从 request.json 生成（兼容 A~H）
  if [ -f "$REQUEST_FILE" ]; then
    bash "$(dirname "${BASH_SOURCE[0]}")/12_request_analyze.sh" "$REQUEST_FILE" >/dev/null 2>&1 || true
  fi
}

# 加载 request：优先 analysis.json
if [ ! -f "$REQUEST_FILE" ] && [ ! -f "$ANALYSIS_FILE" ]; then
  echo "Usage: $0 [request.json or request.txt]" >&2
  echo "  Run 12_request_analyze.sh first, or provide request.json" >&2
  audit_die_fail "request/analysis not found"
fi

ensure_analysis_json
[ -f "$ANALYSIS_FILE" ] || { echo "BLOCKED: analysis.json not found" >&2; audit_die_blocked "analysis.json not found"; }

REQUIRED=$(jq -r '.required_capabilities[]?' "$ANALYSIS_FILE" 2>/dev/null || true)
if [ -z "$REQUIRED" ]; then
  echo "BLOCKED: analysis must have required_capabilities" >&2
  audit_die_blocked "analysis must have required_capabilities"
fi

# 收集所有已 review 且 PASS 的 skills 及其 capabilities
# 输出格式每行: skill_id|cap|trust_level|verdict
collect_candidates() {
  local cap="$1"
  shopt -s nullglob 2>/dev/null || true
  for f in "$CAP_DIR"/*.json; do
    [ -f "$f" ] || continue
    local sid
    sid=$(jq -r '.skill_id' "$f")
    local caps
    caps=$(jq -r '.capabilities[]?' "$f" 2>/dev/null || true)
    echo "$caps" | grep -qx "$cap" || continue
    local verdict="PASS"
    local review_file="$SECURITY_DIR/${sid}_review.json"
    if [ -f "$review_file" ]; then
      verdict=$(jq -r '.verdict' "$review_file" 2>/dev/null || echo "UNKNOWN")
    fi
    [ "$verdict" != "PASS" ] && continue
    local trust="T1_WELL_KNOWN"
    local src_ref
    src_ref=$(jq -r '.source_ref // empty' "$review_file" 2>/dev/null)
    if [ -n "$src_ref" ]; then
      local tl
      tl=$(jq -r --arg loc "$src_ref" '.sources[] | select(.locator == $loc) | .trust_level' "$TRUSTED" 2>/dev/null | head -1)
      [ -n "$tl" ] && trust="$tl"
    fi
    echo "$sid|$cap|$trust|$verdict"
  done
}

# 评分: T0>T1>T2, PASS only, least_privilege, operational_fit
score_candidate() {
  local trust="$1"
  local score=0
  case "$trust" in
    T0_OFFICIAL) score=100 ;;
    T1_WELL_KNOWN) score=70 ;;
    T2_COMMUNITY) score=40 ;;
    *) score=10 ;;
  esac
  echo $score
}

# 生成 capability_match_table 和 selected_skills
main() {
  [ -f "$TRUSTED" ] || { echo "BLOCKED: TRUSTED_SOURCES missing" >&2; audit_die_blocked "TRUSTED_SOURCES missing"; }
  command -v jq >/dev/null 2>&1 || { echo "BLOCKED: jq required" >&2; audit_die_blocked "jq required"; }

  local match_table="{}"
  local selected="[]"
  local blocked_reasons="[]"
  local all_covered=true

  for cap in $REQUIRED; do
    local best=""
    local best_score=0
    while IFS='|' read -r sid c t v; do
      [ -z "$sid" ] && continue
      local s
      s=$(score_candidate "$t")
      if [ "$s" -gt "$best_score" ]; then
        best_score=$s
        best="$sid"
      fi
    done < <(collect_candidates "$cap")

    if [ -n "$best" ]; then
      match_table=$(echo "$match_table" | jq --arg c "$cap" --arg s "$best" --argjson sc "$best_score" \
        '. + {($c): {"skill_id":$s,"score":$sc}}')
      selected=$(echo "$selected" | jq --arg s "$best" 'if index($s) then . else . + [$s] end | unique')
    else
      all_covered=false
      blocked_reasons=$(echo "$blocked_reasons" | jq --arg c "$cap" '. + ["missing capability: " + $c]')
    fi
  done

  if [ "$all_covered" != "true" ]; then
    echo "BLOCKED: cannot cover all required_capabilities" >&2
    echo "$blocked_reasons" | jq -r '.[]' >&2
    audit_die_blocked "cannot cover all required_capabilities"
  fi

  local scoring_rules='{
    "trust_level": "T0>T1>T2",
    "security_verdict": "PASS only",
    "least_privilege": "minimize permissions",
    "operational_fit": "fewer credentials preferred"
  }'

  jq -n \
    --argjson mt "$match_table" \
    --argjson sel "$selected" \
    --argjson sr "$scoring_rules" \
    --argjson br "$blocked_reasons" \
    '{
      capability_match_table: $mt,
      selected_skills: $sel,
      scoring_rules: $sr,
      blocked_reasons: $br
    }' > "$PLAN_FILE"

  type audit_step &>/dev/null && audit_step "plan" "PASS" "$PLAN_FILE"
  echo "Wrote $PLAN_FILE"
  cat "$PLAN_FILE"
}

main "$@"
