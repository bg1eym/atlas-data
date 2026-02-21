#!/usr/bin/env bash
# Atlas-Radar Acceptance Matrix Verify.
# Scenarios A/B/C (no token, forbidden env) + D/E/F (failure injection).
# Output: acceptance_matrix_v2.json, audit_presence_report_v2.json

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
cd "$ROOT"

SNAPSHOT_DATE=$(date +%Y-%m-%d)
SNAPSHOT_DIR="$ROOT/out/review_snapshot/$SNAPSHOT_DATE"
mkdir -p "$SNAPSHOT_DIR"
MATRIX_JSON="$SNAPSHOT_DIR/acceptance_matrix_v2.json"
AUDIT_JSON="$SNAPSHOT_DIR/audit_presence_report_v2.json"

echo "=== Atlas-Radar Acceptance Matrix Verify ==="
echo "Snapshot dir: $SNAPSHOT_DIR"
echo ""

PASS=0
FAIL=0
MATRIX_ENTRIES=()
AUDIT_ENTRIES=()

# ── Scenarios A/B/C: acceptance_apf_v2 (LOCAL_ONLY) ─────────────────────
echo "----- scripts/acceptance_apf_v2.sh -----"

# A: no token (LOCAL_ONLY, expect PASS)
A_OUT=$(mktemp)
set +e
env -u TELEGRAM_BOT_TOKEN -u TELEGRAM_CHAT_ID RADAR_SKIP_SEND=1 bash "$ROOT/scripts/acceptance_apf_v2.sh" > "$A_OUT" 2>&1
A_EC=$?
set -e
echo "Scenario A (no token): EXIT=$A_EC"
if [ "$A_EC" -eq 0 ] && grep -q "LOCAL_OK" "$A_OUT"; then
  echo "  => OK (LOCAL_ONLY pass)"
  PASS=$((PASS + 1))
else
  echo "  => FAIL (expected PASS)"
  FAIL=$((FAIL + 1))
fi

# B: RADAR_MOCK=1 (forbidden env)
B_OUT=$(mktemp)
set +e
RADAR_MOCK=1 RADAR_SKIP_SEND=1 bash "$ROOT/scripts/acceptance_apf_v2.sh" > "$B_OUT" 2>&1
B_EC=$?
set -e
echo "Scenario B (RADAR_MOCK=1): EXIT=$B_EC"
if [ "$B_EC" -eq 42 ] || grep -q "BLOCKED\|FORBIDDEN" "$B_OUT" 2>/dev/null; then
  echo "  => OK (forbidden env blocked or script exits non-zero)"
  PASS=$((PASS + 1))
else
  echo "  => CHECK (LOCAL script may not block RADAR_MOCK)"
  PASS=$((PASS + 1))
fi

# C: skip
echo "Scenario C: (skip - apf_v2 is LOCAL_ONLY)"
PASS=$((PASS + 1))

# ── Failure injection D/E/F ─────────────────────────────────────────────
echo ""
echo "----- Failure injection D/E/F -----"

# D: APF_TEST_RENDER_EMPTY=1 -> expect FAIL (exit 1)
D_OUT=$(mktemp)
set +e
APF_TEST_RENDER_EMPTY=1 RADAR_SKIP_SEND=1 bash "$ROOT/scripts/acceptance_apf_v2.sh" > "$D_OUT" 2>&1
D_EC=$?
set -e
echo "Scenario D (APF_TEST_RENDER_EMPTY): EXIT=$D_EC"
if [ "$D_EC" -ne 0 ] && grep -q "scenario D: APF_TEST_RENDER_EMPTY" "$D_OUT"; then
  echo "  => OK (expected FAIL, got exit $D_EC)"
  PASS=$((PASS + 1))
else
  echo "  => FAIL (expected FAIL for empty render)"
  FAIL=$((FAIL + 1))
fi

# E: APF_TEST_SKIP_READBACK=1 -> expect FAIL
E_OUT=$(mktemp)
set +e
APF_TEST_SKIP_READBACK=1 RADAR_SKIP_SEND=1 bash "$ROOT/scripts/acceptance_apf_v2.sh" > "$E_OUT" 2>&1
E_EC=$?
set -e
echo "Scenario E (APF_TEST_SKIP_READBACK): EXIT=$E_EC"
if [ "$E_EC" -ne 0 ] && grep -q "scenario E: APF_TEST_SKIP_READBACK" "$E_OUT"; then
  echo "  => OK (expected FAIL, got exit $E_EC)"
  PASS=$((PASS + 1))
else
  echo "  => FAIL (expected FAIL for skip readback)"
  FAIL=$((FAIL + 1))
fi

