# Rollback — PCK-ATLAS-FINAL-001

## 故障模式

- ROOT 指向不存在: ATLAS_ROOT 路径无效 → 直接返回 ROOT_MISSING
- spawn ENOENT (node/pnpm shebang): fs.access(X_OK) 检测 node；node + pnpm.cjs 绕过 shebang
- launchd env 未应用/贫瘠 PATH: NODE_BIN/PNPM_JS 显式 env；execution-sim 用 env -i 复现

## Forbidden Patterns

- 引入 radar 字符串/逻辑
- 硬编码 example.com
- debug/evidence 输出敏感值
- 跳过 Iteration Memory
- ACTF SKIP 作为默认

## Restore

```bash
git checkout HEAD -- runtime/atlas/run_atlas.ts
# oc-bind: revert atlas-adapter.ts, index.ts
rm -f tools/atlas-final-activation-audit.sh tools/atlas-final-acceptance.sh
rm -rf .project-control/00-ledger/PCK-ATLAS-FINAL-001
rm -f .project-control/02-regressions/RG-ATLAS-FINAL-001.sh
# Revert .project-control/07-critical-tests/ changes
```
