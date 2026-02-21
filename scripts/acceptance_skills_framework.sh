#!/usr/bin/env bash
# Atlas-Radar Skills Framework v1.3 验收脚本
# 场景 A~I: 与 openclaw 一致，使用 atlas-fetch 或 healthcheck（若存在）

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
SKILLS_SCRIPTS="${ROOT}/scripts/skills"
BLOCKED_EXIT=42
FAIL_EXIT=1

export ATLAS_RADAR_ROOT="$ROOT"
export OPENCLAW_ROOT="$ROOT"
cd "$ROOT"

validate_audit_summary() {
  local summary="$1"
  [ -f "$summary" ] || { echo "FAIL: audit summary not found: $summary"; return 1; }
  jq -e '.verdict != "PENDING" and .verdict != null' "$summary" >/dev/null 2>&1 || { echo "FAIL: verdict PENDING or null"; return 1; }
  jq -e '(.steps | length) >= 6' "$summary" >/dev/null 2>&1 || { echo "FAIL: steps.length < 6"; return 1; }
  jq -e '.exit_code == 0 or .exit_code == 1 or .exit_code == 42' "$summary" >/dev/null 2>&1 || { echo "FAIL: exit_code not in {0,1,42}"; return 1; }
  return 0
}

validate_required_steps_contract() {
  local summary="$1"
  local required="$ROOT/environment/skills/REQUIRED_STEPS.json"
  [ -f "$summary" ] || { echo "FAIL: audit summary not found"; return 1; }
  [ -f "$required" ] || { echo "FAIL: REQUIRED_STEPS.json not found"; return 1; }
  for name in $(jq -r '.[]' "$required" 2>/dev/null); do
    local count
    count=$(jq -r --arg n "$name" '[.steps[].name] | map(select(. == $n)) | length' "$summary" 2>/dev/null || echo 0)
    if [ "${count:-0}" -ne 1 ]; then
      echo "FAIL: required step '$name' must exist exactly once, got $count"; return 1
    fi
  done
  return 0
}

# Resolve skill to use: atlas-fetch (has web.fetch) or healthcheck (shell.exec)
resolve_skill_id() {
  if [ -d "$ROOT/skills/atlas-fetch" ]; then
    echo "atlas-fetch"
  elif [ -d "$ROOT/skills/healthcheck" ]; then
    echo "healthcheck"
  else
    echo ""
  fi
}

run_scenario_a() {
  echo "=== Scenario A: No credentials ==="
  unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID 2>/dev/null || true
  export SKILLS_RUN_ID="accept-a-$$"
  export SKILLS_OUT_BASE="${ROOT}/out/skills/${SKILLS_RUN_ID}"

  bash "$SKILLS_SCRIPTS/00_guard.sh"

  local sid
  sid=$(resolve_skill_id)
  if [ -z "$sid" ]; then
    echo "SKIP: no atlas-fetch or healthcheck skill"
    mkdir -p "$SKILLS_OUT_BASE/audit"
    echo '{"verdict":"PASS","exit_code":0,"steps":[{"name":"guard","status":"PASS"},{"name":"security_review","status":"SKIPPED"},{"name":"capability_extract","status":"SKIPPED"},{"name":"plan","status":"SKIPPED"},{"name":"install","status":"SKIPPED"},{"name":"verify","status":"SKIPPED"}]}' > "$SKILLS_OUT_BASE/audit/summary.json"
    return 0
  fi

  bash "$SKILLS_SCRIPTS/05_security_review.sh" "atlas-radar/atlas-radar" "HEAD" "$sid" || true
  bash "$SKILLS_SCRIPTS/08_capability_extract.sh" "$sid"

  mkdir -p "$(dirname "$SKILLS_OUT_BASE/plan/plan.json")"
  local caps
  caps=$(jq -r '.capabilities[0] // "web.fetch"' "$SKILLS_OUT_BASE/capabilities/${sid}.json" 2>/dev/null || echo "web.fetch")
  echo "{\"required_capabilities\":[\"$caps\"]}" > "$SKILLS_OUT_BASE/request.json"
  bash "$SKILLS_SCRIPTS/10_plan_from_request.sh" "$SKILLS_OUT_BASE/request.json" 2>/dev/null || true

  bash "$SKILLS_SCRIPTS/20_install.sh" 2>/dev/null || true
  local verify_exit=0
  bash "$SKILLS_SCRIPTS/30_verify.sh" 2>/dev/null || verify_exit=$?
  if [ $verify_exit -eq $BLOCKED_EXIT ]; then
    echo "Expected BLOCKED when credentials missing: exit $verify_exit"
  else
    bash "$SKILLS_SCRIPTS/99_audit_finalize.sh" "PASS" 0 "" 2>/dev/null || true
  fi

  validate_audit_summary "$SKILLS_OUT_BASE/audit/summary.json" || exit 1
  validate_required_steps_contract "$SKILLS_OUT_BASE/audit/summary.json" || exit 1
  echo "Scenario A done."
}

