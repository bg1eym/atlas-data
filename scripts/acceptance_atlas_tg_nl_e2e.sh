#!/usr/bin/env bash
# Atlas TG Natural Language E2E acceptance.
# - No creds: BLOCKED(42) + audit summary verdict=BLOCKED
# - With creds: run NL handler -> atlas pipeline -> cover card send + provenance checks

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
HARD_RULES="${ROOT}/environment/HARD_RULES.json"
cd "$ROOT"
export PDF_EXTRACT_ALLOW_FALLBACK="${PDF_EXTRACT_ALLOW_FALLBACK:-1}"

PASS_EXIT=$(jq -r '.exit_codes.PASS // 0' "$HARD_RULES" 2>/dev/null || echo 0)
FAIL_EXIT=$(jq -r '.exit_codes.FAIL // 1' "$HARD_RULES" 2>/dev/null || echo 1)
BLOCKED_EXIT=$(jq -r '.exit_codes.BLOCKED // 42' "$HARD_RULES" 2>/dev/null || echo 42)

BLOCKED_RUN_ID="blocked-nl-$$"
BLOCKED_DIR="$ROOT/out/atlas/$BLOCKED_RUN_ID"
mkdir -p "$BLOCKED_DIR/audit"

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ] || [ -z "${DASHBOARD_URL_BASE:-}" ]; then
  REASON="missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID or DASHBOARD_URL_BASE"
  jq -n \
    --arg r "$REASON" \
    '{
      pipeline_verdict:"OK",
      delivery_verdict:"NOT_CONFIGURED",
      delivery_reason:$r,
      steps:["Configure TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, DASHBOARD_URL_BASE","See README_TG.md"],
      exit_code:42,
      mode:"TG_NL_E2E"
    }' > "$BLOCKED_DIR/audit/summary.json"
  echo "delivery_verdict=NOT_CONFIGURED"
  echo "delivery_reason=$REASON"
  echo "NOT_CONFIGURED: $REASON"
  echo "Configure in OpenClaw TG skill env or service. See README_TG.md"
  exit "$BLOCKED_EXIT"
fi

echo "=== acceptance_atlas_tg_nl_e2e: hard rules guard ==="
bash "$ROOT/scripts/lib/hard_rules_guard.sh" || exit "$BLOCKED_EXIT"

NL_INPUT="${ATLAS_NL_TEST_INPUT:-今天的文明态势雷达}"
echo "=== acceptance_atlas_tg_nl_e2e: simulate incoming message via Telegram API ==="
SIM_RESP=$(curl -sS -X POST \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\":\"${TELEGRAM_CHAT_ID}\",\"text\":\"[NL-E2E] ${NL_INPUT}\"}")
SIM_OK=$(echo "$SIM_RESP" | jq -r '.ok // false')
if [ "$SIM_OK" != "true" ]; then
  echo "FAIL: cannot simulate incoming NL message"
  echo "$SIM_RESP"
  exit "$FAIL_EXIT"
fi
SIM_MSG_ID=$(echo "$SIM_RESP" | jq -r '.result.message_id // 0')
echo "simulated_message_id=$SIM_MSG_ID"

echo "=== acceptance_atlas_tg_nl_e2e: run NL handler ==="
HANDLER_LOG=$(mktemp)
set +e
ATLAS_NL_TEXT="$NL_INPUT" npx tsx runtime/atlas/tg_nl_handler.ts > "$HANDLER_LOG" 2>&1
HANDLER_EC=$?
set -e
cat "$HANDLER_LOG"
if [ "$HANDLER_EC" -ne 0 ]; then
  echo "FAIL: tg_nl_handler exit=$HANDLER_EC"
  rm -f "$HANDLER_LOG"
  exit "$FAIL_EXIT"
fi

RUN_ID=$(awk -F= '/^run_id=/{print $2}' "$HANDLER_LOG" | tail -1)
OUT_DIR=$(awk -F= '/^out_dir=/{print $2}' "$HANDLER_LOG" | tail -1)
REPLY_MSG_ID=$(awk -F= '/^reply_message_id=/{print $2}' "$HANDLER_LOG" | tail -1)
DASHBOARD_URL=$(awk -F= '/^dashboard_url=/{print $2}' "$HANDLER_LOG" | tail -1)
rm -f "$HANDLER_LOG"

if [ -z "${RUN_ID:-}" ] || [ ! -d "${OUT_DIR:-}" ]; then
  echo "FAIL: NL handler did not produce atlas run output"
  exit "$FAIL_EXIT"
fi

TG_DIR="$OUT_DIR/tg"
PROV="$TG_DIR/provenance.json"
SENT_TEXT="$TG_DIR/sent_text.txt"
CARD="$OUT_DIR/tg_cover_card_zh.txt"

if [ ! -f "$PROV" ]; then
  echo "FAIL: missing tg/provenance.json"
  exit "$FAIL_EXIT"
fi
if ! jq -e '.chain_valid == true' "$PROV" >/dev/null 2>&1; then
  echo "FAIL: tg provenance chain invalid"
  exit "$FAIL_EXIT"
fi
if [ ! -f "$CARD" ]; then
  echo "FAIL: missing tg_cover_card_zh.txt"
  exit "$FAIL_EXIT"
fi
if grep -q "{{DASHBOARD_URL}}" "$CARD"; then
  echo "FAIL: cover card still contains {{DASHBOARD_URL}} placeholder"
  exit "$FAIL_EXIT"
fi
if [ ! -f "$SENT_TEXT" ]; then
  echo "FAIL: missing tg sent text evidence"
  exit "$FAIL_EXIT"
fi
if ! grep -q "🟦 打开 Dashboard：" "$SENT_TEXT"; then
  echo "FAIL: sent message missing dashboard line"
  exit "$FAIL_EXIT"
fi
BULLET_COUNT=$(grep -c '^• ' "$SENT_TEXT" || true)
if [ "${BULLET_COUNT:-0}" -lt 3 ]; then
  echo "FAIL: sent message should include >=3 Chinese bullets"
  exit "$FAIL_EXIT"
fi
if ! grep -qE 'https?://' "$SENT_TEXT"; then
  echo "FAIL: sent message missing dashboard url"
  exit "$FAIL_EXIT"
fi
if grep -q "^总条数:" "$SENT_TEXT"; then
  echo "FAIL: rendered preview leaked into TG message"
  exit "$FAIL_EXIT"
fi

mkdir -p "$OUT_DIR/audit"
jq -n \
  --arg run_id "$RUN_ID" \
  --arg out_dir "$OUT_DIR" \
  --arg nl_input "$NL_INPUT" \
  --arg reply_message_id "${REPLY_MSG_ID:-0}" \
  --arg dashboard_url "${DASHBOARD_URL:-}" \
  '{
    verdict:"PASS",
    exit_code:0,
    mode:"TG_NL_E2E",
    run_id:$run_id,
    out_dir:$out_dir,
    nl_input:$nl_input,
    reply_message_id:($reply_message_id|tonumber),
    dashboard_url:$dashboard_url
  }' > "$OUT_DIR/audit/summary.json"

echo "PASS: TG NL E2E"
echo "run_id=$RUN_ID"
echo "out_dir=$OUT_DIR"
echo "reply_message_id=${REPLY_MSG_ID:-0}"
echo "dashboard_url=${DASHBOARD_URL:-}"
exit "$PASS_EXIT"
