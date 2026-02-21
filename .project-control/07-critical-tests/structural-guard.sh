#!/usr/bin/env bash
# ACTF Structural Guard — Evidence-based structural checks.
# Input: env vars only. Output: structural-evidence.json

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ACTF_DIR="${ROOT}/.project-control/07-critical-tests"
OUT_DIR="${ACTF_DIR}/_out"
OUT_FILE="${OUT_DIR}/structural-evidence.json"

mkdir -p "${OUT_DIR}"
export ACTF_OUT_FILE="${OUT_FILE}"
export ACTF_ROOT_FOR_GUARD="${ROOT}"

python3 << 'PYEOF'
import json
import os
from datetime import datetime

root = os.environ.get("ACTF_ROOT_FOR_GUARD", os.environ.get("PCK_ROOT", os.getcwd()))
out_file = os.environ.get("ACTF_OUT_FILE", "")
required_keys_str = os.environ.get("ACTF_REQUIRED_ENV_KEYS", "")
root_dir = os.environ.get("ACTF_ROOT_DIR") or root
pwd_val = os.getcwd()
host_os = os.uname().sysname if hasattr(os, "uname") else "unknown"

# Env summary: present/missing only
env_summary = {}
if required_keys_str:
    for k in required_keys_str.split(","):
        k = k.strip()
        if k:
            env_summary[k] = "present" if os.environ.get(k) else "missing"

env_ok = True
if required_keys_str:
    for k in required_keys_str.split(","):
        k = k.strip()
        if k and not os.environ.get(k):
            env_ok = False
            break

root_ok = True
root_details = "exists,is_dir"
if root_dir:
    if os.path.isdir(root_dir):
        pass
    else:
        root_ok = False
        root_details = "missing_or_not_dir"
else:
    root_details = "not_configured"

pkg_ok = os.path.isfile(os.path.join(root_dir, "package.json"))
pkg_details = "exists" if pkg_ok else "missing"

cwd_ok = os.path.isdir(pwd_val) and os.access(pwd_val, os.R_OK)
cwd_details = "readable" if cwd_ok else "not_readable_or_missing"

required_fail = (required_keys_str and not env_ok) or not root_ok or not cwd_ok

j = {
    "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z"),
    "host_os": host_os,
    "pwd": pwd_val,
    "env_summary": env_summary,
    "checks": {
        "env_presence": {"ok": env_ok, "details": "required_keys_check"},
        "root_path": {"ok": root_ok, "details": root_details},
        "key_files": {"ok": pkg_ok, "details": pkg_details},
        "cwd_access": {"ok": cwd_ok, "details": cwd_details},
    },
    "required_fail": required_fail,
}
if not out_file:
    out_file = os.path.join(root, ".project-control/07-critical-tests/_out/structural-evidence.json")
with open(out_file, "w") as f:
    json.dump(j, f, indent=2)
print(json.dumps(j))
PYEOF

if grep -q '"required_fail":\s*true' "${OUT_FILE}" 2>/dev/null; then
  exit 2
fi
exit 0
