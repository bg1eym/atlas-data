#!/usr/bin/env bash
# Atlas Activation Audit — Determine what code Telegram is actually running.
# Non-interactive. Exit 1 if loaded plugin dir cannot be determined.
# Prints: gateway process, plugin dir, help source, forbidden strings, conclusion.

set -euo pipefail

OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"
GATEWAY_PORT="${GATEWAY_PORT:-18789}"
HELP_ANCHOR="📡 Atlas Dashboard"

fail() {
  echo "AUDIT FAIL: $*" >&2
  exit 1
}

echo "=== 1) Gateway process on port ${GATEWAY_PORT} ==="
echo "\$ lsof -i :${GATEWAY_PORT} 2>/dev/null || true"
if lsof -i :${GATEWAY_PORT} 2>/dev/null || true; then
  :
else
  echo "(no process found or lsof unavailable)"
fi
echo ""

echo "=== 2) Loaded plugin dir from openclaw.json ==="
if [ ! -f "$OPENCLAW_JSON" ]; then
  fail "openclaw.json not found: $OPENCLAW_JSON"
fi
echo "\$ cat $OPENCLAW_JSON | jq '.plugins.load.paths, .plugins.installs[\"oc-bind\"]'"
cat "$OPENCLAW_JSON" | jq '.plugins.load.paths, .plugins.installs["oc-bind"]' 2>/dev/null || fail "jq failed"

PLUGIN_DIR=""
# Prefer load.paths[0], fallback to installs.oc-bind.installPath
PLUGIN_DIR=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // .plugins.installs["oc-bind"].sourcePath // empty' "$OPENCLAW_JSON" 2>/dev/null)
if [ -z "$PLUGIN_DIR" ] || [ "$PLUGIN_DIR" = "null" ]; then
  fail "Cannot determine loaded plugin dir from $OPENCLAW_JSON"
fi
if [ ! -d "$PLUGIN_DIR" ]; then
  fail "Plugin dir does not exist: $PLUGIN_DIR"
fi
echo "Resolved plugin dir: $PLUGIN_DIR"
echo ""

echo "=== 3) Help text source in plugin dir ==="
echo "\$ grep -rn \"$HELP_ANCHOR\" \"$PLUGIN_DIR\""
if grep -rn "$HELP_ANCHOR" "$PLUGIN_DIR" 2>/dev/null || true; then
  :
else
  echo "(no match)"
fi
echo ""

echo "=== 4) Forbidden radar strings in plugin dir ==="
FORBIDDEN=("radar:run" "OPENCLAW_ROOT" "/atlas radar" "radar_daily")
FOUND_ANY=0
for pat in "${FORBIDDEN[@]}"; do
  echo "\$ grep -rn \"$pat\" \"$PLUGIN_DIR\""
  if grep -rn "$pat" "$PLUGIN_DIR" 2>/dev/null; then
    FOUND_ANY=1
  fi
done
if [ "$FOUND_ANY" -eq 0 ]; then
  echo "(none found)"
fi
echo ""

echo "=== 5) Git HEAD of plugin dir ==="
echo "\$ git -C \"$PLUGIN_DIR\" rev-parse HEAD 2>/dev/null || echo norepo"
PLUGIN_SHA=$(git -C "$PLUGIN_DIR" rev-parse HEAD 2>/dev/null || echo "norepo")
echo "$PLUGIN_SHA"
echo ""

echo "=== 6) Help text source file:line ==="
HELP_SOURCE=$(grep -rn "$HELP_ANCHOR" "$PLUGIN_DIR" 2>/dev/null | head -1 || echo "")
if [ -n "$HELP_SOURCE" ]; then
  echo "$HELP_SOURCE"
else
  echo "(not found)"
fi
echo ""

echo "=== CONCLUSION ==="
echo "TG bot is using code from: $PLUGIN_DIR"
echo "That code HEAD is: $PLUGIN_SHA"
echo "Help text originates from: ${HELP_SOURCE:-(not found)}"
echo ""
echo "=== Audit complete ==="
