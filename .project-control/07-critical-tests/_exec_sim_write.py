#!/usr/bin/env python3
"""Write execution evidence from captured stdout/stderr"""
import json
import sys
from datetime import datetime

out_file = sys.argv[1]
tmpout = sys.argv[2]
tmperr = sys.argv[3]
exit_code = int(sys.argv[4])
cmd = sys.argv[5] if len(sys.argv) > 5 else ""
sim_path = sys.argv[6] if len(sys.argv) > 6 else ""
host_os = sys.argv[7] if len(sys.argv) > 7 else "unknown"
n = int(sys.argv[8]) if len(sys.argv) > 8 else 4000

stdout = ""
stderr = ""
try:
    with open(tmpout) as f:
        stdout = f.read()[:n]
except Exception:
    pass
try:
    with open(tmperr) as f:
        stderr = f.read()[:n]
except Exception:
    pass

j = {
    "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z"),
    "host_os": host_os,
    "exit_code": exit_code,
    "stdout_truncated": stdout,
    "stderr_truncated": stderr,
    "cmd": cmd,
    "sim_path": sim_path,
}
with open(out_file, "w") as f:
    json.dump(j, f, indent=2)
print(json.dumps(j))
