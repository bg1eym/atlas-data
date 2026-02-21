# OSS Hard-Learning Cursor Task Template

用于自动生成 Cursor 任务的模板。核心是「证据+验收」，不给实现细节。

## Objective

- [ ] 明确借鉴的 vendor 项目名与路径
- [ ] 明确 Parity 范围（必须列出 files/components）
- [ ] 明确 Delta-only 列表（每条需 not-in-vendor 证明）

## Vendor Parity Scope

必须命名：
- `vendor/<name>/` 下的关键文件路径
- 布局组件：Header, Sidebar, Panels, Cards 等对应路径
- 交互关键点：filter/tab/drill-down 对应实现文件

## Delta-Only List

每条 Delta 必须包含：
- 功能描述
- `Vendor does not have: <evidence>` 证明
- 可测验收项

## Hard Constraints

- 不得无 vendor 证据的 UI 重构
- 不得把 rendered_text 直接放首屏（除非 vendor 首屏就是如此）
- 必须产出 vendor_parity_map.json / delta_spec.md

## Deliverables

- out/oss_learning/vendor_parity_map.json
- out/oss_learning/ui_parity_checklist.md
- out/oss_learning/delta_spec.md

## Automated Acceptance Scripts

- scripts/oss/90_acceptance_contract.sh
- 检查 required_artifacts 存在
- 检查 parity_dimensions 全部覆盖
- 检查 delta_spec.md 每条含 "Not in vendor"

## Evidence Outputs

- vendor_component_refs（文件路径）
- screenshot_path
- css/token refs