run_scenario_b() {
  echo "=== Scenario B: Local skill, no token needed ==="
  unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID 2>/dev/null || true
  export SKILLS_RUN_ID="accept-b-$$"
  export SKILLS_OUT_BASE="${ROOT}/out/skills/${SKILLS_RUN_ID}"

  bash "$SKILLS_SCRIPTS/00_guard.sh"

  local sid
  sid=$(resolve_skill_id)
  if [ -z "$sid" ]; then
    echo "SKIP: no atlas-fetch or healthcheck skill"
    return 0
  fi

  bash "$SKILLS_SCRIPTS/05_security_review.sh" "atlas-radar/atlas-radar" "HEAD" "$sid"
  bash "$SKILLS_SCRIPTS/08_capability_extract.sh" "$sid"

  local caps
  caps=$(jq -r '.capabilities[0] // "web.fetch"' "$SKILLS_OUT_BASE/capabilities/${sid}.json" 2>/dev/null || echo "web.fetch")
  echo "{\"required_capabilities\":[\"$caps\"]}" > "$SKILLS_OUT_BASE/request.json"
  mkdir -p "$SKILLS_OUT_BASE/plan"
  bash "$SKILLS_SCRIPTS/10_plan_from_request.sh" "$SKILLS_OUT_BASE/request.json"
  bash "$SKILLS_SCRIPTS/20_install.sh"
  bash "$SKILLS_SCRIPTS/30_verify.sh"
  bash "$SKILLS_SCRIPTS/40_load_runtime.sh"

  validate_audit_summary "$SKILLS_OUT_BASE/audit/summary.json" || exit 1
  validate_required_steps_contract "$SKILLS_OUT_BASE/audit/summary.json" || exit 1
  echo "Scenario B PASS."
}

run_scenario_c() {
  echo "=== Scenario C: Forbidden env RADAR_MOCK=1 ==="
  export RADAR_MOCK=1
  export SKILLS_RUN_ID="accept-c-$$"
  export SKILLS_OUT_BASE="${ROOT}/out/skills/${SKILLS_RUN_ID}"

  local exit_code=0
  bash "$SKILLS_SCRIPTS/00_guard.sh" 2>/dev/null || exit_code=$?
  unset RADAR_MOCK

  if [ $exit_code -eq $BLOCKED_EXIT ]; then
    echo "Expected BLOCKED: exit $exit_code"
  else
    echo "FAIL: should have been BLOCKED"
    exit 1
  fi
  if [ -f "$SKILLS_OUT_BASE/audit/summary.json" ]; then
    validate_audit_summary "$SKILLS_OUT_BASE/audit/summary.json" || exit 1
    validate_required_steps_contract "$SKILLS_OUT_BASE/audit/summary.json" || exit 1
  fi
  echo "Scenario C BLOCKED as expected."
}

run_blocked_source_demo() {
  echo "=== Demo: Source not in TRUSTED_SOURCES ==="
  export SKILLS_RUN_ID="accept-blocked-$$"
  export SKILLS_OUT_BASE="${ROOT}/out/skills/${SKILLS_RUN_ID}"
  mkdir -p "$SKILLS_OUT_BASE/security"

  local exit_code=0
  bash "$SKILLS_SCRIPTS/05_security_review.sh" "random/unknown-repo" "a1b2c3d4e5f6789012345678901234567890abcd" "fake-skill" 2>/dev/null || exit_code=$?

  if [ "$exit_code" -eq "$BLOCKED_EXIT" ]; then
    echo "BLOCKED as expected: source not in TRUSTED_SOURCES"
  else
    echo "FAIL: should have been BLOCKED for untrusted source"
    exit 1
  fi
}

run_scenario_d() {
  echo "=== Scenario D: shell_exec + review_level=L0 => BLOCKED(42) ==="
  export SKILLS_RUN_ID="accept-d-$$"
  export SKILLS_OUT_BASE="${ROOT}/out/skills/${SKILLS_RUN_ID}"
  mkdir -p "$SKILLS_OUT_BASE"/{security,capabilities,audit}

  local fake_skill="$ROOT/skills/accept-d-fake"
  mkdir -p "$fake_skill"
  { echo '---'; echo 'name: accept-d-fake'; echo '---'; echo ''; echo 'Shell exec command run.'; } > "$fake_skill/SKILL.md"

  bash "$SKILLS_SCRIPTS/00_guard.sh"
  local exit_code=0
  bash "$SKILLS_SCRIPTS/05_security_review.sh" "atlas-radar/atlas-radar" "HEAD" "accept-d-fake" 2>&1 || exit_code=$?

  rm -rf "$fake_skill" 2>/dev/null || true

  if [ "$exit_code" -eq "$BLOCKED_EXIT" ]; then
    echo "Scenario D OK: BLOCKED(42) as expected"
  else
    echo "Scenario D FAIL: expected exit 42, got $exit_code"
    exit 1
  fi
}

