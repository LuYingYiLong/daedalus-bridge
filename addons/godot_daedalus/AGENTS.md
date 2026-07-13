# godot_daedalus 前端插件 — AGENTS 指南

## 项目范围

本目录是 Godot Daedalus 的 Godot 编辑器插件前端，负责聊天 UI、会话列表、审批弹窗、Todo/workflow 展示、工具调用渲染、Additional Context、Settings、自定义 MCP 配置、EditorBridge 和状态恢复。

只修改本插件相关文件：`scripts/`、`scenes/`、`assets/`、`tools/`、`plugin.cfg`、`godot_daedalus.gd`。不要修改同级第三方插件目录。

## 目录约定

- `scripts/main.gd`：主 UI、WebSocket/RPC、消息流、队列、审批、EditorBridge、Additional Context。
- `scripts/tool_call_item/`：工具调用、thinking、状态项渲染。
- `scripts/settings_menu/`：设置、归档、自定义 MCP 管理。
- `scenes/`：Godot 场景资源；优先通过场景表达节点结构和信号连接。
- `assets/`：图标、主题、静态资源；已有图标优先通过 UID 引用。
- `tools/`：headless 场景操作等 Godot 端辅助脚本。

## GDScript 规范

- 使用 Godot 4.7 GDScript，严格显式类型；禁止 `:=`。
- 使用 UTF-8 无 BOM、LF 行尾。
- 不 shadow 成员变量；局部变量和形参命名要避开成员作用域。
- 资源加载尽量用 `uid://...`，只有必要时才用 `res://...`。
- 注释用简洁中文，只解释非显而易见的状态机、恢复逻辑或安全边界。
- 保持 Godot 风格：信号、节点路径、场景结构优先在 `.tscn` 中表达，脚本只处理行为。

## UI 与交互规则

- UI 风格贴近 Godot 编辑器：克制、信息密度高、避免营销式大卡片。
- 不覆盖全局主题；优先使用当前 Editor 主题和控件默认样式。
- 按钮优先用已有图标或 Godot/editor 风格图标；陌生图标要有 tooltip。
- 流式回答时必须保持滚动稳定：用户不在底部时不强制滚动，用户在底部时自动跟随。
- assistant 消息应在用户发送后立即出现，耗时从发送时刻开始计算；暂停/审批恢复应复用同一条 assistant 消息。
- 工具调用、thinking、XML loose tool 内容不得裸露成普通 markdown 文本。

## 协议与后端联动

- WebSocket RPC 名称、payload、事件字段必须与后端 `src/protocol` 和 `src/server` 保持一致。
- 新增后端事件或工具状态时，同步补前端本地化、tooltip、错误展示和恢复路径。
- 写入类工具、EditorBridge 写操作和自定义 MCP 工具必须保留审批流程；前端不得绕过后端策略。
- Additional Context 是当前消息上下文；pinned 才跨轮保留，未 pinned 发送后清空。
- 用户提示词、下一步提示、消息引导、归档/删除等功能要能在重启/重连后保持安全、可解释状态。

## Godot EditorBridge 约束

- 读取编辑器上下文可以自动刷新，但用户手动移除的 live context 不应立刻刷新回来。
- 在线场景写入必须使用 `EditorUndoRedoManager`，形成可撤销动作；失败时保留清晰错误。
- 编辑器离线时不要假装成功，前端应允许后端回退到离线 `.tscn`/文本/headless 工具。
- LSP/DAP 诊断状态只作为只读信息展示；不要在前端添加调试控制 UI，除非后端已明确支持并有审批策略。

## 验证命令

```powershell
& "D:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe" --headless --path "D:/GodotProjects/example" --check-only --script "res://addons/godot_daedalus/scripts/main.gd"
& "D:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe" --headless --path "D:/GodotProjects/example" --quit --scene "res://addons/godot_daedalus/scenes/main.tscn"
```

按改动范围补充检查对应脚本和场景，例如 `settings_menu.gd`、`tool_call_item.gd`、`context_popup_menu.gd`、`assistant_markdown_item.tscn`。修改 UI 后尽量加载相关 `.tscn`，防止节点路径、脚本挂载或 UID 失效。

## 禁止事项

- 不手动编辑 `.godot/`、`.import` 和自动生成文件。
- 不提交本机日志、会话、API key、MCP secret、`%USERPROFILE%\.daedalus` 或旧 `%APPDATA%\.godot_daedalus` 内容。
- 不把后端工具 XML、MCP 原始函数名、secret、绝对隐私路径直接渲染给用户。
- 不在前端实现会绕过后端审批、安全策略或工具幂等的快捷路径。
