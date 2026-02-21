# Rollback — PCK-ATLAS-005

## 故障模式 (Fault Mode)

- **iteration-memory gate fail** — prior Run Journal 缺失；任务在未读 evidence 的情况下修改业务逻辑
- **静默偏离** — 行为变化但 contract/ledger 未更新

## 根因 (Root Cause)

- 无强制 gate 要求改前读 evidence、改后写 journal
- 本 ledger 新增 iteration-memory.sh 解决

## 修复策略 (Fix Strategy)

- 每次任务前运行 `bash .project-control/04-gates/iteration-memory.sh`
- 若 prior journal 缺失 → exit 1，禁止继续
- 新增任务必须创建 Run Journal 并写入 mistake-book

## 验证方法 (Verification)

- 运行 iteration-memory.sh；非 BOOTSTRAP 时应有 prior Run Journal
- 检查 03-runs/ 下存在 ATLAS-<N>-*.md

## Restore to PCK-ATLAS-004

```bash
rm -f .project-control/04-gates/iteration-memory.sh
rm -f .project-control/02-regressions/mistake-book.md
rm -rf .project-control/00-ledger/PCK-ATLAS-005
```

## Forbidden Patterns

- 修改业务逻辑前未通过 preflight + regress + convergence + iteration-memory
- 变更后未写 Run Journal
- 关键诊断未写入 mistake-book
- 提出 "assumptions" 当 evidence 已存在

## Scope (PCK-ATLAS-005)

- 04-gates/iteration-memory.sh
- 02-regressions/mistake-book.md
- 00-ledger/PCK-ATLAS-005/*
