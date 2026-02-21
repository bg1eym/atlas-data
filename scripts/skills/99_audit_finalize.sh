#!/usr/bin/env bash
# Audit Finalize: 写入 verdict 并校验 steps>=6 (INV-S3)
# 用法: $0 <verdict> [exit_code] [reason]
# 若 steps<6 会 pad 并可能覆盖为 FAIL(1)

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}}"
[ -f "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/00_guard.sh" 2>/dev/null || true
[ -f "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/lib_audit.sh" 2>/dev/null || true

verdict="${1:-PENDING}"
exit_code="${2:-0}"
reason="${3:-}"

audit_finalize "$verdict" "$exit_code" "$reason"
ab="${OUT_BASE:-${SKILLS_OUT_BASE:-$ROOT/out/skills/${SKILLS_RUN_ID:-unknown}}}"
ec=$(jq -r '.exit_code // 0' "$ab/audit/summary.json" 2>/dev/null || echo 0)
exit "${ec:-0}"
