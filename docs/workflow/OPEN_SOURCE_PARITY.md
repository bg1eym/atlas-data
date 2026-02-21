# 开源借鉴模板原则 (Open-Source Parity Principle)

## 目标

任何「借鉴开源项目」的工作，必须自动遵循 **Design/Interaction Parity**：学习到代码与设计细节级别；只做对方没有的新需求；形成可验收的工程约束。

## Parity 范围（必须对齐）

| 维度 | 说明 | 验收方式 |
|-----|------|---------|
| **布局 (layout)** | 首屏结构、网格、列数、间距 | 截图对比 |
| **组件 (component)** | 形状、边框、圆角、阴影 | 代码级对照 |
| **信息架构 (information architecture)** | 面板层级、导航模型 | 结构对照 |
| **交互 (interaction)** | 点击、筛选、分页、drill-down | 行为对照 |
| **密度 (density)** | 字号、行距、padding、truncation | 视觉对照 |
| **动效 (animation)** | 过渡、loading、hover | 可选 |
| **主题变量 (theme)** | CSS 变量、颜色、对比度 | 变量对照 |
| **快捷键 (shortcuts)** | 若有 | 可选 |

## 禁止「自由发挥」

- **任何偏离** vendor 的设计/交互，必须：
  1. 在 `out/parity_map.json` 的 `deltas` 中写明
  2. 附 `RATIONALE`：为何必须偏离
  3. 附截图对比：vendor vs ours

- 未在 `deltas` 中声明的偏离，视为违反原则。

## 学习到「代码级」

必须维护 **vendor 组件 ↔ 我们实现** 的映射表：

- 文件：`out/parity_map.json`
- 结构：见下方 Schema
- 每个映射必须标注 `parity_items`：对齐了哪些维度
- `deltas` 仅允许写「新增需求」相关差异（如：中文摘要、TG 封面卡、栏目化）

## Schema: out/parity_map.json

```json
{
  "version": "1.0",
  "vendor_root": "vendor/situation-monitor",
  "mappings": [
    {
      "vendor_component_path": "vendor/situation-monitor/src/lib/components/common/Panel.svelte",
      "our_component_path": "ui/atlas-viewer/src/Dashboard/Panel.svelte",
      "parity_items": ["layout", "typography", "density", "interaction", "state_model"],
      "deltas": []
    }
  ]
}
```

## 验收

- `bash scripts/parity_guard.sh` 必须 exit 0（当 vendor 存在时）
- vendor 存在但 `out/parity_map.json` 缺失或无效 => exit 13，报错可读