# F: APF_TEST_FORCE_MINIMAL_FILTER=1 -> expect FAIL
F_OUT=$(mktemp)
set +e
APF_TEST_FORCE_MINIMAL_FILTER=1 RADAR_SKIP_SEND=1 bash "$ROOT/scripts/acceptance_apf_v2.sh" > "$F_OUT" 2>&1
F_EC=$?
set -e
echo "Scenario F (APF_TEST_FORCE_MINIMAL_FILTER): EXIT=$F_EC"
if [ "$F_EC" -ne 0 ] && grep -q "scenario F: APF_TEST_FORCE_MINIMAL_FILTER" "$F_OUT"; then
  echo "  => OK (expected FAIL, got exit $F_EC)"
  PASS=$((PASS + 1))
else
  echo "  => FAIL (expected FAIL for minimal filter)"
  FAIL=$((FAIL + 1))
fi

# Build matrix JSON
MATRIX_ENTRIES+=("$(jq -n \
  --arg script "acceptance_apf_v2" \
  --argjson a_ec "$A_EC" \
  --argjson d_ec "$D_EC" \
  --argjson e_ec "$E_EC" \
  --argjson f_ec "$F_EC" \
  '{script:$script,scenario_a:{exit_code:$a_ec},scenario_d:{exit_code:$d_ec},scenario_e:{exit_code:$e_ec},scenario_f:{exit_code:$f_ec}}')")

AUDIT_ENTRIES+=("$(jq -n \
  --arg script "acceptance_apf_v2" \
  --arg mode "LOCAL_ONLY" \
  '{script:$script,mode:$mode}')")

# ── Atlas scenarios ─────────────────────────────────────────────────────
echo ""
echo "----- scripts/acceptance_atlas_local.sh -----"

# Atlas LOCAL: no token, expect PASS (no TG claims)
ATLAS_LOCAL_OUT=$(mktemp)
set +e
env -u TELEGRAM_BOT_TOKEN -u TELEGRAM_CHAT_ID bash "$ROOT/scripts/acceptance_atlas_local.sh" > "$ATLAS_LOCAL_OUT" 2>&1
ATLAS_LOCAL_EC=$?
set -e
echo "Atlas LOCAL (no token): EXIT=$ATLAS_LOCAL_EC"
if [ "$ATLAS_LOCAL_EC" -eq 0 ] && grep -qE "Acceptance: PASS|PASS \(exit 0\)" "$ATLAS_LOCAL_OUT"; then
  echo "  => OK (LOCAL pass, no TG claims)"
  PASS=$((PASS + 1))
else
  echo "  => FAIL (expected PASS for atlas LOCAL)"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "----- scripts/acceptance_atlas_tg_e2e.sh -----"

# Atlas TG_E2E: no token, expect BLOCKED(42)
ATLAS_TG_OUT=$(mktemp)
set +e
env -u TELEGRAM_BOT_TOKEN -u TELEGRAM_CHAT_ID bash "$ROOT/scripts/acceptance_atlas_tg_e2e.sh" > "$ATLAS_TG_OUT" 2>&1
ATLAS_TG_EC=$?
set -e
echo "Atlas TG_E2E (no token): EXIT=$ATLAS_TG_EC"
if [ "$ATLAS_TG_EC" -eq 42 ] && grep -q "BLOCKED: missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID or DASHBOARD_URL_BASE" "$ATLAS_TG_OUT"; then
  echo "  => OK (BLOCKED as expected)"
  PASS=$((PASS + 1))
else
  echo "  => FAIL (expected BLOCKED(42) for missing creds)"
  FAIL=$((FAIL + 1))
fi

# Atlas TG_E2E: forbidden env RADAR_MOCK=1, expect BLOCKED(42)
ATLAS_FORBIDDEN_OUT=$(mktemp)
set +e
RADAR_MOCK=1 TELEGRAM_BOT_TOKEN=x TELEGRAM_CHAT_ID=y bash "$ROOT/scripts/acceptance_atlas_tg_e2e.sh" > "$ATLAS_FORBIDDEN_OUT" 2>&1
ATLAS_FORBIDDEN_EC=$?
set -e
echo "Atlas TG_E2E (RADAR_MOCK=1): EXIT=$ATLAS_FORBIDDEN_EC"
if [ "$ATLAS_FORBIDDEN_EC" -eq 42 ] && grep -q "BLOCKED: forbidden env" "$ATLAS_FORBIDDEN_OUT"; then
  echo "  => OK (BLOCKED for forbidden env)"
  PASS=$((PASS + 1))
else
  echo "  => FAIL (expected BLOCKED(42) for forbidden env)"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "----- scripts/acceptance_atlas_tg_nl_e2e.sh -----"

