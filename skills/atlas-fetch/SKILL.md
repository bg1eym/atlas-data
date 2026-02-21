---
name: atlas-fetch
description: Fetch AI news and KOL/official feeds from configured sources. Multi-adapter (RSS, HTML, GitHub). Declares external_network, network_domains.
review_level: L2
---

# Atlas-Fetch

## Capabilities

- **web.fetch**: HTTP fetch from configured AI news sources
- **external_network**: Required for API/RSS access
- **network_domains**: openai.com, anthropic.com, deepmind.google, github.com (explicit, non-empty)

## Adapters

1. **RSS/Atom**: Official blogs, research orgs, media RSS
2. **HTML Feed**: Pages without RSS (domain allowlist required)
3. **GitHub Releases**: GitHub releases.atom

## Required Environment

- None. Reads `runtime/atlas/config/sources.json`.

## Risk Flags

- external_network: true
- network_domains: ["openai.com", "anthropic.com", "deepmind.google", "github.com"]

## Output

- sources_raw.json
- items_normalized.json
- provenance.json (sha256 chain)

## Invariants

- Coverage: each configured source must appear in provenance with fetch result or reason
- No placeholder output
- Provenance sha256 chain preserved
