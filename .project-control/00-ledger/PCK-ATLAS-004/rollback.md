# Rollback — PCK-ATLAS-004

## 故障模式 (Fault Mode)

- **spawn /opt/homebrew/bin/pnpm ENOENT** — 即使使用绝对路径 pnpm，launchd 下仍报 ENOENT

## 根因 (Root Cause)

- shebang `#!/usr/bin/env node` 在 launchd 环境下解释器解析失败
- 子进程无法正确解析 pnpm 的 shebang 行

## 修复策略 (Fix Strategy)

- **spawn(node, [pnpm.cjs, ...])** — 用 node 直接执行 pnpm.cjs，绕过 shebang
- 不再 spawn pnpm 可执行文件

## 验证方法 (Verification)

- env -i 模拟 launchd 贫瘠 PATH
- TG 执行 /atlas debug、/atlas today

## Restore to PCK-ATLAS-003

```bash
git checkout HEAD -- oc-bind/atlas-adapter.ts oc-bind/index.ts
rm -f oc-personal-agent-lab/tools/atlas-node-probe.cjs oc-personal-agent-lab/tools/atlas-node-spawn-test.cjs
rm -f .project-control/02-regressions/RG-ATLAS-004-*.sh
```

## Scope

- atlas-adapter.ts: resolveNodeBin(), resolvePnpmJs(), spawn(nodeBin, [pnpmJs, ...])
- index.ts: /atlas debug node_bin, pnpm_js, node_probe, pnpm_js_probe
- tools/atlas-node-probe.js, atlas-node-spawn-test.js
- RG-ATLAS-004-no-radar-strings.sh, RG-ATLAS-004-shebang-proof.sh