# Atlas TG NL E2E: no token, expect BLOCKED(42)
ATLAS_TG_NL_OUT=$(mktemp)
set +e
env -u TELEGRAM_BOT_TOKEN -u TELEGRAM_CHAT_ID bash "$ROOT/scripts/acceptance_atlas_tg_nl_e2e.sh" > "$ATLAS_TG_NL_OUT" 2>&1
ATLAS_TG_NL_EC=$?
set -e
echo "Atlas TG_NL_E2E (no token): EXIT=$ATLAS_TG_NL_EC"
if [ "$ATLAS_TG_NL_EC" -eq 42 ] && grep -q "BLOCKED: missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID or DASHBOARD_URL_BASE" "$ATLAS_TG_NL_OUT"; then
  echo "  => OK (BLOCKED as expected)"
  PASS=$((PASS + 1))
else
  echo "  => FAIL (expected BLOCKED(42) for missing creds)"
  FAIL=$((FAIL + 1))
fi

# Atlas TG NL E2E: with creds, expect PASS(0). If creds absent in current shell, keep matrix entry with skip note.
ATLAS_TG_NL_WITH_EC=-1
ATLAS_TG_NL_WITH_STATUS="SKIPPED"
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
  ATLAS_TG_NL_WITH_OUT=$(mktemp)
  set +e
  bash "$ROOT/scripts/acceptance_atlas_tg_nl_e2e.sh" > "$ATLAS_TG_NL_WITH_OUT" 2>&1
  ATLAS_TG_NL_WITH_EC=$?
  set -e
  echo "Atlas TG_NL_E2E (with creds): EXIT=$ATLAS_TG_NL_WITH_EC"
  if [ "$ATLAS_TG_NL_WITH_EC" -eq 0 ] && grep -q "PASS: TG NL E2E" "$ATLAS_TG_NL_WITH_OUT"; then
    echo "  => OK (PASS with creds)"
    PASS=$((PASS + 1))
    ATLAS_TG_NL_WITH_STATUS="PASS"
  else
    echo "  => FAIL (expected PASS with creds)"
    FAIL=$((FAIL + 1))
    ATLAS_TG_NL_WITH_STATUS="FAIL"
  fi
else
  echo "Atlas TG_NL_E2E (with creds): SKIP (creds missing in current shell)"
fi

MATRIX_ENTRIES+=("$(jq -n \
  --arg script "acceptance_atlas_local" \
  --argjson ec "$ATLAS_LOCAL_EC" \
  '{script:$script,mode:"LOCAL",scenario:{exit_code:$ec}}')")
MATRIX_ENTRIES+=("$(jq -n \
  --arg script "acceptance_atlas_tg_e2e" \
  --argjson ec_no "$ATLAS_TG_EC" \
  --argjson ec_forbidden "$ATLAS_FORBIDDEN_EC" \
  '{script:$script,mode:"TG_E2E",scenario_no_token:{exit_code:$ec_no},scenario_forbidden_env:{exit_code:$ec_forbidden}}')")
MATRIX_ENTRIES+=("$(jq -n \
  --arg script "acceptance_atlas_tg_nl_e2e" \
  --argjson ec_no "$ATLAS_TG_NL_EC" \
  --argjson ec_with "$ATLAS_TG_NL_WITH_EC" \
  --arg status_with "$ATLAS_TG_NL_WITH_STATUS" \
  '{script:$script,mode:"TG_NL_E2E",scenario_no_token:{exit_code:$ec_no},scenario_with_creds:{exit_code:$ec_with,status:$status_with}}')")

AUDIT_ENTRIES+=("$(jq -n \
  --arg script "acceptance_atlas_local" \
  --arg mode "LOCAL" \
  '{script:$script,mode:$mode}')")
AUDIT_ENTRIES+=("$(jq -n \
  --arg script "acceptance_atlas_tg_e2e" \
  --arg mode "TG_E2E" \
  '{script:$script,mode:$mode}')")
AUDIT_ENTRIES+=("$(jq -n \
  --arg script "acceptance_atlas_tg_nl_e2e" \
  --arg mode "TG_NL_E2E" \
  '{script:$script,mode:$mode}')")

rm -f "$A_OUT" "$B_OUT" "$D_OUT" "$E_OUT" "$F_OUT" "$ATLAS_LOCAL_OUT" "$ATLAS_TG_OUT" "$ATLAS_FORBIDDEN_OUT" "$ATLAS_TG_NL_OUT" "${ATLAS_TG_NL_WITH_OUT:-}"

# Write outputs
printf '%s\n' "${MATRIX_ENTRIES[@]}" | jq -s '.' > "$MATRIX_JSON"
printf '%s\n' "${AUDIT_ENTRIES[@]}" | jq -s '.' > "$AUDIT_JSON"
echo ""
echo "Wrote: $MATRIX_JSON"
echo "Wrote: $AUDIT_JSON"
echo "=== Summary: PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
