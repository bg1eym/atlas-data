#!/usr/bin/env bash
# Install: 只能对 plan.json 中 selected_skills 且 security PASS 的执行。
# 本脚本执行"逻辑安装"：确保 skill 已存在于 skills/ 目录。
# 实际从远程拉取由外部流程完成，此处仅校验 + 登记。

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}}"
RUN_ID="${SKILLS_RUN_ID:-}"
OUT_BASE="${SKILLS_OUT_BASE:-$ROOT/out/skills/$RUN_ID}"
PLAN_FILE="${OUT_BASE}/plan/plan.json"
SECURITY_DIR="${OUT_BASE}/security"
SKILLS_DIR="${ROOT}/skills"
BLOCKED_EXIT=42

[ -f "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" 2>/dev/null || true
[ -f "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" 2>/dev/null || true

# 仅安装 plan 中 selected_skills 且 security PASS 的
main() {
  [ -f "$PLAN_FILE" ] || { echo "BLOCKED: plan.json not found. Run 10_plan_from_request.sh first." >&2; audit_die_blocked "plan.json not found"; }

  local selected
  selected=$(jq -r '.selected_skills[]' "$PLAN_FILE" 2>/dev/null || true)
  [ -z "$selected" ] && { echo "No selected_skills in plan"; exit 0; }

  for sid in $selected; do
    local review_file="$SECURITY_DIR/${sid}_review.json"
    if [ ! -f "$review_file" ]; then
      echo "BLOCKED: no security review for $sid" >&2
      audit_die_blocked "no security review for $sid"
    fi
    local verdict
    verdict=$(jq -r '.verdict' "$review_file")
    if [ "$verdict" != "PASS" ]; then
      echo "BLOCKED: security verdict for $sid is $verdict, not PASS" >&2
      audit_die_blocked "security verdict for $sid is $verdict"
    fi

    local skill_path="$SKILLS_DIR/$sid"
    if [ ! -d "$skill_path" ]; then
      echo "SKIP: skill $sid not present at $skill_path (install from trusted source first)" >&2
      continue
    fi
    echo "OK: $sid installed at $skill_path"
  done

  type audit_step &>/dev/null && audit_step "install" "PASS" "$PLAN_FILE"
  echo "Install phase complete."
}

main "$@"
