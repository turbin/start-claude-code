# Claude Code 启动脚本

> **用途：** 一键启动 Claude Code，支持会话管理、模型切换和权限透传。
> **适用平台：** Linux / macOS / WSL（Windows Subsystem for Linux）/ Git Bash on Windows
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
| **模型切换**    | 自动读取 `models.json`，设置 `ANTHROPIC_MODEL`、`ANTHROPIC_BASE_URL`、`MAX_THINKING_TOKENS` 等环境变量 |
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

## 安装

```bash
# 克隆后进入目录
cd start-claude-code

# 一键安装到 ~/.local/bin/start-claude-code（默认路径）
./install.sh

# 或指定自定义路径
./install.sh /opt/start-claude-code
```

安装脚本会自动：
1. 复制脚本到目标目录
2. 创建 `.env` 文件（用于存放 API Key）
3. 在 `~/.bashrc` 和 `~/.zshrc` 中添加 `claude-new` / `claude-resume` 别名

安装后执行 `source ~/.bashrc`（或 `source ~/.zshrc`）即可使用别名。

## 前提条件

```bash
# 1. 安装 Claude Code
npm install -g @anthropic-ai/claude-code

# 2. 给脚本执行权限（开发/测试时）
chmod +x start-claude-quick.sh
```

## Windows (Git Bash / cmd.exe / PowerShell)

### Git Bash

将脚本目录加入 `~/.bashrc`，即可在任何位置使用：

```bash
# ~/.bashrc
export PATH="/d/workspace/newland-workspace/start-claude-code:$PATH"
alias claude-start="start-claude-quick.sh"
alias claude-resume="start-claude-quick.sh --resume"
alias claude-new="start-claude-quick.sh --new"
```

然后 `source ~/.bashrc`，之后可在任意目录使用 `claude-start`、`claude-resume` 等命令。

### cmd.exe / PowerShell

使用 `start-claude-quick.bat`，它会自动查找 Git Bash 并回退到 WSL：

```cmd
:: 需要已安装 Git for Windows，或使用 start-claude-quick.bat 所在目录
start-claude-quick.bat
start-claude-quick.bat --resume
```

## 配置

### 模型环境变量

脚本会自动 `source` 同目录下的 `model-env.sh`，该文件读取 `models.json` 并导出以下变量：

| 变量                                | 说明                     |
| :---------------------------------- | :----------------------- |
| `ANTHROPIC_MODEL`                   | 模型名称 / ID            |
| `ANTHROPIC_BASE_URL`                | Anthropic 兼容 Base URL  |
| `ANTHROPIC_AUTH_TOKEN`              | API Key（自动从对应 env var 读取） |
| `MAX_THINKING_TOKENS`               | 思考预算                 |
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS`    | 上下文窗口大小           |

### API Key 配置

脚本会自动加载同目录下的 `.env` 文件（已加入 `.gitignore`，不会被提交到 Git）。推荐把 Key 写在这里：

```bash
# 编辑项目目录下的 .env
QWEN_CODING_API_KEY="sk-sp-..."
MOONSHOT_API_KEY="sk-..."
```

启动时 `model-env.sh` 会自动 `source` 该文件，无需手动 `export`。

如果你更喜欢手动导出，也可以在 shell 中设置：

```bash
export QWEN_CODING_API_KEY="sk-sp-..."
export MOONSHOT_API_KEY="sk-..."
```

启动脚本会根据 `models.json` 中的 `api_key_env` 字段，自动将对应的 Key 注入到 `ANTHROPIC_AUTH_TOKEN`。

### models.json 配置

模型列表保存在同目录的 `models.json` 中，结构如下：

```json
{
  "default_model": "qwen3.6-plus",
  "models": {
    "qwen3.6-plus": {
      "id": "qwen3.6-plus",
      "base_url": "https://coding.dashscope.aliyuncs.com/apps/anthropic",
      "api_key_env": "QWEN_CODING_API_KEY",
      "context_tokens": 1000000,
      "max_thinking_tokens": 31999,
      "flags": "cache"
    }
  }
}
```

- `default_model` — 当 `settings.json` 未指定模型时的默认回退
- `id` — 发送到 API 的模型标识符
- `base_url` — Anthropic 兼容端点
- `api_key_env` — 存放 API Key 的环境变量名
- `context_tokens` / `max_thinking_tokens` / `flags` — 模型能力参数

**修改模型列表：** 直接编辑 `models.json`，无需改动脚本，保存后即刻生效。

### 切换模型

```bash
# 1. 使用 cc 切换模型（会更新 settings.json）
cc switch <model>

# 2. 重新启动脚本（自动读取新模型配置）
./start-claude-quick.sh
```

## 项目结构

```
start-claude-code/
├── install.sh              # 安装脚本
├── start-claude-quick.sh   # 启动脚本（Linux / macOS / Git Bash）
├── start-claude-quick.bat  # Windows 批处理包装器
├── model-env.sh            # 模型环境变量（读取 models.json）
├── models.json             # 模型列表与配置
├── .env                    # API Key 配置（gitignore，安装后生成）
├── .gitignore              # Git 忽略规则
└── README.md               # 本文档
```
