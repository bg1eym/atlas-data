#!/usr/bin/env bash
# Atlas Result Guard — Verify result.json from atlas:run.
# Reads ATLAS_ROOT/out/atlas/<latest>/result.json.
# Output: _out/atlas-result-evidence.json
# items_count==0 && categories_count==0 → exit non-zero

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ACTF_DIR="${ROOT}/.project-control/07-critical-tests"
OUT_DIR="${ACTF_DIR}/_out"
OUT_FILE="${OUT_DIR}/atlas-result-evidence.json"
ATLAS_ROOT="${ATLAS_ROOT:-}"

mkdir -p "${OUT_DIR}"

if [ -z "$ATLAS_ROOT" ] || [ ! -d "$ATLAS_ROOT" ]; then
  export ATLAS_RESULT_OUT="$OUT_FILE"
  python3 -c "
import json, os
j = {'result_path': '', 'run_id': '', 'items_count': 0, 'categories_count': 0, 'ok': False, 'error': 'ATLAS_ROOT missing or not a directory'}
with open(os.environ.get('ATLAS_RESULT_OUT',''), 'w') as f: json.dump(j, f, indent=2)
print(json.dumps(j))
"
  exit 1
fi

ATLAS_OUT="${ATLAS_ROOT}/out/atlas"
LATEST_RESULT=""
LATEST_MTIME=0

if [ -d "$ATLAS_OUT" ]; then
  for dir in "$ATLAS_OUT"/*/; do
    [ -d "$dir" ] || continue
    rp="${dir}result.json"
    if [ -f "$rp" ]; then
      m=$(stat -f %m "$rp" 2>/dev/null || stat -c %Y "$rp" 2>/dev/null || echo 0)
      if [ "$m" -gt "$LATEST_MTIME" ]; then
        LATEST_MTIME=$m
        LATEST_RESULT=$rp
      fi
    fi
  done
fi

if [ -z "$LATEST_RESULT" ] || [ ! -f "$LATEST_RESULT" ]; then
  export ATLAS_RESULT_OUT="$OUT_FILE"
  python3 -c "
import json, os
j = {'result_path': '', 'run_id': '', 'items_count': 0, 'categories_count': 0, 'ok': False, 'error': 'EVIDENCE_MISSING'}
with open(os.environ.get('ATLAS_RESULT_OUT',''), 'w') as f: json.dump(j, f, indent=2)
print(json.dumps(j))
"
  exit 1
fi

export ATLAS_RESULT_OUT="$OUT_FILE"
export ATLAS_RESULT_PATH="$LATEST_RESULT"
python3 -c "
import json, os
path = os.environ.get('ATLAS_RESULT_PATH','')
with open(path) as f:
    c = json.load(f)
run_id = c.get('run_id', '')
items = c.get('item_count', 0)
cats = c.get('categories_count', 0)
ok = items > 0 or cats > 0
j = {
  'result_path': path,
  'run_id': run_id,
  'items_count': items,
  'categories_count': cats,
  'ok': ok,
  'error': 'ATLAS_EMPTY' if not ok else ''
}
with open(os.environ.get('ATLAS_RESULT_OUT',''), 'w') as f:
    json.dump(j, f, indent=2)
print(json.dumps(j))
"

# Exit non-zero if empty
ITEMS=$(python3 -c "import json; print(json.load(open('$OUT_FILE')).get('items_count',0))")
CATS=$(python3 -c "import json; print(json.load(open('$OUT_FILE')).get('categories_count',0))")
if [ "${ITEMS:-0}" -eq 0 ] && [ "${CATS:-0}" -eq 0 ]; then
  exit 1
fi
exit 0
