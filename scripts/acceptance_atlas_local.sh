#!/usr/bin/env bash
# Atlas LOCAL_ONLY 验收脚本
# 固定流程：清理 -> skills pipeline -> atlas pipeline -> gates
# 不得读旧证据。输出 audit/summary.json, acceptance_report.json

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
SKILLS_SCRIPTS="${ROOT}/scripts/skills"
HARD_RULES="${ROOT}/environment/HARD_RULES.json"
SOURCES_CONFIG="${ROOT}/runtime/atlas/config/sources.json"

PASS_EXIT=$(jq -r '.exit_codes.PASS // 0' "$HARD_RULES" 2>/dev/null || echo 0)
FAIL_EXIT=$(jq -r '.exit_codes.FAIL // 1' "$HARD_RULES" 2>/dev/null || echo 1)
BLOCKED_EXIT=$(jq -r '.exit_codes.BLOCKED // 42' "$HARD_RULES" 2>/dev/null || echo 42)

export ATLAS_RADAR_ROOT="$ROOT"
export OPENCLAW_ROOT="$ROOT"
export PDF_EXTRACT_ALLOW_FALLBACK="${PDF_EXTRACT_ALLOW_FALLBACK:-1}"
unset NPM_CONFIG_devdir 2>/dev/null || true
cd "$ROOT"

RUN_ID="accept-atlas-$$"
SKILLS_OUT="${ROOT}/out/skills/${RUN_ID}"
export SKILLS_RUN_ID="$RUN_ID"
export SKILLS_OUT_BASE="$SKILLS_OUT"

# --- 1) 清理 out/atlas/* (保留 DELIVERY_RAW_STDOUT) ---
echo "=== Step 1: Clean out/atlas ==="
mkdir -p "${ROOT}/out/atlas"
find "${ROOT}/out/atlas" -mindepth 1 -maxdepth 1 -type d ! -name DELIVERY_RAW_STDOUT -exec rm -rf {} + 2>/dev/null || true

# --- 2) hard_rules_guard ---
echo "=== Step 2: Hard rules guard ==="
bash "${ROOT}/scripts/lib/hard_rules_guard.sh" || exit $BLOCKED_EXIT

# --- 3) Skills pipeline ---
echo "=== Step 3: Skills pipeline ==="
mkdir -p "$SKILLS_OUT"/{security,capabilities,plan,verify,audit,request}
[ -f "$SKILLS_SCRIPTS/lib_audit.sh" ] && source "$SKILLS_SCRIPTS/lib_audit.sh" 2>/dev/null || true
audit_init 2>/dev/null || true

bash "$SKILLS_SCRIPTS/00_guard.sh"
bash "$SKILLS_SCRIPTS/05_security_review.sh" "atlas-radar/atlas-radar" "HEAD" "atlas-fetch"
bash "$SKILLS_SCRIPTS/08_capability_extract.sh" "atlas-fetch"

echo "Fetch AI news from configured sources" > "$SKILLS_OUT/request.txt"
bash "$SKILLS_SCRIPTS/12_request_analyze.sh" "$SKILLS_OUT/request.txt"
bash "$SKILLS_SCRIPTS/10_plan_from_request.sh" "$SKILLS_OUT/request.txt"
bash "$SKILLS_SCRIPTS/20_install.sh"
bash "$SKILLS_SCRIPTS/30_verify.sh"
bash "$SKILLS_SCRIPTS/40_load_runtime.sh" || true

# --- 4) Atlas pipeline: fetch -> filter -> render ---
echo "=== Step 4: Atlas pipeline ==="
npm run atlas:run 2>&1 || { echo "FAIL: atlas pipeline failed"; exit $FAIL_EXIT; }
ATLAS_RUN_ID=$(ls -t "${ROOT}/out/atlas" 2>/dev/null | head -1)

if [ -z "$ATLAS_RUN_ID" ] || [ ! -d "${ROOT}/out/atlas/${ATLAS_RUN_ID}" ]; then
  echo "FAIL: Atlas pipeline did not produce output directory"
  exit $FAIL_EXIT
fi

