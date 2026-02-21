#!/usr/bin/env bash
# Skills Framework Audit Library v1.2.1
# 统一退出封装：所有 exit 必须经 audit_die_*，确保 summary.json 闭环

: "${OUT_BASE:=${SKILLS_OUT_BASE:-}}"
: "${RUN_ID:=${SKILLS_RUN_ID:-}}"
ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}}"
[ -z "$OUT_BASE" ] && OUT_BASE="${ROOT}/out/skills/${RUN_ID:-unknown}"

BLOCKED_EXIT=42
FAIL_EXIT=1

get_required_steps() {
  local root="${ROOT}"
  local f="$root/environment/skills/REQUIRED_STEPS.json"
  if [ -f "$f" ] && command -v jq >/dev/null 2>&1; then
    jq -r '.[]' "$f" 2>/dev/null | tr '\n' ' '
  else
    echo "guard security_review capability_extract plan install verify"
  fi
}

audit_init() {
  mkdir -p "$OUT_BASE"/{security,capabilities,plan,verify,audit,request}
  echo '{"run_id":"'"${RUN_ID:-unknown}"'","started_at":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","verdict":"PENDING","steps":[]}' > "$OUT_BASE/audit/summary.json"
  echo "audit_dir: $OUT_BASE/audit"
}

audit_step() {
  local name="$1" status="$2" evidence_paths="${3:-[]}"
  local f="$OUT_BASE/audit/summary.json"
  if [ -f "$f" ] && command -v jq >/dev/null 2>&1; then
    local ts ep
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    ep="$evidence_paths"
    if [ -z "$ep" ] || [ "$ep" = "[]" ]; then
      ep="[]"
    elif [[ "$ep" != "["* ]]; then
      ep=$(jq -n -c --arg p "$ep" '[$p]')
    fi
    jq --arg n "$name" --arg s "$status" --arg t "$ts" --argjson ep "$ep" \
      '.steps += [{"name":$n,"status":$s,"evidence_paths":$ep,"timestamp":$t}]' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
  fi
}

audit_finalize() {
  local verdict="$1" exit_code="${2:-0}" reason="${3:-}"
  if [ ! -f "$OUT_BASE/audit/summary.json" ]; then
    audit_init
  fi
  local f="$OUT_BASE/audit/summary.json"
  if [ ! -f "$f" ] || ! command -v jq >/dev/null 2>&1; then return; fi

  local required_steps
  required_steps=$(get_required_steps)
  local have_names
  have_names=$(jq -r '[.steps[].name] | join(" ")' "$f" 2>/dev/null || echo "")

  jq '.steps |= (group_by(.name) | map(.[0]))' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
  have_names=$(jq -r '[.steps[].name] | join(" ")' "$f" 2>/dev/null || echo "")

  local had_to_pad=false
  for name in $required_steps; do
    [ -z "$name" ] && continue
    if ! echo " $have_names " | grep -qE " $name "; then
      had_to_pad=true
      local ts
      ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      jq --arg n "$name" --arg t "$ts" --arg r "not reached due to $verdict: $reason" \
        '.steps += [{"name":$n,"status":"SKIPPED","evidence_paths":[],"timestamp":$t,"reason":$r}]' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
      have_names="${have_names} ${name}"
    fi
  done

  if [ "$had_to_pad" = "true" ] && [ "$verdict" = "PENDING" ]; then
    verdict="FAIL"
    exit_code=1
    reason="${reason:+$reason; }steps padded (INV-S3)"
  fi

  jq --arg v "$verdict" --argjson e "$exit_code" --arg r "$reason" \
    '. + {"verdict":$v,"exit_code":$e,"reason":$r,"finished_at":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
}

audit_die_blocked() {
  local reason="${1:-blocked}"
  type audit_finalize &>/dev/null && audit_finalize "BLOCKED" "$BLOCKED_EXIT" "$reason"
  exit $BLOCKED_EXIT
}

audit_die_fail() {
  local reason="${1:-fail}"
  type audit_finalize &>/dev/null && audit_finalize "FAIL" "$FAIL_EXIT" "$reason"
  exit $FAIL_EXIT
}

audit_die_pass() {
  type audit_finalize &>/dev/null && audit_finalize "PASS" 0 ""
  exit 0
}

export -f audit_init audit_step audit_finalize audit_die_blocked audit_die_fail audit_die_pass 2>/dev/null || true
export BLOCKED_EXIT FAIL_EXIT
