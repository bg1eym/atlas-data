# Parity Requirements（开源借鉴要求）

## 前置条件

任何涉及开源借鉴的任务，必须先完成：

- `docs/parity/<upstream>/PARITY_MAP.md`
- `docs/parity/<upstream>/ARCH_NOTES.md`

## PARITY_MAP 必须包含

- **upstream_evidence**：path + symbol（函数/组件/类型名）
- **our_mapping**：我方对应实现路径
- **parity_status**：对齐状态
- **behavior_notes**：行为对照说明

## 禁止抽象描述

不允许只写「学习了设计理念」或「对齐了结构」这种抽象描述。

必须引用具体代码证据：
- 路径（含 `/`）
- symbol（函数名、组件名、类型名）