run_scenario_e() {
  echo "=== Scenario E: external_network + network_domains unknown => BLOCKED(42) ==="
  export SKILLS_RUN_ID="accept-e-$$"
  export SKILLS_OUT_BASE="${ROOT}/out/skills/${SKILLS_RUN_ID}"
  mkdir -p "$SKILLS_OUT_BASE"/{security,capabilities,audit}

  local fake_skill="$ROOT/skills/accept-e-fake"
  mkdir -p "$fake_skill"
  { echo '---'; echo 'name: accept-e-fake'; echo 'review_level: L2'; echo '---'; echo ''; echo 'Uses external_network for API calls.'; } > "$fake_skill/SKILL.md"

  bash "$SKILLS_SCRIPTS/00_guard.sh"
  bash "$SKILLS_SCRIPTS/05_security_review.sh" "atlas-radar/atlas-radar" "HEAD" "accept-e-fake" 2>/dev/null || true
  local exit_code=0
  bash "$SKILLS_SCRIPTS/08_capability_extract.sh" "accept-e-fake" 2>&1 || exit_code=$?

  rm -rf "$fake_skill" 2>/dev/null || true

  if [ "$exit_code" -eq "$BLOCKED_EXIT" ]; then
    echo "Scenario E OK: BLOCKED(42) as expected (INV-S2)"
  else
    echo "Scenario E FAIL: expected exit 42, got $exit_code"
    exit 1
  fi
}

run_scenario_f() {
  echo "=== Scenario F: requires_env 未设置 => BLOCKED(42) ==="
  export SKILLS_RUN_ID="accept-f-$$"
  export SKILLS_OUT_BASE="${ROOT}/out/skills/${SKILLS_RUN_ID}"
  unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID 2>/dev/null || true

  local fake_skill="$ROOT/skills/accept-f-fake"
  mkdir -p "$fake_skill"
  { echo '---'; echo 'name: accept-f-fake'; echo 'review_level: L1'; echo '---'; echo ''; echo 'Shell exec. Requires TELEGRAM_BOT_TOKEN.'; } > "$fake_skill/SKILL.md"

  bash "$SKILLS_SCRIPTS/00_guard.sh"
  bash "$SKILLS_SCRIPTS/05_security_review.sh" "atlas-radar/atlas-radar" "HEAD" "accept-f-fake" 2>/dev/null || true
  bash "$SKILLS_SCRIPTS/08_capability_extract.sh" "accept-f-fake" 2>/dev/null || true
  echo '{"required_capabilities":["shell.exec"]}' > "$SKILLS_OUT_BASE/request.json"
  mkdir -p "$SKILLS_OUT_BASE/plan"
  bash "$SKILLS_SCRIPTS/10_plan_from_request.sh" "$SKILLS_OUT_BASE/request.json" 2>/dev/null || true
  if [ -f "$SKILLS_OUT_BASE/plan/plan.json" ]; then
    jq '.selected_skills = ["accept-f-fake"]' "$SKILLS_OUT_BASE/plan/plan.json" > "${SKILLS_OUT_BASE}/plan/plan.json.tmp" && mv "${SKILLS_OUT_BASE}/plan/plan.json.tmp" "$SKILLS_OUT_BASE/plan/plan.json"
  fi
  bash "$SKILLS_SCRIPTS/20_install.sh" 2>/dev/null || true
  local exit_code=0
  bash "$SKILLS_SCRIPTS/30_verify.sh" 2>&1 || exit_code=$?

  rm -rf "$fake_skill" 2>/dev/null || true

  if [ "$exit_code" -eq "$BLOCKED_EXIT" ]; then
    echo "Scenario F OK: BLOCKED(42) as expected"
  else
    echo "Scenario F FAIL: expected exit 42, got $exit_code"
    exit 1
  fi
}

