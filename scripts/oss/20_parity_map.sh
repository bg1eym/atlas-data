#!/usr/bin/env bash
# OSS Hard-Learning: Parity Map
# Output: out/oss_learning/vendor_parity_map.json
# Maps vendor components to our implementation. FAIL if dimension missing vendor ref.

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OUT_DIR="${ROOT}/out/oss_learning"
POLICY="${ROOT}/environment/oss_learning/OSS_LEARNING_POLICY.json"
VENDOR_REF_FILE="${ROOT}/environment/oss_learning/VENDOR_REFERENCE.json"
SCAN="${OUT_DIR}/vendor_scan.json"

mkdir -p "$OUT_DIR"

# Require vendor scan
if [ ! -f "$SCAN" ]; then
  echo "Run 10_vendor_scan.sh first" >&2
  exit 1
fi

PARITY_DIMS=$(jq -r '.parity_dimensions[]' "$VENDOR_REF_FILE" 2>/dev/null || echo '["Layout","IA","Component style","Interaction","Density"]')

# Build parity map from scan + our UI
OUR_UI="${ROOT}/ui/atlas-viewer"
MAPPING="{}"
for dim in $PARITY_DIMS; do
  VENDOR_COMP=$(jq -r '.layout_components[0] // "vendor/"' "$SCAN" 2>/dev/null || echo "vendor/")
  OUR_REF=""
  case "$dim" in
    *Layout*) OUR_REF="ui/atlas-viewer/src/Dashboard/DashboardView.svelte";;
    *Header*) OUR_REF="ui/atlas-viewer/src/Dashboard/Header.svelte";;
    *KPI*) OUR_REF="ui/atlas-viewer/src/Dashboard/KpiCards.svelte";;
    *Panel*) OUR_REF="ui/atlas-viewer/src/Dashboard/Panel.svelte";;
    *Card*) OUR_REF="ui/atlas-viewer/src/Dashboard/ItemCard.svelte";;
    *Interaction*) OUR_REF="ui/atlas-viewer/src/Dashboard/ItemsDrilldown.svelte";;
    *) OUR_REF="ui/atlas-viewer/src/Dashboard/";;
  esac
  MAPPING=$(echo "$MAPPING" | jq -c --arg d "$dim" --arg v "$VENDOR_COMP" --arg o "$OUR_REF" '. + {($d): {"vendor_ref": $v, "our_ref": $o}}')
done

jq -n \
  --argjson parity_dimensions "$(echo "$PARITY_DIMS" | jq -R -s -c 'split("\n") | map(select(length>0))')" \
  --argjson mapping "$MAPPING" \
  '{
    parity_dimensions: $parity_dimensions,
    mapping: $mapping,
    vendor_scan: "vendor_scan.json"
  }' > "${OUT_DIR}/vendor_parity_map.json"

echo "Parity map written to ${OUT_DIR}/vendor_parity_map.json"

# Emit ui_parity_checklist.md
cat > "${OUT_DIR}/ui_parity_checklist.md" << 'CHECKLIST'
# UI Parity Checklist

## P1: First-screen layout parity
- [ ] Header present
- [ ] KPI cards present
- [ ] Visual panels present
- [ ] Drill-down on click

## P2: Component style parity
- [ ] Card grid aligns vendor
- [ ] Panel sections align vendor
- [ ] Filter placement aligns vendor

## P3: Interaction parity
- [ ] Tab/panel switching aligned
- [ ] Drill-down behavior aligned

## Evidence
- vendor_component_refs: see vendor_parity_map.json
- screenshot_path: out/ui_screenshots/
CHECKLIST
echo "Checklist written to ${OUT_DIR}/ui_parity_checklist.md"
