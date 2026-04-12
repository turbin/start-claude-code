# Claude Code 启动脚本

> **用途：** 一键启动 Claude Code，支持会话管理、模型切换和权限透传。
> **适用平台：** Linux / macOS / WSL（Windows Subsystem for Linux）
> **注意：** 本脚本需在已安装 Claude Code 的环境中运行。

## 使用方法

```bash
# 基本用法 — 交互式选择（新建 / 恢复 / 挑选会话）
./start-claude-quick.sh

# 新建会话
./start-claude-quick.sh --new
./start-claude-quick.sh -n

# 恢复上次会话
./start-claude-quick.sh --resume
./start-claude-quick.sh -r

# 透传参数给 claude 命令
./start-claude-quick.sh --model sonnet
./start-claude-quick.sh -c "explain the project structure"
./start-claude-quick.sh --name "refactor auth"
```

## 功能说明

| 功能            | 说明                                                                                             |
| :-------------- | :----------------------------------------------------------------------------------------------- |
| **会话管理**    | 支持新建、恢复最近会话、交互式挑选历史会话               |
| **模型切换**    | 自动读取 `model-env.sh`，设置 `ANTHROPIC_MODEL`、`MAX_THINKING_TOKENS` 等环境变量 |
| **权限透传**    | 自动添加 `--allow-dangerously-skip-permissions` 参数     |
| **参数透传**    | 所有未识别参数原样传递给 `claude` 命令                   |
| **环境变量**    | 自动 `source model-env.sh`，无需手动配置                 |

## 会话选择菜单

当项目中存在历史会话时，脚本会显示选择菜单：

```
  [1] New session (default)
  [2] Resume latest
  [3] Pick session...
```

- 直接按 **Enter**：新建会话
- 按 **2**：恢复最近的会话
- 按 **3**：打开 `claude --resume` 交互式选择器

## 前提条件

```bash
# 1. 安装 Claude Code
npm install -g @anthropic-ai/claude-code

# 2. 给脚本执行权限
chmod +x start-claude-quick.sh
```

## 配置

### 模型环境变量

脚本会自动 `source` 同目录下的 `model-env.sh`，该文件定义：

| 变量                                | 说明                     |
| :---------------------------------- | :----------------------- |
| `ANTHROPIC_MODEL`                   | 模型名称                 |
| `MAX_THINKING_TOKENS`               | 思考预算                 |
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS`    | 上下文窗口大小           |

### 切换模型

```bash
# 1. 使用 cc 切换模型（会更新 settings.json）
cc switch <model>

# 2. 重新启动脚本（自动读取新模型配置）
./start-claude-quick.sh
```

## 项目结构

```
agent-laucher/
├── start-claude-quick.sh   # 启动脚本
├── model-env.sh            # 模型环境变量
└── README.md               # 本文档
```
