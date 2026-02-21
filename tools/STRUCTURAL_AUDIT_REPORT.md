# PCK-STRUCT-AUDIT-001: Structural Enforcement Audit Report

**Type:** analysis-only (no functional changes)  
**Date:** 2026-02-20  
**Scope:** PCK v4 — Ledger, Gates, Critical Tests, Iteration Memory, Run Journal

---

## 1. EXECUTION PATH MAP

### Mandatory Scripts (block exit code on failure)

| Script | Invoked By | Blocks On |
|--------|------------|-----------|
| `preflight.sh` | atlas-final-acceptance.sh | Ledger missing, meta.json invalid, base_version ref broken |
| `regress.sh` | atlas-final-acceptance.sh | Any 02-regressions/*.sh exit 1, critical-tests.sh exit 1 |
| `convergence.sh` | atlas-final-acceptance.sh | contract.snapshot.md changed without contract:update in structural_scope |
| `atlas-final-activation-audit.sh` | atlas-final-acceptance.sh | root_cause=UNKNOWN, ATLAS_ROOT invalid |

### Regress Execution Order

1. All `02-regressions/*.sh` in filesystem order
2. `critical-tests.sh` (unless `PCK_SKIP_ACTF=1`)

**Note:** `PCK_SKIP_ACTF=1` skips only the final critical-tests block. `RG-ACTF-001` runs earlier and still invokes `critical-tests.sh`; removal of critical-tests is blocked by RG-ACTF-001.

### Scripts That Can Be Skipped

- `critical-tests.sh` final block: via `PCK_SKIP_ACTF=1` (documented; Run Journal must record)
- Individual regressions: none — all are mandatory in the loop

### What Actually Blocks Exit Code

- `regress.sh`: `set -e` + explicit `exit 1` on any regression failure
- `preflight.sh`: `exit 1` on ledger/meta/base_version failure
- `convergence.sh`: `exit 1` on contract change without scope
- `atlas-final-acceptance.sh`: `FAILED=1` propagates to `exit 1`

---

## 2. ENFORCEMENT TEST (Bypass Attempts)

### Case A: Delete critical-tests.sh → Does regress fail?

**Result:** PASS (blocked)

**Evidence:**

```
=== PROBE: Rename critical-tests.sh ===
Running regress.sh...
RG-001 PASS: Version/identity evidence found in runtime
RG-ACTF-001 FAIL: critical-tests.sh missing
REGRESS FAIL: /Users/qiangguo/atlas-radar/.project-control/02-regressions/RG-ACTF-001-evidence-and-classifier.sh
...
EXIT: non-zero (BLOCKED)
```

**Mechanism:** `RG-ACTF-001-evidence-and-classifier.sh` checks `[ ! -f "${GATES_DIR}/critical-tests.sh" ]` and exits 1 before any ACTF execution.

---

### Case B: Remove failure-classifier.cjs → Does gate fail?

**Result:** PASS (blocked)

**Evidence:**

```
=== PROBE: Rename failure-classifier.cjs ===
Running regress.sh...
RG-ACTF-001 FAIL: /Users/qiangguo/atlas-radar/.project-control/07-critical-tests/failure-classifier.cjs missing
REGRESS FAIL: /Users/qiangguo/atlas-radar/.project-control/02-regressions/RG-ACTF-001-evidence-and-classifier.sh
...
EXIT: non-zero (BLOCKED)
```

**Mechanism:** `RG-ACTF-001` validates presence of `structural-guard.sh`, `execution-sim.sh`, `failure-classifier.cjs`, `test-matrix.json`; missing any causes exit 1.

---

### Case C: Modify contract.snapshot.md → Does convergence fail?

**Result:** PASS (blocked)

**Evidence:**

```
$ echo "MODIFIED" >> .project-control/00-ledger/PCK-CORE-ACTF-001/contract.snapshot.md
$ bash .project-control/04-gates/convergence.sh
CONVERGENCE FAIL: contract.snapshot.md changed but structural_scope does not contain 'contract:update'
Latest: PCK-CORE-ACTF-001
Add 'contract:update' to structural_scope in meta.json if this change is intentional.
$ echo "Case C exit: $?"
Case C exit: 1
```

**Mechanism:** `convergence.sh` diffs latest vs previous `contract.snapshot.md`; if changed and `structural_scope` lacks `contract:update`, exit 1.

---

### Case D: Remove Run Journal → Does preflight block next task?

**Result:** FAIL (bypass possible at preflight level)

**Evidence (preflight):**

```
$ mv .project-control/03-runs/ATLAS-005-*.md /tmp/run-journal.bak
$ bash .project-control/04-gates/preflight.sh
=== Preflight PASS ===
Latest ledger: PCK-CORE-ACTF-001
$ echo "Case D preflight exit: $?"
Case D preflight exit: 0
```

**Evidence (regress — iteration-memory blocks):**

```
$ bash .project-control/04-gates/regress.sh
...
RG-iteration-memory-prior-journal FAIL: iteration-memory gate failed
REGRESS FAIL: /Users/qiangguo/atlas-radar/.project-control/02-regressions/RG-iteration-memory-prior-journal.sh
```

**Conclusion:** Preflight does **not** check Run Journal. Regress (via `RG-iteration-memory-prior-journal` → `iteration-memory.sh`) **does** block when prior Run Journal is missing. Bypass at preflight only; full pipeline blocked by regress.

---

### Case E: Set invalid ATLAS_ROOT → Does acceptance fail?

**Result:** PASS (blocked)

**Evidence:**

```
$ ATLAS_ROOT=/nonexistent bash tools/atlas-final-acceptance.sh
...
=== bash .../atlas-final-activation-audit.sh ===
{"conclusion": {"root_cause": "ROOT_WRONG", "next_fix": "ATLAS_ROOT path does not exist; set to valid atlas-radar root"}}
ACCEPTANCE FAIL
$ echo "Case E acceptance exit: $?"
Case E acceptance exit: 1
```

**Mechanism:** `atlas-final-activation-audit.sh` checks `ATLAS_ROOT`; invalid path yields `root_cause: ROOT_WRONG` and acceptance fails.

**Note:** When `ATLAS_ROOT` is unset, `RG-ATLAS-FINAL-001` may PASS with "may be expected if ATLAS_* unset". Invalid-but-set path is caught by activation audit.

---

## 3. INHERITANCE TEST

### meta.json base_version validation

- **Preflight:** Validates that `base_version` (if non-null) references an existing ledger directory. Enforced.
- **Iteration-memory:** Uses `base_version` to locate prior Run Journal (`${RUNS}/${BASE_SUFFIX}-*.md`). Enforced.

### Previous Run Journal content read by code

- **iteration-memory.sh:** Checks existence and non-empty (`[ ! -s "${PRIOR_JOURNAL}" ]`). Does **not** parse content.
- **No other code** reads Run Journal content for structural enforcement.

### Iteration memory: executable or documentary?

**Executable.** `iteration-memory.sh` is invoked by `RG-iteration-memory-prior-journal.sh` within regress. It exits 1 when prior Run Journal is missing or empty. The gate is enforced at runtime.

---

## 4. STRUCTURAL WEAK POINTS

| Weak Point | Type | Detail |
|------------|------|--------|
| Preflight ignores Run Journal | Soft | Preflight passes without Run Journal; only regress (iteration-memory) blocks |
| Run Journal content not validated | Documentary | Only presence/size checked; semantic content not enforced |
| PCK_SKIP_ACTF=1 | Soft | Skips final critical-tests block; RG-ACTF-001 still runs critical-tests, so removal is blocked |
| ATLAS_ROOT unset | Soft | RG-ATLAS-FINAL-001 can PASS when unset; activation audit catches invalid path |
| Ledger sort order variance | Assumption | `preflight` uses `sort -V` tail; `iteration-memory` prefers `PCK-ATLAS-*`; different "latest" possible |

---

## 5. STRUCTURAL STRENGTH SCORE (0–100)

**Score: 72**

### Breakdown

| Criterion | Weight | Score | Notes |
|-----------|--------|-------|-------|
| Mandatory enforcement | 25% | 85 | Regress, convergence, activation audit block; preflight has gaps |
| Non-bypassability | 25% | 70 | Case D preflight bypass; PCK_SKIP_ACTF soft skip |
| Memory–execution coupling | 25% | 65 | Iteration memory executable; Run Journal content not parsed |
| Gate integrity | 25% | 68 | ACTF and convergence strong; preflight incomplete |

### Rationale

- **Strengths:** critical-tests, failure-classifier, convergence, and iteration-memory are enforced. Bypass attempts A, B, C, E are blocked.
- **Weaknesses:** Preflight does not enforce Run Journal; Run Journal content is documentary; `PCK_SKIP_ACTF` allows a documented soft skip.

---

## 6. RAW TERMINAL OUTPUTS (Probe Script)

```
=== PROBE: Rename critical-tests.sh ===
Running regress.sh...
RG-001 PASS: Version/identity evidence found in runtime
RG-ACTF-001 FAIL: critical-tests.sh missing
REGRESS FAIL: /Users/qiangguo/atlas-radar/.project-control/02-regressions/RG-ACTF-001-evidence-and-classifier.sh
...
EXIT: non-zero (BLOCKED)

=== PROBE: Rename failure-classifier.cjs ===
Running regress.sh...
RG-ACTF-001 FAIL: /Users/qiangguo/atlas-radar/.project-control/07-critical-tests/failure-classifier.cjs missing
REGRESS FAIL: /Users/qiangguo/atlas-radar/.project-control/02-regressions/RG-ACTF-001-evidence-and-classifier.sh
...
EXIT: non-zero (BLOCKED)

=== PROBE COMPLETE ===
```
