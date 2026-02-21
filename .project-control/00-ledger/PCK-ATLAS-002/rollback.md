# Rollback — PCK-ATLAS-002

## Restore to PCK-ATLAS-001

To revert PCK-ATLAS-002 changes:

```bash
# oc-bind: remove build fingerprint, /atlas debug
git checkout HEAD -- oc-bind/index.ts
# atlas-radar: remove audit script, regression
rm -f tools/atlas-activation-audit.sh
rm -f .project-control/02-regressions/RG-ATLAS-002-build-fingerprint-present.sh
```

## Scope

- oc-bind/index.ts: build fingerprint suffix, getBuildFingerprint(), /atlas debug handler
- tools/atlas-activation-audit.sh: new audit script
- RG-ATLAS-002-build-fingerprint-present.sh: new regression
