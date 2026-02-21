#!/usr/bin/env bash
# PCK-ATLAS-006B: Publish latest local run to atlas-data repo.
# Non-interactive. Copies run folder, updates latest.json + index.json, commit + push.
#
# Env: ATLAS_ROOT (atlas-radar root), ATLAS_DATA_REPO (path to atlas-data repo)
# Usage: bash tools/atlas-publish-latest.sh

set -euo pipefail

ATLAS_ROOT="${ATLAS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ATLAS_DATA_REPO="${ATLAS_DATA_REPO:-}"
OUT_ATLAS="${ATLAS_ROOT}/out/atlas"
INDEX_KEEP=30

if [ -z "${ATLAS_DATA_REPO}" ] || [ ! -d "${ATLAS_DATA_REPO}" ]; then
  echo "ATLAS_DATA_REPO not set or not a directory. Set to atlas-data repo path."
  exit 1
fi

# Detect latest run_id (by mtime)
LATEST_RUN=""
LATEST_MTIME=0
for d in "${OUT_ATLAS}"/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  [[ "$name" == DELIVERY_RAW_STDOUT ]] && continue
  [ -f "${d}result.json" ] || continue
  mtime=$(stat -f %m "$d" 2>/dev/null || stat -c %Y "$d" 2>/dev/null || echo 0)
  if [ "${mtime}" -gt "${LATEST_MTIME}" ]; then
    LATEST_MTIME=$mtime
    LATEST_RUN=$name
  fi
done

if [ -z "$LATEST_RUN" ]; then
  echo "No run with result.json in ${OUT_ATLAS}"
  exit 1
fi

DATA_OUT="${ATLAS_DATA_REPO}/out/atlas"
mkdir -p "${DATA_OUT}"
RUN_DEST="${DATA_OUT}/${LATEST_RUN}"

# Copy run folder (rsync or cp -r)
if command -v rsync &>/dev/null; then
  rsync -a --delete "${OUT_ATLAS}/${LATEST_RUN}/" "${RUN_DEST}/"
else
  rm -rf "${RUN_DEST}"
  cp -R "${OUT_ATLAS}/${LATEST_RUN}" "${RUN_DEST}"
fi

# Read generated_at from result.json
GENERATED_AT=""
if [ -f "${RUN_DEST}/result.json" ]; then
  GENERATED_AT=$(jq -r '.generated_at // ""' "${RUN_DEST}/result.json" 2>/dev/null || echo "")
fi
PUBLISHED_AT=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# Update latest.json
echo "{\"run_id\":\"${LATEST_RUN}\",\"published_at\":\"${PUBLISHED_AT}\",\"generated_at\":\"${GENERATED_AT}\"}" > "${DATA_OUT}/latest.json"

# Update index.json: prepend new run, keep last N
INDEX_FILE="${DATA_OUT}/index.json"
NEW_ENTRY="{\"run_id\":\"${LATEST_RUN}\",\"published_at\":\"${PUBLISHED_AT}\"}"
if [ -f "${INDEX_FILE}" ] && command -v jq &>/dev/null; then
  RUNS=$(jq -c --argjson new "$NEW_ENTRY" '.runs | [$new] + map(select(.run_id != $new.run_id)) | .[0:'$INDEX_KEEP']' "${INDEX_FILE}" 2>/dev/null || echo "[]")
else
  RUNS="[]"
fi
if [ -z "$RUNS" ] || [ "$RUNS" = "[]" ]; then
  RUNS="[$NEW_ENTRY]"
fi
echo "{\"runs\":$RUNS}" > "${INDEX_FILE}"

# Commit + push (non-interactive)
cd "${ATLAS_DATA_REPO}"
git add out/atlas/
git add -u out/atlas/
if git diff --staged --quiet 2>/dev/null; then
  echo "No changes to publish (${LATEST_RUN} already in atlas-data)"
  exit 0
fi
git -c user.email="atlas-publish@local" -c user.name="atlas-publish" commit -m "publish: ${LATEST_RUN}"
git push

echo "Published ${LATEST_RUN} to atlas-data"
