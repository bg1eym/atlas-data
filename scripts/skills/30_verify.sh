#!/usr/bin/env bash
# Verify: 能力验证 + 副作用验证
# INV-S4: requires_env 与 verify 强绑定，缺失 => BLOCKED(42)
# - 能力验证: 声明了 requires_env 就必须已设置（缺 => BLOCKED）
# - 副作用验证: 不得泄露内部路径/entry/git/cwd

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}}"
RUN_ID="${SKILLS_RUN_ID:-}"
OUT_BASE="${SKILLS_OUT_BASE:-$ROOT/out/skills/$RUN_ID}"
PLAN_FILE="${OUT_BASE}/plan/plan.json"
CAP_DIR="${OUT_BASE}/capabilities"
VERIFY_DIR="${OUT_BASE}/verify"
SKILLS_DIR="${ROOT}/skills"
BLOCKED_EXIT=42

[ -f "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" 2>/dev/null || true
[ -f "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" 2>/dev/null || true

mkdir -p "$VERIFY_DIR"

# INV-S4: 检查 requires_env 中每个变量是否已设置，缺失 => BLOCKED
check_credentials() {
  local sid="$1"
  local cap_file="$CAP_DIR/${sid}.json"
  [ -f "$cap_file" ] || return 0
  local envs
  envs=$(jq -r '.requires_env[]?' "$cap_file" 2>/dev/null || true)
  for e in $envs; do
    [ -z "$e" ] && continue
    eval "val=\${$e:-}"
    if [ -z "${val:-}" ]; then
      echo "BLOCKED: $sid requires $e but it is not set (INV-S4)"
      return 1
    fi
  done
  return 0
}

# 副作用验证: 检查 skill 文档/脚本是否包含敏感路径泄露模式
check_no_leak() {
  local sid="$1"
  local path="$SKILLS_DIR/$sid"
  [ -d "$path" ] || return 0
  local leak_patterns=".git/|/Users/|/home/|/tmp/.*openclaw|OPENCLAW_ROOT|ATLAS_RADAR_ROOT|entry point"
  if grep -rE "$leak_patterns" "$path" --include="*.md" --include="*.sh" 2>/dev/null | grep -v "example\|Example\|documentation" | head -1; then
    echo "WARN: possible path leak in $sid"
    return 1
  fi
  return 0
}

main() {
  [ -f "$PLAN_FILE" ] || { echo "BLOCKED: plan.json not found" >&2; audit_die_blocked "plan.json not found"; }

  local selected
  selected=$(jq -r '.selected_skills[]' "$PLAN_FILE" 2>/dev/null || true)
  [ -z "$selected" ] && { echo "No selected_skills"; exit 0; }

  local results="[]"
  local any_blocked=false

  for sid in $selected; do
    local result="PASS"
    if ! check_credentials "$sid"; then
      result="BLOCKED"
      any_blocked=true
    fi
    check_no_leak "$sid" || result="FAIL"

    results=$(echo "$results" | jq --arg s "$sid" --arg r "$result" '. + [{"skill_id":$s,"verdict":$r}]')
    echo "$sid: $result"
  done

  echo "$results" | jq -s 'add' > "$VERIFY_DIR/verify_report.json"

  if [ "$any_blocked" = "true" ]; then
    type audit_step &>/dev/null && audit_step "verify" "BLOCKED" "$VERIFY_DIR/verify_report.json"
    echo "BLOCKED: one or more skills require credentials that are not set (INV-S4)" >&2
    audit_die_blocked "INV-S4 requires_env not set"
  fi

  type audit_step &>/dev/null && audit_step "verify" "PASS" "$VERIFY_DIR/verify_report.json"
  echo "Verify phase complete."
}

main "$@"
