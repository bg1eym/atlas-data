# Rollback — PCK-ATLAS-003

## Fault Mode (本次故障)

- **spawn pnpm ENOENT** — launchd 环境 PATH 贫瘠，子进程找不到 pnpm
- 证据：/atlas debug 显示 ATLAS_* 三项 present，但 /atlas today 报 spawn pnpm ENOENT

## Fix Strategy

- pnpm 解析契约化：PNPM_BIN env → 固定候选路径
- spawn 使用绝对路径 pnpm，不依赖 PATH
- 失败时错误包含 pnpm_bin_used, env_path, atlas_root, hint: set PNPM_BIN

## Restore to PCK-ATLAS-002

```bash
git checkout HEAD -- oc-bind/atlas-adapter.ts oc-bind/index.ts
rm -f tools/atlas-pnpm-probe.ts
rm -f .project-control/02-regressions/RG-ATLAS-003-no-radar-strings.sh
rm -f .project-control/02-regressions/RG-ATLAS-003-pnpm-enoent-proof.sh
```

## Scope

- atlas-adapter.ts: resolvePnpmBin(), spawn with absolute pnpm, error metadata
- index.ts: /atlas debug PATH, pnpm_bin, pnpm_probe
- tools/atlas-pnpm-probe.ts: harness for regression
- RG-ATLAS-003-*: no-radar, pnpm-enoent-proof
