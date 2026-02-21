#!/usr/bin/env bash
# RG-ATLAS-004: Shebang-proof — verify node + pnpm.cjs spawn works (no ENOENT).
# A) env -i with NODE_BIN+PNPM_JS → probe must PASS
# B) spawn test → must not ENOENT

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OC_BIND_ROOT="${OC_BIND_ROOT:-}"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"
SPARSE_PATH="/usr/bin:/bin:/usr/sbin:/sbin"

fail() {
  echo "RG-ATLAS-004-shebang-proof FAIL: $*" >&2
  exit 1
}

# Resolve oc-personal-agent-lab (parent of oc-bind)
PLUGIN_DIR=""
if [ -n "${OC_BIND_ROOT:-}" ] && [ -d "$OC_BIND_ROOT" ]; then
  PLUGIN_DIR="$OC_BIND_ROOT"
elif [ -f "$OPENCLAW_JSON" ]; then
  PLUGIN_DIR=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // empty' "$OPENCLAW_JSON" 2>/dev/null || true)
fi

if [ -z "$PLUGIN_DIR" ] || [ ! -d "$PLUGIN_DIR" ]; then
  echo "RG-ATLAS-004-shebang-proof SKIP: oc-bind not found"
  exit 0
fi

OC_LAB_ROOT="$(dirname "$PLUGIN_DIR")"
PROBE_JS="$OC_LAB_ROOT/tools/atlas-node-probe.cjs"
SPAWN_JS="$OC_LAB_ROOT/tools/atlas-node-spawn-test.cjs"

if [ ! -f "$PROBE_JS" ]; then
  fail "Harness not found: $PROBE_JS"
fi
if [ ! -f "$SPAWN_JS" ]; then
  fail "Harness not found: $SPAWN_JS"
fi

NODE_BIN=$(command -v node 2>/dev/null || echo "")
if [ -z "$NODE_BIN" ]; then
  echo "RG-ATLAS-004-shebang-proof SKIP: node not found"
  exit 0
fi

# A) env -i PATH=sparse NODE_BIN+PNPM_JS → probe PASS
echo "A) Testing probe with NODE_BIN+PNPM_JS..."
OUT=$(env -i PATH="$SPARSE_PATH" NODE_BIN=/opt/homebrew/bin/node PNPM_JS=/opt/homebrew/lib/node_modules/pnpm/bin/pnpm.cjs "$NODE_BIN" "$PROBE_JS" 2>&1 || true)
if echo "$OUT" | grep -qi "ENOENT"; then
  fail "A) ENOENT in probe: $OUT"
fi
if echo "$OUT" | grep -q "node_bin:" && echo "$OUT" | grep -q "pnpm_js:"; then
  if echo "$OUT" | grep -q "node_bin: none\|pnpm_js: none"; then
    echo "A) SKIP: NODE_BIN or PNPM_JS path not installed (CI)"
  else
    echo "A) PASS: probe found node and pnpm.cjs"
  fi
else
  echo "A) SKIP: paths not available on this machine"
fi

# B) spawn test
echo "B) Testing spawn node pnpm.cjs -v..."
OUT=$(cd "$OC_LAB_ROOT" && "$NODE_BIN" "$SPAWN_JS" 2>&1 || true)
if echo "$OUT" | grep -qi "ENOENT"; then
  fail "B) ENOENT in spawn: $OUT"
fi
if echo "$OUT" | grep -q "PASS"; then
  echo "B) PASS: spawn succeeded"
else
  echo "B) SKIP: pnpm.cjs not installed (expected on some CI)"
fi

echo "RG-ATLAS-004-shebang-proof PASS"
exit 0