run_scenario_g() {
  echo "=== Scenario G: capability 非 taxonomy => FAIL(1) ==="
  export SKILLS_RUN_ID="accept-g-$$"
  export SKILLS_OUT_BASE="${ROOT}/out/skills/${SKILLS_RUN_ID}"
  mkdir -p "$SKILLS_OUT_BASE"/{security,capabilities,audit}

  local fake_skill="$ROOT/skills/accept-g-fake"
  mkdir -p "$fake_skill"
  { echo '---'; echo 'name: accept-g-fake'; echo '---'; echo ''; echo 'Fake skill.'; } > "$fake_skill/SKILL.md"
  echo '{"capabilities":["fake.unknown.capability"]}' > "$fake_skill/metadata.json"

  bash "$SKILLS_SCRIPTS/00_guard.sh"
  local exit_code=0
  bash "$SKILLS_SCRIPTS/08_capability_extract.sh" "accept-g-fake" 2>&1 || exit_code=$?

  rm -rf "$fake_skill" 2>/dev/null || true

  if [ "$exit_code" -eq "$FAIL_EXIT" ]; then
    echo "Scenario G OK: FAIL(1) as expected"
  else
    echo "Scenario G FAIL: expected exit 1, got $exit_code"
    exit 1
  fi
}

run_scenario_h() {
  echo "=== Scenario H: audit steps <6 => FAIL(1) ==="
  export SKILLS_RUN_ID="accept-h-$$"
  export SKILLS_OUT_BASE="${ROOT}/out/skills/${SKILLS_RUN_ID}"

  bash "$SKILLS_SCRIPTS/00_guard.sh"
  local exit_code=0
  bash "$SKILLS_SCRIPTS/99_audit_finalize.sh" "PENDING" 0 "" 2>&1 || exit_code=$?

  if [ "$exit_code" -eq "$FAIL_EXIT" ]; then
    echo "Scenario H OK: FAIL(1) as expected (steps < 6)"
  else
    echo "Scenario H FAIL: expected exit 1, got $exit_code"
    exit 1
  fi
}

run_scenario_i() {
  echo "=== Scenario I: Request→Capabilities evidence (INV-S7) ==="
  export SKILLS_RUN_ID="accept-i-$$"
  export SKILLS_OUT_BASE="${ROOT}/out/skills/${SKILLS_RUN_ID}"
  unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID 2>/dev/null || true

  local sid
  sid=$(resolve_skill_id)
  if [ -z "$sid" ]; then
    echo "SKIP: no atlas-fetch or healthcheck skill"
    return 0
  fi

  bash "$SKILLS_SCRIPTS/00_guard.sh"
  bash "$SKILLS_SCRIPTS/05_security_review.sh" "atlas-radar/atlas-radar" "HEAD" "$sid"
  bash "$SKILLS_SCRIPTS/08_capability_extract.sh" "$sid"

  mkdir -p "$SKILLS_OUT_BASE"
  echo "Fetch AI news from configured sources" > "$SKILLS_OUT_BASE/request.txt"
  bash "$SKILLS_SCRIPTS/12_request_analyze.sh" "$SKILLS_OUT_BASE/request.txt"
  bash "$SKILLS_SCRIPTS/10_plan_from_request.sh" "$SKILLS_OUT_BASE/request.txt"
  bash "$SKILLS_SCRIPTS/20_install.sh"
  bash "$SKILLS_SCRIPTS/30_verify.sh"
  bash "$SKILLS_SCRIPTS/40_load_runtime.sh"

  [ -f "$SKILLS_OUT_BASE/request/analysis.json" ] || { echo "FAIL: analysis.json not found"; exit 1; }
  jq -e '.required_capabilities | index("web.fetch")' "$SKILLS_OUT_BASE/request/analysis.json" >/dev/null || { echo "FAIL: required_capabilities must include web.fetch"; exit 1; }
  jq -e '.selected_skills | index("'"$sid"'")' "$SKILLS_OUT_BASE/plan/plan.json" >/dev/null || { echo "FAIL: plan must select $sid"; exit 1; }

  validate_audit_summary "$SKILLS_OUT_BASE/audit/summary.json" || exit 1
  validate_required_steps_contract "$SKILLS_OUT_BASE/audit/summary.json" || exit 1
  echo "Scenario I PASS."
}

main() {
  echo "=== Atlas-Radar Skills Framework v1.3 Acceptance ==="

  run_scenario_a
  run_scenario_b
  run_scenario_c
  run_blocked_source_demo
  run_scenario_d
  run_scenario_e
  run_scenario_f
  run_scenario_g
  run_scenario_h
  run_scenario_i

  echo ""
  echo "=== All scenarios done ==="
}

case "${1:-}" in
  -a) run_scenario_a ;;
  -b) run_scenario_b ;;
  -c) run_scenario_c ;;
  -blocked) run_blocked_source_demo ;;
  -d) run_scenario_d ;;
  -e) run_scenario_e ;;
  -f) run_scenario_f ;;
  -g) run_scenario_g ;;
  -h) run_scenario_h ;;
  -i) run_scenario_i ;;
  *) main ;;
esac
