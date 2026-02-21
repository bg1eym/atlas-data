ENV_POLICY_VERSION = 2

---

[ENV_POLICY v2] Open-Source Learning Contract（强制指定学习对象 + 证据）

当任务涉及"借鉴/对齐/硬学习/Parity"时，必须在任务中显式指定 upstream：

必须提供：
- upstream_name：明确的项目名（例如 situation-monitor）
- upstream_locator：至少一个可定位入口（优先本地 vendor 路径；可选 repo URL）
  - 例：vendor/situation-monitor/（必须存在）
- evidence_rule：所有关键结论必须引用 upstream 代码证据（path + symbol），不接受概念描述

门禁：
- 若任务没有 upstream_name + upstream_locator：直接 FAIL（不进入实现）
- 若 PARITY_MAP 缺少 upstream 证据（path+symbol）：直接 FAIL
- Input Pack extraction 为强制步骤：必须从 `RADAR_INPUT_PACK_PATHS`（pdf/txt/md/yaml/json）或默认 PDF 输入中提取，产出 `out/radar_sources/extracted_sources.json`
- 禁止 silent fallback：当输入缺失/解析失败时，默认 `BLOCKED(42)` 并写入 `audit/summary.json`；仅在 `PDF_EXTRACT_ALLOW_FALLBACK=1` 时允许 fallback

---
