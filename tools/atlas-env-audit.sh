#!/usr/bin/env bash
# ATLAS-ITER-009: Audit gateway env and ATLAS_ROOT. Deterministic discovery + remediation.
# Output: tools/_out/atlas-env-audit.json

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUT_DIR="${ROOT}/tools/_out"
OUT_JSON="${OUT_DIR}/atlas-env-audit.json"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"
PLIST_PATH="${HOME}/Library/LaunchAgents/ai.openclaw.gateway.plist"

mkdir -p "${OUT_DIR}"

# 1) openclaw plugin installPath
PLUGIN_INSTALL_PATH=""
if [ -f "$OPENCLAW_JSON" ]; then
  PLUGIN_INSTALL_PATH=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // .plugins.installs.oc-bind.installPath // empty' "$OPENCLAW_JSON" 2>/dev/null || true)
fi

# 2) gateway launchd environment
LAUNCHD_OUT=$(launchctl print "gui/$(id -u)/ai.openclaw.gateway" 2>/dev/null || true)
ATLAS_ROOT_VAL=""
ATLAS_DASHBOARD_VAL=""
ATLAS_COVER_VAL=""
if [ -n "$LAUNCHD_OUT" ]; then
  ATLAS_ROOT_VAL=$(echo "$LAUNCHD_OUT" | grep "ATLAS_ROOT =>" | head -1 | sed 's/.*=> *//' | sed 's/[[:space:]]*$//' || true)
  ATLAS_DASHBOARD_VAL=$(echo "$LAUNCHD_OUT" | grep "ATLAS_DASHBOARD_URL_BASE =>" | head -1 | sed 's/.*=> *//' | sed 's/[[:space:]]*$//' || true)
  ATLAS_COVER_VAL=$(echo "$LAUNCHD_OUT" | grep "ATLAS_COVER_URL_BASE =>" | head -1 | sed 's/.*=> *//' | sed 's/[[:space:]]*$//' || true)
fi

# 3) validate ATLAS_ROOT
ATLAS_ROOT_EXISTS=false
ATLAS_ROOT_HAS_PKG=false
ATLAS_ROOT_HAS_SCRIPT=false
if [ -n "$ATLAS_ROOT_VAL" ] && [ -d "$ATLAS_ROOT_VAL" ]; then
  ATLAS_ROOT_EXISTS=true
  [ -f "${ATLAS_ROOT_VAL}/package.json" ] && ATLAS_ROOT_HAS_PKG=true
  if [ "$ATLAS_ROOT_HAS_PKG" = true ]; then
    grep -qE '"atlas:run"|atlas:run' "${ATLAS_ROOT_VAL}/package.json" 2>/dev/null && ATLAS_ROOT_HAS_SCRIPT=true
  fi
fi

# 4) discovery if invalid
CANDIDATES=()
RECOMMENDED_ROOT=""
if [ "$ATLAS_ROOT_EXISTS" != true ] || [ "$ATLAS_ROOT_HAS_PKG" != true ] || [ "$ATLAS_ROOT_HAS_SCRIPT" != true ]; then
  set +u
  [ -d "$HOME/Projects" ] && for dir in "$HOME/Projects"/*/; do
    [ -d "$dir" ] || continue
    d="${dir%/}"
    PKG="${d}/package.json"
    [ -f "$PKG" ] || continue
    grep -qE '"atlas:run"|atlas:run' "$PKG" 2>/dev/null || continue
    [[ " ${CANDIDATES[*]} " == *" $d "* ]] || CANDIDATES+=("$d")
  done
  for dir in "$HOME/Projects/atlas-radar" "$HOME/Projects/atlas_radar" "$HOME/atlas-radar" "$ROOT"; do
    [ -d "$dir" ] || continue
    [ -f "${dir}/package.json" ] || continue
    grep -qE '"atlas:run"|atlas:run' "${dir}/package.json" 2>/dev/null || continue
    [[ " ${CANDIDATES[*]} " == *" $dir "* ]] || CANDIDATES+=("$dir")
  done
  set -u
  if [ ${#CANDIDATES[@]} -gt 0 ]; then
    for c in "${CANDIDATES[@]}"; do
      if [[ "$(basename "$c")" == "atlas-radar" ]]; then
        RECOMMENDED_ROOT="$c"
        break
      fi
    done
    [ -z "$RECOMMENDED_ROOT" ] && RECOMMENDED_ROOT="${CANDIDATES[0]}"
  fi
fi

# 5) conclusion
ROOT_CAUSE="OK"
if [ -z "$LAUNCHD_OUT" ]; then
  ROOT_CAUSE="GATEWAY_ENV_MISSING"
elif [ -z "$ATLAS_ROOT_VAL" ]; then
  ROOT_CAUSE="ATLAS_ROOT_UNKNOWN"
elif [ "$ATLAS_ROOT_EXISTS" != true ] || [ "$ATLAS_ROOT_HAS_PKG" != true ] || [ "$ATLAS_ROOT_HAS_SCRIPT" != true ]; then
  ROOT_CAUSE="ATLAS_ROOT_INVALID"
fi

# 6) next_fix (PlistBuddy command)
NEXT_FIX=""
if [ "$ROOT_CAUSE" != "OK" ] && [ -n "$RECOMMENDED_ROOT" ] && [ -f "$PLIST_PATH" ]; then
  NEXT_FIX="/usr/libexec/PlistBuddy -c \"Set :ATLAS_ROOT $RECOMMENDED_ROOT\" $PLIST_PATH"
elif [ "$ROOT_CAUSE" != "OK" ] && [ -n "$RECOMMENDED_ROOT" ]; then
  NEXT_FIX="# Plist not at $PLIST_PATH; set ATLAS_ROOT=$RECOMMENDED_ROOT in gateway env"
fi

CAND_JSON=$(printf '%s\n' "${CANDIDATES[@]}" | jq -R -s -c 'split("\n") | map(select(length>0))')
jq -n \
  --arg plugin_path "$PLUGIN_INSTALL_PATH" \
  --arg atlas_root "$ATLAS_ROOT_VAL" \
  --arg dashboard "$ATLAS_DASHBOARD_VAL" \
  --arg cover "$ATLAS_COVER_VAL" \
  --argjson exists "$([ "$ATLAS_ROOT_EXISTS" = true ] && echo true || echo false)" \
  --argjson has_pkg "$([ "$ATLAS_ROOT_HAS_PKG" = true ] && echo true || echo false)" \
  --argjson has_script "$([ "$ATLAS_ROOT_HAS_SCRIPT" = true ] && echo true || echo false)" \
  --argjson candidates "$CAND_JSON" \
  --arg recommended "$RECOMMENDED_ROOT" \
  --arg root_cause "$ROOT_CAUSE" \
  --arg next_fix "$NEXT_FIX" \
  --arg plist "$PLIST_PATH" \
  '{
    openclaw_plugin_installPath: $plugin_path,
    gateway_env: {
      ATLAS_ROOT: $atlas_root,
      ATLAS_DASHBOARD_URL_BASE: $dashboard,
      ATLAS_COVER_URL_BASE: $cover
    },
    atlas_root_validation: {
      path_exists: $exists,
      has_package_json: $has_pkg,
      has_script_atlas_run: $has_script
    },
    discovery: {
      candidates: $candidates,
      recommended_root: $recommended
    },
    conclusion: {
      root_cause: $root_cause,
      next_fix: $next_fix
    },
    plist_path: $plist
  }' > "$OUT_JSON"

echo "atlas-env-audit: root_cause=$ROOT_CAUSE"
cat "$OUT_JSON"
