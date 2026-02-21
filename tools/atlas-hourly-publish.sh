#!/usr/bin/env bash
# PCK-ATLAS-006B: Hourly publish — if newest local run not yet in atlas-data, publish it.
# Non-interactive. Invoke from launchd or cron.
#
# Env: ATLAS_ROOT, ATLAS_DATA_REPO

set -euo pipefail

ATLAS_ROOT="${ATLAS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ATLAS_DATA_REPO="${ATLAS_DATA_REPO:-}"

if [ -z "${ATLAS_DATA_REPO}" ] || [ ! -d "${ATLAS_DATA_REPO}" ]; then
  echo "ATLAS_DATA_REPO not set" >&2
  exit 1
fi

# Get latest local run_id (by mtime)
OUT_ATLAS="${ATLAS_ROOT}/out/atlas"
LATEST_LOCAL=""
LATEST_MTIME=0
for d in "${OUT_ATLAS}"/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  [[ "$name" == DELIVERY_RAW_STDOUT ]] && continue
  [ -f "${d}result.json" ] || continue
  mtime=$(stat -f %m "$d" 2>/dev/null || stat -c %Y "$d" 2>/dev/null || echo 0)
  if [ "${mtime}" -gt "${LATEST_MTIME}" ]; then
    LATEST_MTIME=$mtime
    LATEST_LOCAL=$name
  fi
done

[ -z "$LATEST_LOCAL" ] && exit 0

# Check if already in atlas-data index
INDEX_FILE="${ATLAS_DATA_REPO}/out/atlas/index.json"
if [ -f "${INDEX_FILE}" ] && grep -q "\"${LATEST_LOCAL}\"" "${INDEX_FILE}" 2>/dev/null; then
  exit 0
fi
# Also check latest.json
LATEST_FILE="${ATLAS_DATA_REPO}/out/atlas/latest.json"
if [ -f "${LATEST_FILE}" ] && grep -q "\"${LATEST_LOCAL}\"" "${LATEST_FILE}" 2>/dev/null; then
  exit 0
fi

# Publish
exec bash "$(dirname "${BASH_SOURCE[0]}")/atlas-publish-latest.sh"
