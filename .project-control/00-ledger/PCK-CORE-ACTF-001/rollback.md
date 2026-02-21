# Rollback — PCK-CORE-ACTF-001

## 本任务新增 (Added by this task)

- `.project-control/06-iteration-memory/` — placeholder (empty)
- `.project-control/07-critical-tests/` — test-matrix.json, structural-guard.sh, execution-sim.sh, failure-classifier.cjs, _exec_sim_probe.py, _exec_sim_write.py, _out/
- `.project-control/04-gates/critical-tests.sh`
- `.project-control/04-gates/regress.sh` — appended critical-tests call
- `.project-control/02-regressions/RG-ACTF-001-evidence-and-classifier.sh`
- `.project-control/00-ledger/PCK-CORE-ACTF-001/`

## Restore (git revert)

```bash
rm -rf .project-control/07-critical-tests
rm -rf .project-control/06-iteration-memory
rm -f .project-control/04-gates/critical-tests.sh
rm -f .project-control/02-regressions/RG-ACTF-001-evidence-and-classifier.sh
rm -rf .project-control/00-ledger/PCK-CORE-ACTF-001
git checkout -- .project-control/04-gates/regress.sh
```

## Forbidden Patterns

- 在 evidence 中输出敏感 env 值（token、key、chat id）
- 使用“可能是…”作为唯一诊断；必须有 machine evidence + failure_mode
- 修改业务逻辑文件（非 .project-control/** 与 tools/**）
