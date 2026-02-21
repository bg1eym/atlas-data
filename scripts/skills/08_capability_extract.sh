#!/usr/bin/env bash
# Capability Extract: 从 skill 提取结构化能力声明。
# INV-S2: external_network => network_domains 必填（从 manifest/README/SKILL.md 提取显式域名）
# INV-S5: capabilities 必须来自 CAPABILITY_TAXONOMY.json
# 输入: skill repo/package (pinned revision)，本地路径或 skill_id
# 输出: out/skills/<run_id>/capabilities/<skill_id>.json

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}}"
RUN_ID="${SKILLS_RUN_ID:-}"
OUT_BASE="${SKILLS_OUT_BASE:-$ROOT/out/skills/$RUN_ID}"
TAXONOMY="${ROOT}/environment/skills/CAPABILITY_TAXONOMY.json"
CAP_DIR="${OUT_BASE}/capabilities"
BLOCKED_EXIT=42
FAIL_EXIT=1

[ -f "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" 2>/dev/null || true
[ -f "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" 2>/dev/null || true

usage() {
  echo "Usage: $0 <skill_id> [skill_path]" >&2
  echo "  skill_id: e.g. healthcheck, playwright" >&2
  echo "  skill_path: default $ROOT/skills/<skill_id>" >&2
  audit_die_fail "invalid usage"
}

[ $# -ge 1 ] || usage

SKILL_ID="$1"
SKILL_PATH="${2:-$ROOT/skills/$SKILL_ID}"
CAP_DIR="${OUT_BASE}/capabilities"
OUT_FILE="${CAP_DIR}/${SKILL_ID}.json"
mkdir -p "$CAP_DIR"

# 从 taxonomy 获取所有能力 id
get_taxonomy_ids() {
  jq -r '.capabilities[].id' "$TAXONOMY" 2>/dev/null || echo ""
}

# 关键词 → capability 映射（fallback 当无 manifest 时）
map_keywords() {
  local text="$1"
  local caps="[]"
  local kw cap
  while IFS=$'\t' read -r kw cap; do
    [ -z "$kw" ] || [ -z "$cap" ] && continue
    if echo "$text" | grep -qi "$kw"; then
      caps=$(echo "$caps" | jq --arg c "$cap" '. + [$c] | unique')
    fi
  done <<'EOM'
telegram.send	telegram.send
telegram.read	telegram.readback
telegram.readback	telegram.readback
web.search	web.search
web.fetch	web.fetch
http	web.fetch
pdf	pdf.generate
notes.write	notes.write
reminders	reminders.write
filesystem.read	filesystem.read
filesystem	filesystem.read
filesystem.write	filesystem.write
shell.exec	shell.exec
shell exec	shell.exec
command	shell.exec
EOM
  echo "$caps"
}

# 优先从 manifest 读取
extract_from_manifest() {
  local path="$1"
  local caps="[]"
  [ -f "$path/metadata.json" ] && caps=$(jq -r '.capabilities // []' "$path/metadata.json" 2>/dev/null || echo "[]")
  if [ "$caps" = "[]" ] && [ -f "$path/SKILL.md" ]; then
    local text
    text=$(cat "$path/SKILL.md" 2>/dev/null || true)
    caps=$(map_keywords "$text")
  fi
  echo "$caps"
  return 0
}

# 从 README 关键词 fallback
extract_from_readme() {
  local path="$1"
  local text=""
  [ -f "$path/README.md" ] && text=$(cat "$path/README.md")
  [ -f "$path/SKILL.md" ] && text="${text}$(cat "$path/SKILL.md")"
  map_keywords "$text"
}

# 检测 requires_env
extract_requires_env() {
  local path="$1"
  local envs="[]"
  local text=""
  for f in SKILL.md README.md; do
    [ -f "$path/$f" ] && text="${text}$(cat "$path/$f")"
  done
  for token in TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID GITHUB_TOKEN API_KEY; do
    if echo "$text" | grep -q "$token"; then
      envs=$(echo "$envs" | jq --arg t "$token" '. + [$t]')
    fi
  done
  echo "$envs"
}

# 检测 risk_flags
# external_network: 显式外网行为（api.、fetch、https://、telegram、external_network 等），非泛指 "network"
extract_risk_flags() {
  local path="$1"
  local flags="[]"
  local text=""
  for f in SKILL.md README.md; do
    [ -f "$path/$f" ] && text="${text}$(cat "$path/$f")"
  done
  echo "$text" | grep -qiE "external_network|external network|api\.|https?://|fetch|telegram\.|web\.(search|fetch)" && flags=$(echo "$flags" | jq '. + ["external_network"]')
  echo "$text" | grep -qi "shell\|exec\|command" && flags=$(echo "$flags" | jq '. + ["shell_exec"]')
  echo "$flags"
}

# INV-S2: 从 manifest/README/SKILL.md 提取显式域名（如 api.telegram.org, news.ycombinator.com）
extract_network_domains() {
  local path="$1"
  local domains="[]"
  local text=""
  for f in SKILL.md README.md metadata.json; do
    [ -f "$path/$f" ] && text="${text}$(cat "$path/$f")"
  done
  # 匹配常见域名模式: xxx.yyy.com, api.xxx.org, xxx.io 等
  local found
  found=$(echo "$text" | grep -oE '[a-zA-Z0-9][-a-zA-Z0-9]*\.(com|org|net|io|dev|api|co|app)[a-zA-Z0-9/.-]*' 2>/dev/null | sed 's/[\/:].*//' | sort -u | head -20)
  if [ -n "$found" ]; then
    domains=$(printf '%s\n' $found | jq -R . | jq -s .)
  else
    # 若检测到外网行为线索但无显式域名 => unknown（INV-S2 将触发 BLOCKED）
    if echo "$text" | grep -qiE "external_network|https?://|api\.|telegram\.org|ycombinator\.com"; then
      domains='["unknown"]'
    fi
  fi
  echo "$domains"
}

# INV-S5: 校验 capabilities 均在 taxonomy 中
validate_capabilities_taxonomy() {
  local caps_json="$1"
  local allowlist
  allowlist=$(jq -r '.capabilities[].id' "$TAXONOMY" 2>/dev/null | tr '\n' ' ')
  local invalid=""
  for cap in $(echo "$caps_json" | jq -r '.[]?' 2>/dev/null); do
    if ! echo " $allowlist " | grep -q " $cap "; then
      invalid="${invalid}${cap} "
    fi
  done
  [ -z "$invalid" ] && return 0
  echo "FAIL: capabilities not in taxonomy: $invalid (INV-S5)" >&2
  return 1
}

main() {
  [ -f "$TAXONOMY" ] || { echo "BLOCKED: CAPABILITY_TAXONOMY.json missing" >&2; audit_die_blocked "CAPABILITY_TAXONOMY.json missing"; }
  [ -d "$SKILL_PATH" ] || { echo "SKILL_PATH not found: $SKILL_PATH" >&2; audit_die_fail "SKILL_PATH not found: $SKILL_PATH"; }

  local capabilities
  capabilities=$(extract_from_manifest "$SKILL_PATH" 2>/dev/null || extract_from_readme "$SKILL_PATH")
  local requires_env
  requires_env=$(extract_requires_env "$SKILL_PATH")
  local risk_flags
  risk_flags=$(extract_risk_flags "$SKILL_PATH")
  local network_domains
  network_domains=$(extract_network_domains "$SKILL_PATH")

  # INV-S5: capabilities 必须来自 taxonomy
  if ! validate_capabilities_taxonomy "$capabilities"; then
    type audit_step &>/dev/null && audit_step "capability_extract" "FAIL" "$OUT_FILE"
    audit_die_fail "INV-S5 capabilities not in taxonomy"
  fi

  # INV-S2: external_network 必须声明 network_domains（非空且非 unknown）
  if echo "$risk_flags" | jq -e 'index("external_network")' >/dev/null 2>&1; then
    local dom_len dom_first
    dom_len=$(echo "$network_domains" | jq 'length' 2>/dev/null || echo 0)
    dom_first=$(echo "$network_domains" | jq -r '.[0] // ""' 2>/dev/null)
    if [ "${dom_len:-0}" -eq 0 ] || [ "$dom_first" = "unknown" ]; then
      echo "BLOCKED: external_network requires non-empty network_domains (got $network_domains) (INV-S2)" >&2
      type audit_step &>/dev/null && audit_step "capability_extract" "BLOCKED" "$OUT_FILE"
      audit_die_blocked "INV-S2 external_network requires non-empty network_domains"
    fi
  fi

  local evidence_refs="[]"
  [ -f "$SKILL_PATH/SKILL.md" ] && evidence_refs=$(echo "$evidence_refs" | jq '. + ["SKILL.md"]')
  [ -f "$SKILL_PATH/README.md" ] && evidence_refs=$(echo "$evidence_refs" | jq '. + ["README.md"]')

  jq -n \
    --arg id "$SKILL_ID" \
    --argjson caps "$capabilities" \
    --argjson envs "$requires_env" \
    --argjson risks "$risk_flags" \
    --argjson doms "$network_domains" \
    --argjson refs "$evidence_refs" \
    '{
      skill_id: $id,
      capabilities: $caps,
      claimed_tools: ["cli"],
      requires_env: $envs,
      risk_flags: $risks,
      network_domains: $doms,
      evidence_refs: $refs
    }' > "$OUT_FILE"

  type audit_step &>/dev/null && audit_step "capability_extract" "PASS" "$OUT_FILE"
  echo "Wrote $OUT_FILE"
  cat "$OUT_FILE"
}

main "$@"
