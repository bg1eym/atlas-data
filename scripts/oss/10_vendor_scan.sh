#!/usr/bin/env bash
# OSS Hard-Learning: Vendor Scan
# Output: out/oss_learning/vendor_scan.json
# Collects: framework, component tree, layout files, interaction points

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OUT_DIR="${ROOT}/out/oss_learning"
VENDOR_DIR="${ROOT}/vendor"

mkdir -p "$OUT_DIR"

# Detect first vendor dir (e.g. vendor/situation-monitor)
VENDOR_NAME=""
if [ -d "$VENDOR_DIR" ]; then
  VENDOR_NAME=$(find "$VENDOR_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1 | xargs basename 2>/dev/null || true)
fi

VENDOR_ROOT="${VENDOR_DIR}/${VENDOR_NAME}"

if [ ! -d "$VENDOR_ROOT" ]; then
  echo '{"error":"No vendor directory found","vendor_root":""}' > "${OUT_DIR}/vendor_scan.json"
  echo "WARN: No vendor at $VENDOR_DIR" >&2
  exit 0
fi

# Collect stack hints
FRAMEWORK=""
[ -f "${VENDOR_ROOT}/package.json" ] && FRAMEWORK=$(jq -r '.dependencies.svelte // .dependencies.react // .dependencies.vue // "unknown"' "${VENDOR_ROOT}/package.json" 2>/dev/null || echo "unknown")

# Find key files
UI_ENTRYPOINTS=()
for p in index.html src/main.js src/main.ts src/App.svelte src/App.tsx src/App.vue; do
  [ -f "${VENDOR_ROOT}/$p" ] && UI_ENTRYPOINTS+=("$p") || true
done

LAYOUT_FILES=()
for c in Header Sidebar Dashboard Panel Card; do
  F=$(find "$VENDOR_ROOT" -type f \( -name "*${c}*.svelte" -o -name "*${c}*.tsx" -o -name "*${c}*.vue" \) 2>/dev/null | head -1)
  if [ -n "$F" ]; then
    LAYOUT_FILES+=("$(echo "$F" | sed "s|^${VENDOR_ROOT}/||")")
  fi
done
LAYOUT_FILES=($(printf '%s\n' "${LAYOUT_FILES[@]}" | sort -u))

jq -n \
  --arg vendor_name "$VENDOR_NAME" \
  --arg vendor_root "$VENDOR_ROOT" \
  --arg framework "$FRAMEWORK" \
  --argjson ui_entrypoints "$(printf '%s\n' "${UI_ENTRYPOINTS[@]:-}" | jq -R -s -c 'split("\n") | map(select(length>0))')" \
  --argjson layout_files "$(printf '%s\n' "${LAYOUT_FILES[@]}" | jq -R -s -c 'split("\n") | map(select(length>0)) | unique')" \
  '{
    vendor_name: $vendor_name,
    vendor_root: $vendor_root,
    framework: $framework,
    ui_entrypoints: $ui_entrypoints,
    layout_components: $layout_files,
    interaction_points: { filter: "see layout_files" }
  }' > "${OUT_DIR}/vendor_scan.json"

echo "Vendor scan written to ${OUT_DIR}/vendor_scan.json"
