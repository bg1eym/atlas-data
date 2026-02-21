# Atlas-Radar Next Step Implementation Plan

## Situation-Monitor Classification

**Decision: module-reference** (NOT skill-wrapper)

- **Evidence**: See `out/vendor_review/situation-monitor_assessment.json`
- **Rationale**: situation-monitor is a frontend-only dashboard (Svelte/Vite/D3). It does NOT implement crawling, RSS ingestion, or data pipeline. It displays pre-aggregated data. No TRUSTED_SOURCES entry, license undetected, install hooks unknown.

## What Will Be Copied (from situation-monitor)

- D3 + TopoJSON world map rendering patterns (if map display desired)
- Tailwind-based styling approach
- UI layout patterns for dashboard visualization

## What Will Become In-Repo Skills

- **atlas-fetch**: Already created as stub. Full implementation will:
  - Read `runtime/atlas/config/sources.json`
  - Fetch from configured AI news/KOL/official URLs
  - Output `sources_raw.json` with provenance sha256 chain
  - Record coverage metrics (must cover configured sources or explicitly record reasons)

## Invariants That Will Gate Implementation

1. **TG_E2E reality-binding**: Send + readback required for PASS. No claim without real TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID.
2. **AI-only feed**: No non-AI geopolitics or placeholder sources (Example, example.com forbidden).
3. **Provenance sha256 chain**: pipeline_output_sha256, render_input_sha256, rendered_text_sha256 required.
4. **Coverage metrics**: Must cover all configured sources or explicitly record reasons.
5. **BUSINESS_OBJECTIVE**: Complete feed, not minimal gate-satisfying output.

## Skills Framework Gates (Non-Negotiable)

- TRUSTED_SOURCES allowlist
- pinned_revision
- license_detected
- install_hooks_scan
- risk→review_level mapping (shell_exec≥L1, external_network≥L2)
- network_domains required for external_network

## Do NOT

- Install hipcityreg/situation-monitor as a skill
- Add situation-monitor to TRUSTED_SOURCES without license verification
- Claim TG E2E PASS without real credentials