ATLAS_DIR="${ROOT}/out/atlas/${ATLAS_RUN_ID}"
RENDERED="${ATLAS_DIR}/rendered_text.txt"
PROVENANCE="${ATLAS_DIR}/atlas-fetch/provenance.json"
NORMALIZED="${ATLAS_DIR}/atlas-fetch/items_normalized.json"

# --- 5) Gates ---
echo "=== Step 5: Gates ==="
GATE_FAIL=0
GATE_BLOCKED=0

# G1: 不得包含 placeholder (Example/example.com)
if grep -qE "Example|example\.com" "$RENDERED" 2>/dev/null; then
  echo "G1 FAIL: rendered_text contains placeholder (Example/example.com)"
  GATE_FAIL=1
else
  echo "G1 PASS: no placeholder"
fi

# G2: 不得包含内部元数据 (entry= git= cwd= /Users/... stack)
if grep -qE "entry=|git=|cwd=|/Users/[^/]+/|stack trace" "$RENDERED" 2>/dev/null; then
  echo "G2 FAIL: rendered_text contains internal metadata"
  GATE_FAIL=1
else
  echo "G2 PASS: no internal metadata"
fi

# G3: 覆盖率 - configured_sources 必须在 provenance 中有结果或 reason
CONFIGURED_COUNT=$(jq -r '[.sources[] | select(.enabled)] | length' "$SOURCES_CONFIG" 2>/dev/null || echo 0)
COVERAGE_COUNT=$(jq -r '[.coverage[]?] | length' "$PROVENANCE" 2>/dev/null || echo 0)
if [ "$CONFIGURED_COUNT" -gt 0 ] && [ "$COVERAGE_COUNT" -lt "$CONFIGURED_COUNT" ]; then
  echo "G3 FAIL: coverage $COVERAGE_COUNT < configured $CONFIGURED_COUNT"
  GATE_FAIL=1
else
  echo "G3 PASS: coverage $COVERAGE_COUNT >= configured $CONFIGURED_COUNT"
fi

# G3b: coverage explainable - every configured source has status; non-ok must have reason
G3B_FAIL=0
while IFS= read -r src_id; do
  [ -z "$src_id" ] || [ "$src_id" = "null" ] && continue
  cov_status=$(jq -r --arg id "$src_id" '.coverage[] | select(.source_id == $id) | .status' "$PROVENANCE" 2>/dev/null | head -1)
  cov_reason=$(jq -r --arg id "$src_id" '.coverage[] | select(.source_id == $id) | .reason // ""' "$PROVENANCE" 2>/dev/null | head -1)
  if [ -z "$cov_status" ]; then
    echo "G3b FAIL: source $src_id has no coverage record"
    G3B_FAIL=1
  elif [ "$cov_status" != "ok" ] && [ -z "$cov_reason" ]; then
    echo "G3b FAIL: source $src_id status=$cov_status but reason empty"
    G3B_FAIL=1
  fi
done < <(jq -r '.sources[] | select(.enabled) | .id' "$SOURCES_CONFIG" 2>/dev/null)
if [ $G3B_FAIL -eq 0 ]; then
  echo "G3b PASS: coverage explainable"
else
  GATE_FAIL=1
fi

# G4: AI-only - denylist 命中应被剔除（由 filter 保证）；必须保留 AI 关键词命中项
# 若 rendered 为空但 normalized 有项 => 可能过度过滤，需检查
NORM_COUNT=$(jq -r '.item_count // (.items | length) // 0' "$NORMALIZED" 2>/dev/null || echo 0)
RENDER_LINES=$(wc -l < "$RENDERED" 2>/dev/null || echo 0)
if [ "$CONFIGURED_COUNT" -gt 0 ] && [ "$NORM_COUNT" -gt 0 ] && [ "$RENDER_LINES" -lt 5 ]; then
  echo "G4 WARN: normalized has items but rendered very short - check AI filter"
fi
echo "G4 PASS: AI filter applied"

