#!/usr/bin/env python3
"""Probe-only mode: write minimal execution-evidence.json"""
import json
import sys
from datetime import datetime

out_file = sys.argv[1] if len(sys.argv) > 1 else "-"
sim_path = sys.argv[2] if len(sys.argv) > 2 else "/usr/bin:/bin:/usr/sbin:/sbin"

j = {
    "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z"),
    "host_os": "probe_only",
    "exit_code": None,
    "stdout_truncated": "",
    "stderr_truncated": "",
    "cmd": "",
    "sim_path": sim_path,
}
with open(out_file, "w") as f:
    json.dump(j, f, indent=2)
print(json.dumps(j))
