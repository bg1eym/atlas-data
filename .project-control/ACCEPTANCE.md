# PCK Phase 1 — Manual Acceptance Test

This document proves the gates work by following these steps.

## Step 1: Run preflight

```bash
cd /path/to/atlas-radar
bash .project-control/04-gates/preflight.sh
```

**Expected:** `=== Preflight PASS ===` and exit 0.

---

## Step 2: Run regress

```bash
bash .project-control/04-gates/regress.sh
```

**Expected:** `=== Regress PASS ===` (or `RG-001 PASS`) and exit 0.

---

## Step 3: Create second ledger version and modify contract

To test convergence, we need two versions. Copy the bootstrap and modify the new one:

```bash
cp -r .project-control/00-ledger/PCK-BOOTSTRAP-000 .project-control/00-ledger/PCK-BOOTSTRAP-001
# Update task_id in meta.json for the new version
echo "\n## Test change" >> .project-control/00-ledger/PCK-BOOTSTRAP-001/contract.snapshot.md
```

(Or use `sed -i '' 's/PCK-BOOTSTRAP-000/PCK-BOOTSTRAP-001/' .project-control/00-ledger/PCK-BOOTSTRAP-001/meta.json` to fix task_id.)

---

## Step 4: Run convergence.sh

```bash
bash .project-control/04-gates/convergence.sh
```

**Expected:** `CONVERGENCE FAIL` and exit 1, because contract changed (001 vs 000) but `structural_scope` does not contain `contract:update`.

---

## Step 5: Confirm it blocks

The convergence gate must block when:
- `contract.snapshot.md` has changed (diff from previous version)
- AND `structural_scope` in `meta.json` does NOT include `"contract:update"`

To allow the change, you would add `"contract:update"` to `structural_scope` in the ledger version's `meta.json`.

---

## Revert the test change

```bash
rm -rf .project-control/00-ledger/PCK-BOOTSTRAP-001
git checkout -- .project-control/00-ledger/PCK-BOOTSTRAP-000/contract.snapshot.md
```

---

## ACTF (PCK v4) — Manual Acceptance

### 1) Preflight

```bash
bash .project-control/04-gates/preflight.sh
```

**Expected:** `=== Preflight PASS ===`

### 2) Regress (incl. ACTF)

```bash
bash .project-control/04-gates/regress.sh
```

**Expected:** `=== Regress PASS ===` 且出现 `=== ACTF PASS ===` 或 `=== ACTF FAIL ===`

### 3) 无 ACTF_CMD 时

```bash
bash .project-control/04-gates/critical-tests.sh
cat .project-control/07-critical-tests/_out/classification.json
```

**Expected:** `classification.json` 存在且包含 `failure_mode` 字段（可为 OK 或 UNKNOWN）

### 4) 故意失败测试

```bash
ACTF_CMD="nonexistent_bin --version" bash .project-control/04-gates/critical-tests.sh
```

**Expected:** `=== ACTF FAIL ===`，`failure_mode` 为 `BINARY_NOT_FOUND` 或 `SPAWN_ENOENT`
