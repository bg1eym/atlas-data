#!/usr/bin/env bash
# Request Analyze: 从 request.txt 或 request.json 生成 analysis.json (INV-S7)
# 输入: request.txt (纯文本) 或 request.json (含 required_capabilities)
# 输出: out/skills/<run_id>/request/analysis.json
# required_capabilities 必须来自 CAPABILITY_TAXONOMY

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}}"
RUN_ID="${SKILLS_RUN_ID:-}"
OUT_BASE="${SKILLS_OUT_BASE:-$ROOT/out/skills/$RUN_ID}"
TAXONOMY="${ROOT}/environment/skills/CAPABILITY_TAXONOMY.json"
REQUEST_DIR="${OUT_BASE}/request"
ANALYSIS_FILE="${REQUEST_DIR}/analysis.json"
FAIL_EXIT=1

[ -f "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" 2>/dev/null || true
[ -f "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" 2>/dev/null || true

usage() {
  echo "Usage: $0 <request_file>" >&2
  echo "  request_file: request.txt (plain text) or request.json" >&2
  exit 1
}

[ $# -ge 1 ] || usage

REQUEST_FILE="$1"
[ -f "$REQUEST_FILE" ] || { echo "FAIL: request file not found: $REQUEST_FILE" >&2; audit_die_fail "request file not found"; }

mkdir -p "$REQUEST_DIR"

# 从 taxonomy 获取 allowlist
get_taxonomy_ids() {
  jq -r '.capabilities[].id' "$TAXONOMY" 2>/dev/null | tr '\n' ' '
}

# 校验 capabilities 均在 taxonomy 中
validate_capabilities_taxonomy() {
  local caps_json="$1"
  local allowlist
  allowlist=$(get_taxonomy_ids)
  local invalid=""
  for cap in $(echo "$caps_json" | jq -r '.[]?' 2>/dev/null); do
    [ -z "$cap" ] && continue
    if ! echo " $allowlist " | grep -q " $cap "; then
      invalid="${invalid}${cap} "
    fi
  done
  [ -z "$invalid" ] && return 0
  echo "FAIL: required_capabilities not in taxonomy: $invalid (INV-S5/S7)" >&2
  return 1
}

# 从纯文本提取 intent 和 capabilities（关键词映射）
analyze_from_txt() {
  local txt="$1"
  local sha
  sha=$(echo -n "$txt" | shasum -a 256 2>/dev/null | cut -d' ' -f1 || echo "unknown")
  local intent
  intent=$(echo "$txt" | head -5 | tr '\n' ' ' | sed 's/  */ /g' | head -c 500)
  local caps="[]"
  if echo "$txt" | grep -qiE "healthcheck|run|execute|command|shell|status|report"; then
    caps=$(echo "$caps" | jq -c '. + ["shell.exec"] | unique')
  fi
  if echo "$txt" | grep -qiE "telegram|send message"; then
    caps=$(echo "$caps" | jq -c '. + ["telegram.send"] | unique')
  fi
  if echo "$txt" | grep -qiE "web|search|fetch|http"; then
    caps=$(echo "$caps" | jq -c '. + ["web.fetch"] | unique')
  fi
  if echo "$txt" | grep -qiE "notes|write"; then
    caps=$(echo "$caps" | jq -c '. + ["notes.write"] | unique')
  fi
  if [ "$caps" = "[]" ]; then
    caps='["shell.exec"]'
  fi
  printf '%s\n%s\n%s\n' "$sha" "$intent" "$caps"
}

# 从 request.json 提取
analyze_from_json() {
  local f="$1"
  local sha
  sha=$(shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
  local caps
  caps=$(jq -c '.required_capabilities // []' "$f" 2>/dev/null || echo "[]")
  local intent
  intent=$(jq -r '.intent // "from request.json"' "$f" 2>/dev/null || echo "from request.json")
  printf '%s\n%s\n%s\n' "$sha" "$intent" "$caps"
}

main() {
  [ -f "$TAXONOMY" ] || { echo "FAIL: CAPABILITY_TAXONOMY.json missing" >&2; audit_die_fail "TAXONOMY missing"; }

  local sha intent caps
  if [[ "$REQUEST_FILE" == *.txt ]]; then
    local txt
    txt=$(cat "$REQUEST_FILE")
    sha=$(analyze_from_txt "$txt" | head -1)
    intent=$(analyze_from_txt "$txt" | sed -n '2p')
    caps=$(analyze_from_txt "$txt" | tail -1 | tr -d '\n\r')
  else
    sha=$(analyze_from_json "$REQUEST_FILE" | head -1)
    intent=$(analyze_from_json "$REQUEST_FILE" | sed -n '2p')
    caps=$(analyze_from_json "$REQUEST_FILE" | tail -1 | tr -d '\n\r')
  fi

  # INV-S5/S7: required_capabilities 必须来自 taxonomy
  if ! validate_capabilities_taxonomy "$caps"; then
    audit_die_fail "INV-S7 required_capabilities not in taxonomy"
  fi

  jq -n \
    --arg sha "$sha" \
    --arg intent "$intent" \
    --argjson caps "$caps" \
    '{
      request_sha256: $sha,
      extracted_intent: $intent,
      required_capabilities: $caps,
      forbidden_capabilities: [],
      required_credentials: [],
      constraints: {}
    }' > "$ANALYSIS_FILE"

  echo "Wrote $ANALYSIS_FILE"
  cat "$ANALYSIS_FILE"
}

main "$@"
