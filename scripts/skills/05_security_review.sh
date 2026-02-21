#!/usr/bin/env bash
# Security Review: 装之前必须过。未通过禁止进入 install。
# INV-S1: risk_flags shell_exec => review_level>=L1; external_network => >=L2
# INV-S6: PASS 必须含 pinned_revision, license_detected, top_level_deps, install_hooks_scan

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}}"
RUN_ID="${SKILLS_RUN_ID:-}"
OUT_BASE="${SKILLS_OUT_BASE:-$ROOT/out/skills/$RUN_ID}"
TRUSTED="${ROOT}/environment/skills/TRUSTED_SOURCES.json"
POLICY="${ROOT}/environment/skills/SECURITY_POLICY.json"
CAP_DIR="${OUT_BASE}/capabilities"
BLOCKED_EXIT=42
FAIL_EXIT=1

# Load guard + lib_audit early (before usage which may call audit_die_fail)
[ -f "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" 2>/dev/null || true
[ -f "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" 2>/dev/null || true

usage() {
  echo "Usage: $0 <source_locator> <pinned_revision> [skill_id]" >&2
  echo "  source_locator: e.g. anthropic/skills or owner/repo" >&2
  echo "  pinned_revision: commit SHA (40 chars) or npm version (e.g. 1.2.3)" >&2
  audit_die_fail "invalid usage"
}

[ $# -ge 2 ] || usage

SOURCE_LOCATOR="$1"
PINNED_REV="$2"
SKILL_ID="${3:-$(echo "$SOURCE_LOCATOR" | tr '/' '_' | tr ':' '_')}"

REVIEW_DIR="${OUT_BASE}/security"
REVIEW_FILE="${REVIEW_DIR}/${SKILL_ID}_review.json"
mkdir -p "$REVIEW_DIR"

# 加载 guard 的 source_in_trusted
source_in_trusted() {
  local locator="$1"
  if ! command -v jq >/dev/null 2>&1; then return 1; fi
  local found
  found=$(jq -r --arg loc "$locator" '
    .sources[] | select(
      .locator == $loc or
      (.locator | endswith("*") and ($loc | startswith(.locator[0:-1])))
    ) | .id
  ' "$TRUSTED" 2>/dev/null | head -1)
  [ -n "$found" ]
}

# 从 SKILL.md 解析 review_level（L0/L1/L2）
parse_review_level() {
  local skill_path="$ROOT/skills/$SKILL_ID"
  local rl="L0"
  if [ -f "$skill_path/SKILL.md" ]; then
    local yaml
    yaml=$(sed -n '/^---$/,/^---$/p' "$skill_path/SKILL.md" 2>/dev/null | head -20)
    if echo "$yaml" | grep -q "review_level:"; then
      rl=$(echo "$yaml" | grep "review_level:" | head -1 | sed 's/.*review_level:[ 	]*\(L[0-2]\).*/\1/' | tr -d ' ')
      case "$rl" in L0|L1|L2) ;; *) rl="L0" ;; esac
    fi
  fi
  echo "$rl"
}

# 初始化 review 输出
init_review() {
  local rl
  rl=$(parse_review_level)
  cat <<EOF
{
  "skill_id": "$SKILL_ID",
  "source_ref": "$SOURCE_LOCATOR",
  "pinned_revision": "$PINNED_REV",
  "review_level": "$rl",
  "findings": [],
  "verdict": "PENDING"
}
EOF
}

# 检查 1: 来源是否在 TRUSTED_SOURCES
check_provenance() {
  if ! source_in_trusted "$SOURCE_LOCATOR"; then
    echo "FAIL: source $SOURCE_LOCATOR not in TRUSTED_SOURCES allowlist"
    return 1
  fi
  return 0
}

# 检查 2: revision 是否 pinned
check_pinned() {
  # GitHub: 40-char SHA 或 7-char short
  if [[ "$PINNED_REV" =~ ^[a-fA-F0-9]{7,40}$ ]]; then
    return 0
  fi
  # npm: semver
  if [[ "$PINNED_REV" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    return 0
  fi
  # 本地 repo 可用 HEAD 若 skill 已存在（在 main 中会解析为 SHA）
  if [ "$PINNED_REV" = "HEAD" ] && [ -d "$ROOT/skills/$SKILL_ID" ]; then
    return 0
  fi
  echo "FAIL: revision must be pinned (commit SHA or npm version), got: $PINNED_REV"
  return 1
}

# 检查 3: license (从本地 skills 或 package.json 或 repo 根推断)
check_license() {
  local skill_path="$ROOT/skills/$SKILL_ID"
  local lic=""
  if [ -f "$skill_path/package.json" ]; then
    lic=$(jq -r '.license // empty' "$skill_path/package.json" 2>/dev/null || true)
  fi
  if [ -z "$lic" ] && [ -f "$skill_path/LICENSE" ]; then
    lic="detected"
  fi
  # 内部 skill（openclaw 自带）使用 repo 根 LICENSE
  if [ -z "$lic" ] && [ -f "$ROOT/LICENSE" ]; then
    local first_line
    first_line=$(head -1 "$ROOT/LICENSE" 2>/dev/null || true)
    if echo "$first_line" | grep -qi "MIT\|Apache\|BSD"; then
      lic="detected"
    fi
  fi
  if [ -z "$lic" ]; then
    echo "BLOCKED: cannot verify license (skill not yet fetched or no package.json)"
    return 1
  fi
  local forbidden
  forbidden=$(jq -r '.forbidden_license[]' "$POLICY" 2>/dev/null | tr '\n' ' ')
  for f in $forbidden; do
    if [[ "$lic" == *"$f"* ]]; then
      echo "FAIL: forbidden license $f"
      return 1
    fi
  done
  return 0
}

# 检查 4: postinstall/preinstall
check_install_hooks() {
  local skill_path="$ROOT/skills/$SKILL_ID"
  if [ ! -f "$skill_path/package.json" ]; then
    return 0
  fi
  local hooks
  hooks=$(jq -r '.scripts | keys[] | select(. == "postinstall" or . == "preinstall")' "$skill_path/package.json" 2>/dev/null || true)
  if [ -n "$hooks" ]; then
    local allow
    allow=$(jq -r '.require_no_postinstall_scripts // true' "$POLICY" 2>/dev/null)
    if [ "$allow" = "true" ]; then
      echo "FAIL: package has postinstall/preinstall scripts"
      return 1
    fi
  fi
  return 0
}

# INV-S1: risk_flags => review_level (shell_exec=>L1, external_network=>L2)
check_review_level_from_risk() {
  local skill_path="$ROOT/skills/$SKILL_ID"
  local risk_flags="[]"
  if [ -f "$CAP_DIR/${SKILL_ID}.json" ]; then
    risk_flags=$(jq -c '.risk_flags // []' "$CAP_DIR/${SKILL_ID}.json" 2>/dev/null || echo "[]")
  else
    local text=""
    [ -f "$skill_path/SKILL.md" ] && text="${text}$(cat "$skill_path/SKILL.md" 2>/dev/null)"
    [ -f "$skill_path/README.md" ] && text="${text}$(cat "$skill_path/README.md" 2>/dev/null)"
    echo "$text" | grep -qiE "external_network|external network|api\.|https?://|fetch|telegram\.|web\.(search|fetch)" && risk_flags=$(echo "$risk_flags" | jq '. + ["external_network"]')
    echo "$text" | grep -qi "shell\|exec\|command" && risk_flags=$(echo "$risk_flags" | jq '. + ["shell_exec"]')
  fi
  local required_level="L0"
  if echo "$risk_flags" | jq -e 'index("external_network")' >/dev/null 2>&1; then
    required_level="L2"
  elif echo "$risk_flags" | jq -e 'index("shell_exec")' >/dev/null 2>&1; then
    required_level="L1"
  fi
  local current
  current=$(jq -r '.review_level // "L0"' "$REVIEW_FILE" 2>/dev/null)
  case "$current" in
    L0|L1|L2) ;;
    *) echo "FAIL: unknown review_level '$current' (must be L0/L1/L2)"; return 1 ;;
  esac
  local order="L0 L1 L2"
  local req_idx cur_idx
  req_idx=$(echo "$order" | tr ' ' '\n' | grep -n "$required_level" | cut -d: -f1)
  cur_idx=$(echo "$order" | tr ' ' '\n' | grep -n "$current" | cut -d: -f1)
  if [ "${cur_idx:-0}" -lt "${req_idx:-0}" ]; then
    echo "BLOCKED: risk_flags=$risk_flags requires review_level>=$required_level, got $current (INV-S1)"
    return 1
  fi
  jq --arg rl "$required_level" '. + {"review_level":$rl,"risk_flags":'"$risk_flags"'}' "$REVIEW_FILE" > "${REVIEW_FILE}.tmp" && mv "${REVIEW_FILE}.tmp" "$REVIEW_FILE"
  return 0
}

# 检查 5: forbidden_capabilities 声明
check_capabilities_claim() {
  local skill_path="$ROOT/skills/$SKILL_ID"
  local readme="${skill_path}/README.md"
  local skill_md="${skill_path}/SKILL.md"
  local text=""
  [ -f "$readme" ] && text="${text}$(cat "$readme")"
  [ -f "$skill_md" ] && text="${text}$(cat "$skill_md")"
  local forbidden
  forbidden=$(jq -r '.forbidden_capabilities[]' "$POLICY" 2>/dev/null || true)
  for fc in $forbidden; do
    if echo "$text" | grep -qi "$fc"; then
      echo "FAIL: skill claims or references forbidden capability: $fc"
      return 1
    fi
  done
  return 0
}

# 主流程
main() {
  [ -f "$TRUSTED" ] || { echo "BLOCKED: TRUSTED_SOURCES.json missing" >&2; audit_die_blocked "TRUSTED_SOURCES.json missing"; }
  [ -f "$POLICY" ] || { echo "BLOCKED: SECURITY_POLICY.json missing" >&2; audit_die_blocked "SECURITY_POLICY.json missing"; }
  command -v jq >/dev/null 2>&1 || { echo "BLOCKED: jq required" >&2; audit_die_blocked "jq required"; }

  # 解析 HEAD 为实际 SHA（本地 skill）
  if [ "$PINNED_REV" = "HEAD" ] && [ -d "$ROOT/skills/$SKILL_ID" ]; then
    PINNED_REV=$(cd "$ROOT" && git rev-parse HEAD 2>/dev/null || echo "HEAD")
  fi

  init_review > "$REVIEW_FILE"
  local findings=()
  findings=()
  local verdict="PASS"

  if ! check_provenance; then
    findings+=("source not in TRUSTED_SOURCES")
    verdict="BLOCKED"
  fi

  if ! check_pinned; then
    findings+=("revision not pinned")
    verdict="FAIL"
  fi

  if ! check_license 2>/dev/null; then
    findings+=("license check failed")
    verdict="BLOCKED"
  fi

  if [ -d "$ROOT/skills/$SKILL_ID" ]; then
    if ! check_install_hooks 2>/dev/null; then
      findings+=("postinstall/preinstall scripts present")
      verdict="FAIL"
    fi
    if ! check_capabilities_claim 2>/dev/null; then
      findings+=("forbidden capability claimed")
      verdict="FAIL"
    fi
  fi

  if ! check_review_level_from_risk 2>/dev/null; then
    findings+=("review_level insufficient for risk_flags (INV-S1)")
    verdict="BLOCKED"
  fi

  # INV-S2: external_network 必须声明 network_domains（当 capability 文件存在时）
  if [ -f "$CAP_DIR/${SKILL_ID}.json" ]; then
    local has_ext risk_doms dom_len dom_first
    has_ext=$(jq -r '(.risk_flags | index("external_network")) != null' "$CAP_DIR/${SKILL_ID}.json" 2>/dev/null || echo "false")
    risk_doms=$(jq -c '.network_domains // []' "$CAP_DIR/${SKILL_ID}.json" 2>/dev/null || echo "[]")
    if [ "$has_ext" = "true" ]; then
      dom_len=$(echo "$risk_doms" | jq 'length' 2>/dev/null || echo 0)
      dom_first=$(echo "$risk_doms" | jq -r '.[0] // ""' 2>/dev/null)
      if [ "${dom_len:-0}" -eq 0 ] || [ "$dom_first" = "unknown" ]; then
        findings+=("external_network requires non-empty network_domains (INV-S2)")
        verdict="BLOCKED"
      fi
    fi
  fi

  # 依赖数量（若有 package.json）
  local dep_count=0
  if [ -f "$ROOT/skills/$SKILL_ID/package.json" ]; then
    dep_count=$(jq '.dependencies | length' "$ROOT/skills/$SKILL_ID/package.json" 2>/dev/null || echo 0)
  fi

  # license_detected
  local lic=""
  if [ -f "$ROOT/skills/$SKILL_ID/package.json" ]; then
    lic=$(jq -r '.license // "detected"' "$ROOT/skills/$SKILL_ID/package.json" 2>/dev/null || echo "detected")
  fi
  [ -z "$lic" ] && [ -f "$ROOT/skills/$SKILL_ID/LICENSE" ] && lic="detected"
  [ -z "$lic" ] && lic="unknown"

  # install_hooks_scan
  local hooks_scan="clean"
  if [ -f "$ROOT/skills/$SKILL_ID/package.json" ]; then
    local hooks
    hooks=$(jq -r '.scripts | keys[] | select(. == "postinstall" or . == "preinstall")' "$ROOT/skills/$SKILL_ID/package.json" 2>/dev/null || true)
    [ -n "$hooks" ] && hooks_scan="flagged"
  fi

  local fc_json="[]"
  if [ ${#findings[@]} -gt 0 ]; then
    fc_json=$(printf '%s\n' "${findings[@]}" | jq -R . | jq -s .)
  fi

  # INV-S6: PASS must have pinned_revision, license_detected, top_level_deps, install_hooks_scan
  jq --arg v "$verdict" \
     --argjson fc "$fc_json" \
     --argjson dc "$dep_count" \
     --arg lic "$lic" \
     --arg hooks "$hooks_scan" \
     '. + {"verdict":$v,"findings":$fc,"top_level_deps":$dc,"license_detected":$lic,"install_hooks_scan":$hooks,"pinned_revision":(.pinned_revision // "'"$PINNED_REV"'")}' \
     "$REVIEW_FILE" > "${REVIEW_FILE}.tmp" && mv "${REVIEW_FILE}.tmp" "$REVIEW_FILE"

  if [ "$verdict" = "PASS" ]; then
    local missing=""
    jq -e '.pinned_revision and .pinned_revision != ""' "$REVIEW_FILE" >/dev/null 2>&1 || missing="${missing}pinned_revision "
    jq -e '.license_detected and .license_detected != ""' "$REVIEW_FILE" >/dev/null 2>&1 || missing="${missing}license_detected "
    jq -e '.top_level_deps != null' "$REVIEW_FILE" >/dev/null 2>&1 || missing="${missing}top_level_deps "
    jq -e '.install_hooks_scan and .install_hooks_scan != ""' "$REVIEW_FILE" >/dev/null 2>&1 || missing="${missing}install_hooks_scan "
    if [ -n "$missing" ]; then
      echo "FAIL: security review PASS missing required fields: $missing (INV-S6)" >&2
      type audit_step &>/dev/null && audit_step "security_review" "FAIL" "$REVIEW_FILE"
      audit_die_fail "INV-S6 missing fields: $missing"
    fi
  fi

  if [ "$verdict" = "BLOCKED" ]; then
    type audit_step &>/dev/null && audit_step "security_review" "BLOCKED" "$REVIEW_FILE"
    echo "BLOCKED: security review failed" >&2
    audit_die_blocked "security review failed"
  fi
  if [ "$verdict" = "FAIL" ]; then
    type audit_step &>/dev/null && audit_step "security_review" "FAIL" "$REVIEW_FILE"
    echo "FAIL: security review failed" >&2
    audit_die_fail "security review failed"
  fi

  type audit_step &>/dev/null && audit_step "security_review" "PASS" "$REVIEW_FILE"
  echo "PASS: security review OK"
  cat "$REVIEW_FILE"
}

main "$@"
