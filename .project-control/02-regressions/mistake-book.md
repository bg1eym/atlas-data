# PCK Mistake Book (Cross-Project)

证据化记录失败模式、根因、修复策略与回归。每次迭代必须将新结论写入此处。

---

## Entry 1 — ATLAS-001: Radar 残留，TG help/NL 仍出现 radar

| 字段 | 内容 |
|------|------|
| **Symptom** | TG `/atlas help`、NL 输入仍出现 radar 相关文案；`/radar schedule` 仍路由到 atlas_run |
| **Verified Root Cause** | RUN_KEYWORDS 含 "atlas radar"，需两词同时出现才命中；`/radar` 路由未显式停用 |
| **Evidence Pointers** | `runtime/atlas/tg_nl_router.ts` RUN_KEYWORDS；`tg_nl_handler.ts` /radar 分支；Run Journal: `03-runs/ATLAS-001-20250220.md` |
| **Fix Strategy** | 移除 RUN_KEYWORDS 中 "radar"，仅保留 "atlas"；`/radar` 不执行，返回「Radar 已停用」 |
| **New Regression(s)** | RG-ATLAS-001-no-radar-strings.sh：禁止 radar:run, OPENCLAW_ROOT, /atlas radar, radar_daily |
| **How to detect earlier next time** | 回归脚本 grep 禁止字符串；convergence gate 阻止 contract 静默变更 |

---

## Entry 2 — ATLAS-002: Gate 通过但 TG 行为未变，缺少 build fingerprint

| 字段 | 内容 |
|------|------|
| **Symptom** | preflight/regress/convergence 全通过，但 TG 回复未变；无法确认 gateway 实际加载的代码版本 |
| **Verified Root Cause** | Gateway 可能启动于变更前，或从不同路径加载；无 build fingerprint 无法验证 |
| **Evidence Pointers** | `tools/atlas-activation-audit.sh` 输出；Run Journal: `03-runs/ATLAS-002-20250220.md` |
| **Fix Strategy** | 在 /atlas 回复中加入 build fingerprint：`build: <sha> <ledger> <plugin_basename>`；新增 /atlas debug 返回 fingerprint、plugin_dir、env presence |
| **New Regression(s)** | RG-ATLAS-002-build-fingerprint-present.sh：断言 fingerprint 存在且格式正确 |
| **How to detect earlier next time** | 每次变更后 invoke `/atlas help` 验证 sha 与 git HEAD 一致；若不一致需重启 gateway |

---

## Entry 3 — ATLAS-003: launchd 下 spawn pnpm ENOENT，PATH 贫瘠

| 字段 | 内容 |
|------|------|
| **Symptom** | /atlas debug 显示 env present，但 /atlas today 报 `spawn pnpm ENOENT` |
| **Verified Root Cause** | launchd 环境 PATH 贫瘠（/usr/bin:/bin:/usr/sbin:/sbin），子进程 spawn 时找不到 pnpm |
| **Evidence Pointers** | 错误输出含 `pnpm_bin_used=/opt/homebrew/bin/pnpm`、`env_path=/usr/bin:...`；Run Journal: `03-runs/ATLAS-003-20250220.md` |
| **Fix Strategy** | 不依赖 PATH；使用 PNPM_BIN 或固定候选路径（/opt/homebrew/bin/pnpm 等）；spawn 使用绝对路径 |
| **New Regression(s)** | RG-ATLAS-003-pnpm-enoent-proof.sh（后由 RG-ATLAS-004-shebang-proof 替代） |
| **How to detect earlier next time** | 回归脚本用 `env -i PATH=/usr/bin:/bin:...` 模拟 launchd；若 pnpm 不可用，错误含 "set PNPM_BIN" |

---

## Entry 4 — ATLAS-004: shebang 解析失败，需 node 直接执行 pnpm.cjs

| 字段 | 内容 |
|------|------|
| **Symptom** | PNPM_BIN 指向 pnpm 可执行文件，launchd 下仍 `spawn pnpm ENOENT` |
| **Verified Root Cause** | shebang `#!/usr/bin/env node` 在 launchd 下解释器解析失败；需 `node pnpm.cjs` 直接执行 |
| **Evidence Pointers** | 错误输出：`pnpm_bin_used=/opt/homebrew/bin/pnpm`；Run Journal: `03-runs/ATLAS-004-20250220.md` |
| **Fix Strategy** | 使用 NODE_BIN + PNPM_JS；spawn(nodeBin, [pnpmJs, "-C", root, "run", "atlas:run"])；不依赖 shebang |
| **New Regression(s)** | RG-ATLAS-004-shebang-proof.sh：probe NODE_BIN+PNPM_JS；spawn node pnpm.cjs -v |
| **How to detect earlier next time** | shebang-proof harness：`env -i PATH=... NODE_BIN=... PNPM_JS=... node tools/atlas-node-probe.cjs` |

---

## Entry 5 — PCK-ITERATION-001: 迭代记忆门禁缺失，静默偏离风险

| 字段 | 内容 |
|------|------|
| **Symptom** | 任务在未读取 prior run evidence 的情况下修改业务逻辑；变更后未写回 run 结果；行为变化但 contract/ledger 未更新 |
| **Verified Root Cause** | 无强制 gate 要求：1) 改前读 evidence；2) 改后写 journal；3) 引用 base_version 与 prior run |
| **Evidence Pointers** | 本任务模板；Run Journal: `03-runs/ATLAS-005-20250219.md`（待创建） |
| **Fix Strategy** | 新增 iteration-memory.sh gate：A) 最新 ledger + meta.json；B) 非 BOOTSTRAP 时 prior Run Journal 必须存在；C) base_version 引用正确 |
| **New Regression(s)** | RG-iteration-memory-prior-journal.sh：调用 iteration-memory.sh，确保 prior journal 存在 |
| **How to detect earlier next time** | 每次任务前运行 `bash .project-control/04-gates/iteration-memory.sh`；若 prior journal 缺失 → exit 1 |
