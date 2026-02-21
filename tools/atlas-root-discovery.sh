#!/usr/bin/env bash
# ATLAS-008: Discover atlas-radar repo root deterministically.
# Output: tools/_out/atlas-root-discovery.json
# { candidates[], selected_root, why_selected }

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUT_DIR="${ROOT}/tools/_out"
OUT_JSON="${OUT_DIR}/atlas-root-discovery.json"
mkdir -p "${OUT_DIR}"

CANDIDATES=()
WHY_SELECTED=""

# Fixed candidates
for dir in \
  "$HOME/Projects/atlas-radar" \
  "$HOME/Projects/atlas_radar" \
  "$HOME/atlas-radar" \
  "$HOME/Projects/vibe-template/projects/atlas-radar" \
  "$HOME/openclaw/atlas-radar" \
  "$ROOT"; do
  [ -d "$dir" ] || continue
  PKG="$dir/package.json"
  [ -f "$PKG" ] || continue
  if grep -qE '"atlas:run"|atlas:run' "$PKG" 2>/dev/null; then
    CANDIDATES+=("$dir")
  fi
done

# Git repos under $HOME/Projects with atlas:run
if [ -d "$HOME/Projects" ]; then
  for gitdir in "$HOME/Projects"/*/; do
    [ -d "$gitdir" ] || continue
    [ -d "${gitdir}.git" ] || continue
    PKG="${gitdir}package.json"
    [ -f "$PKG" ] || continue
    if grep -qE '"atlas:run"|atlas:run' "$PKG" 2>/dev/null; then
      d="${gitdir%/}"
      dup=0
      for c in "${CANDIDATES[@]}"; do [ "$c" = "$d" ] && dup=1 && break; done
      [ $dup -eq 0 ] && CANDIDATES+=("$d")
    fi
  done
fi

# Deduplicate by realpath
SEEN=()
CANDIDATES_UNIQ=()
for c in "${CANDIDATES[@]}"; do
  r=$(cd "$c" 2>/dev/null && pwd -P) || r="$c"
  dup=0
  for s in "${SEEN[@]}"; do [ "$s" = "$r" ] && dup=1 && break; done
  [ $dup -eq 0 ] && { SEEN+=("$r"); CANDIDATES_UNIQ+=("$c"); }
done
CANDIDATES=("${CANDIDATES_UNIQ[@]}")

SELECTED_ROOT=""
if [ ${#CANDIDATES[@]} -eq 1 ]; then
  SELECTED_ROOT="${CANDIDATES[0]}"
  WHY_SELECTED="single_unambiguous_candidate"
elif [ ${#CANDIDATES[@]} -gt 1 ]; then
  # Prefer exact atlas-radar name
  for c in "${CANDIDATES[@]}"; do
    if [[ "$(basename "$c")" == "atlas-radar" ]]; then
      SELECTED_ROOT="$c"
      WHY_SELECTED="preferred_atlas_radar_named"
      break
    fi
  done
  [ -z "$SELECTED_ROOT" ] && SELECTED_ROOT="${CANDIDATES[0]}" && WHY_SELECTED="first_of_multiple"
fi

CAND_JSON=$(printf '%s\n' "${CANDIDATES[@]}" | jq -R -s -c 'split("\n") | map(select(length>0))')
jq -n \
  --argjson candidates "$CAND_JSON" \
  --arg selected "$SELECTED_ROOT" \
  --arg why "$WHY_SELECTED" \
  '{ candidates: $candidates, selected_root: $selected, why_selected: $why }' > "$OUT_JSON"

if [ -z "$SELECTED_ROOT" ]; then
  echo "ATLAS_ROOT discovery: no candidate found. Checked: ${CANDIDATES[*]:-none}" >&2
  echo "Create atlas-radar repo with package.json containing atlas:run script." >&2
  cat "$OUT_JSON"
  exit 1
fi

echo "ATLAS_ROOT discovery: selected_root=$SELECTED_ROOT why=$WHY_SELECTED"
cat "$OUT_JSON"
exit 0