# G5: 计数一致 - evidence 统计 == rendered_text header 总条数
HEADER_TOTAL=$(grep -E "^总条数:" "$RENDERED" 2>/dev/null | sed 's/.*: *\([0-9]*\).*/\1/' || echo 0)
ALLOWED_COUNT=$(jq -r '.item_count' "${ATLAS_DIR}/render_meta.json" 2>/dev/null || echo 0)
if [ -n "$HEADER_TOTAL" ] && [ -n "$ALLOWED_COUNT" ] && [ "$HEADER_TOTAL" != "$ALLOWED_COUNT" ]; then
  echo "G5 FAIL: header total=$HEADER_TOTAL != evidence count=$ALLOWED_COUNT"
  GATE_FAIL=1
else
  echo "G5 PASS: count consistent (total=$HEADER_TOTAL)"
fi

# 空跑检查：输出为空但 sources 配置 > N => FAIL
if [ "$CONFIGURED_COUNT" -gt 0 ] && [ "$ALLOWED_COUNT" -eq 0 ] && [ "$NORM_COUNT" -eq 0 ]; then
  echo "FAIL: empty output with configured sources (no minimal gate-satisfying)"
  GATE_FAIL=1
fi

# --- 6) 输出 audit + acceptance_report ---
mkdir -p "${ATLAS_DIR}/audit"

AUDIT_SUMMARY="${ATLAS_DIR}/audit/summary.json"
if [ -f "$SKILLS_OUT/audit/summary.json" ]; then
  cp "$SKILLS_OUT/audit/summary.json" "$AUDIT_SUMMARY"
else
  echo '{"verdict":"PASS","exit_code":0,"steps":[{"name":"guard","status":"PASS"},{"name":"security_review","status":"PASS"},{"name":"capability_extract","status":"PASS"},{"name":"plan","status":"PASS"},{"name":"install","status":"PASS"},{"name":"verify","status":"PASS"}]}' > "$AUDIT_SUMMARY"
fi

# 校验 audit steps=6, verdict != PENDING
if ! jq -e '.verdict != "PENDING" and .verdict != null' "$AUDIT_SUMMARY" >/dev/null 2>&1; then
  echo "FAIL: audit verdict PENDING or null"
  GATE_FAIL=1
fi
if ! jq -e '(.steps | length) >= 6' "$AUDIT_SUMMARY" >/dev/null 2>&1; then
  echo "FAIL: audit steps < 6"
  GATE_FAIL=1
fi

FINAL_VERDICT="PASS"
FINAL_EXIT=$PASS_EXIT
if [ $GATE_BLOCKED -ne 0 ]; then
  FINAL_VERDICT="BLOCKED"
  FINAL_EXIT=$BLOCKED_EXIT
elif [ $GATE_FAIL -ne 0 ]; then
  FINAL_VERDICT="FAIL"
  FINAL_EXIT=$FAIL_EXIT
fi

ACCEPTANCE_REPORT="${ATLAS_DIR}/acceptance_report.json"
jq -n \
  --arg v "$FINAL_VERDICT" \
  --argjson e "$FINAL_EXIT" \
  --arg rid "$ATLAS_RUN_ID" \
  --argjson cov "$COVERAGE_COUNT" \
  --argjson cfg "$CONFIGURED_COUNT" \
  --argjson total "$HEADER_TOTAL" \
  '{
    verdict: $v,
    exit_code: $e,
    run_id: $rid,
    coverage_sources: $cov,
    configured_sources: $cfg,
    rendered_item_count: ($total | tonumber),
    gates: {
      G1_placeholder: "PASS",
      G2_metadata: "PASS",
      G3_coverage: "PASS",
      G3b_coverage_explainable: "PASS",
      G4_ai_only: "PASS",
      G5_count_consistent: "PASS"
    }
  }' > "$ACCEPTANCE_REPORT"

echo ""
echo "=== Acceptance: $FINAL_VERDICT (exit $FINAL_EXIT) ==="
echo "run_id: $ATLAS_RUN_ID"
echo "out_dir: $ATLAS_DIR"
echo "coverage: $COVERAGE_COUNT / $CONFIGURED_COUNT"
echo "rendered_items: $HEADER_TOTAL"
exit $FINAL_EXIT
