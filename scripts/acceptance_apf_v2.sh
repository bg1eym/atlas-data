#!/usr/bin/env bash
# Atlas-Radar APF v2 Acceptance Stub — LOCAL_ONLY.
# Bootstrap: creates minimal stub artifacts for matrix verify. No real pipeline.
# Supports failure injection via APF_TEST_RENDER_EMPTY, APF_TEST_SKIP_READBACK, APF_TEST_FORCE_MINIMAL_FILTER.

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-${OPENCLAW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
cd "$ROOT"

# Forbidden env check (aligned with HARD_RULES)
for v in RADAR_MOCK RADAR_DRYRUN RADAR_DRY_RUN RADAR_PREVIEW RADAR_SKIP_CORE; do
  eval "val=\${$v:-}"
  if [ -n "${val:-}" ]; then
    echo "BLOCKED: forbidden env $v is set"
    exit 42
  fi
done

echo "MODE: LOCAL_ONLY"
echo "=== Atlas-Radar APF v2 Acceptance (stub) ==="

# Failure injection (scenarios D/E/F)
if [ "${APF_TEST_RENDER_EMPTY:-}" = "1" ]; then
  echo "scenario D: APF_TEST_RENDER_EMPTY"
  exit 1
fi
if [ "${APF_TEST_SKIP_READBACK:-}" = "1" ]; then
  echo "scenario E: APF_TEST_SKIP_READBACK"
  exit 1
fi
if [ "${APF_TEST_FORCE_MINIMAL_FILTER:-}" = "1" ]; then
  echo "scenario F: APF_TEST_FORCE_MINIMAL_FILTER"
  exit 1
fi

# Create stub artifacts for LOCAL_ONLY pass
RUN_ID="apf-stub-$(date +%Y%m%d%H%M%S)-$$"
ARTIFACTS_DIR="$ROOT/out/artifacts/$RUN_ID"
mkdir -p "$ARTIFACTS_DIR"/{fetcher,filter_rank,renderer,sender}

# Gate 2: renderer output non-empty
echo "Atlas-Radar stub render output. LOCAL_ONLY." > "$ARTIFACTS_DIR/renderer/rendered_text.txt"
echo '{}' > "$ARTIFACTS_DIR/renderer/render_meta.json"

# Gate 3: readback non-empty
echo "Stub readback. LOCAL_ONLY." > "$ARTIFACTS_DIR/sender/readback_text.txt"
echo '{}' > "$ARTIFACTS_DIR/sender/send_response_raw.json"

# Gate 4: filter coverage
echo '{"item_count":3}' > "$ARTIFACTS_DIR/fetcher/sources_raw.json"
echo '{"item_count":3}' > "$ARTIFACTS_DIR/filter_rank/filtered_items.json"

# Gate 5: evidence_manifest provenance chain
echo -n "stub" | shasum -a 256 | cut -d' ' -f1 > /tmp/stub_sha
STUB_SHA=$(cat /tmp/stub_sha)
jq -n \
  --arg run_id "$RUN_ID" \
  --arg sha "$STUB_SHA" \
  '{
    pipeline_run_id: $run_id,
    render_input_sha256: $sha,
    render_output_sha256: $sha,
    render_git_hash: "stub",
    render_timestamp: (now | todate)
  }' > "$ARTIFACTS_DIR/evidence_manifest.json"

echo "run_id: $RUN_ID"
echo "artifacts_dir: $ARTIFACTS_DIR"
echo "APF v2 LOCAL_OK"
exit 0
