#!/usr/bin/env bash
# ACTF Execution Simulator — Simulate launchd/sparse PATH execution.
# Input: env (ACTF_SIM_PATH, ACTF_NODE_BIN, ACTF_CMD). Output: execution-evidence.json

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ACTF_DIR="${ROOT}/.project-control/07-critical-tests"
OUT_DIR="${ACTF_DIR}/_out"
OUT_FILE="${OUT_DIR}/execution-evidence.json"

SIM_PATH="${ACTF_SIM_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"
ACTF_CMD="${ACTF_CMD:-}"
N=4000

mkdir -p "${OUT_DIR}"

# If ACTF_CMD empty: probe only, still produce evidence
if [ -z "${ACTF_CMD}" ]; then
  python3 "${ACTF_DIR}/_exec_sim_probe.py" "${OUT_FILE}" "${SIM_PATH}" 2>/dev/null || {
    echo '{"timestamp":"","host_os":"probe_only","exit_code":null,"stdout_truncated":"","stderr_truncated":"","cmd":"","sim_path":"'"${SIM_PATH}"'"}' > "${OUT_FILE}"
    cat "${OUT_FILE}"
  }
  exit 0
fi

# Run with env -i PATH=$SIM_PATH
TMPOUT=$(mktemp)
TMPERR=$(mktemp)
trap "rm -f ${TMPOUT} ${TMPERR}" EXIT

set +e
env -i "PATH=${SIM_PATH}" sh -c "${ACTF_CMD}" 1> "${TMPOUT}" 2> "${TMPERR}"
EXIT_CODE=$?
set -e

python3 "${ACTF_DIR}/_exec_sim_write.py" "${OUT_FILE}" "${TMPOUT}" "${TMPERR}" "${EXIT_CODE}" "${ACTF_CMD}" "${SIM_PATH}" "$(uname -s)" "${N}" 2>/dev/null || {
  echo "{\"exit_code\":${EXIT_CODE},\"cmd\":\"${ACTF_CMD}\"}" > "${OUT_FILE}"
  cat "${OUT_FILE}"
}

if [ ${EXIT_CODE} -ne 0 ]; then
  exit 3
fi
exit 0
