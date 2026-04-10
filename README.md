Claude Code + Ralph + Superpowers + Multi-Agent 启动脚本

> **用途：** 一键启动 Claude Code + Ralph Loop + Superpowers + Multi-Agent 工作流**适用平台：** Linux / macOS / WSL（Windows Subsystem for Linux）**注意：** 本脚本需在装有 Claude Code 和 Ralph 的环境中运行

## 使用方法

```Bash
# 基本用法（完整模式）
bash start-claude-code-ralph.sh /path/to/project "my-project"

# 快速模式（仅 Superpowers，不启动 Ralph Loop）
bash start-claude-code-ralph.sh /path/to/project "my-project" quick

# Ralph 监控模式
bash start-claude-code-ralph.sh /path/to/project "my-project" monitor
```

## 脚本内容

```Bash
#!/bin/bash
#===========================================================================
# Claude Code + Ralph + Superpowers + Multi-Agent 启动脚本
#===========================================================================

set -e

#---------------------------- 配置区 ------------------------------------
PROJECT_DIR="${1:-.}"  # 项目目录，默认当前目录
RALPH_PROJECT_NAME="${2:-my-project}"  # Ralph 项目名
MODE="${3:-full}"  # full | quick | monitor

# Ralph 配置
RALPH_CALLS_PER_HOUR="${RALPH_CALLS_PER_HOUR:-100}"
RALPH_MAX_ITERATIONS="${RALPH_MAX_ITERATIONS:-100}"

# Superpowers 配置
SUPERPOWERS_PLUGIN="FradSer/dotclaude"

# Multi-Agent 配置
AGENTS_DIR=".claude/agents"
ARCHITECT_PROMPT="你负责需求分析和技术设计。收到任务后输出 design.md 和 acceptance_criteria.md。"
IMPLEMENTER_PROMPT="你负责代码实现。读取 design.md，按设计实现代码。"
REVIEWER_PROMPT="你负责质量审查。对照 acceptance_criteria.md 检查，运行测试，通过则输出 <verified>Fully Vetted.</verified>"
#---------------------------------------------------------------------------

echo "=========================================="
echo " Claude Code + Ralph + Superpowers + Multi-Agent"
echo "=========================================="
echo "项目目录: $PROJECT_DIR"
echo "项目名称: $RALPH_PROJECT_NAME"
echo "启动模式: $MODE"
echo ""

#---------------------------- 步骤 0: 检查依赖 ---------------------------
echo "[1/6] 检查依赖..."

check_command() {
    if ! command -v "$1" &>/dev/null; then
        echo "错误: 缺少 $1"
        exit 1
    fi
}

check_command claude
check_command ralph

#---------------------------- 步骤 1: 安装 Superpowers --------------------
echo "[2/6] 检查 Superpowers 插件..."

PLUGIN_INSTALLED=$(claude plugin list 2>/dev/null | grep -c "superpowers" || true)

if [ "$PLUGIN_INSTALLED" -eq 0 ]; then
    echo "安装 Superpowers 插件..."
    claude plugin marketplace add "$SUPERPOWERS_PLUGIN"
    claude plugin install "superpowers@$SUPERPOWERS_PLUGIN"
    echo "Superpowers 安装完成"
else
    echo "Superpowers 已安装"
fi

#---------------------------- 步骤 2: 创建 Multi-Agent ------------------
echo "[3/6] 创建 Multi-Agent 团队..."

cd "$PROJECT_DIR"

# 创建 agents 目录
mkdir -p "$AGENTS_DIR"

# Architect Agent
cat > "$AGENTS_DIR/architect.md" << 'AGENT_EOF'
# Architect Agent

你负责需求分析和技术设计。

收到任务后：
1. 分析需求，识别核心问题和约束
2. 输出 design.md（架构设计、接口定义、数据流）
3. 输出 acceptance_criteria.md（完成标准）
4. 不要写代码，只做设计和规划

完成设计后，写入 task_context.json，等待 Orchestrator 指令。
AGENT_EOF

# Implementer Agent
cat > "$AGENTS_DIR/implementer.md" << 'AGENT_EOF'
# Implementer Agent

你负责代码实现。

收到任务后：
1. 读取 design.md 和 acceptance_criteria.md
2. 按照设计实现代码
3. 写入完成后通知 Reviewer 审查

每完成一个模块，写入 task_context.json。
AGENT_EOF

# Reviewer Agent
cat > "$AGENTS_DIR/reviewer.md" << 'AGENT_EOF'
# Reviewer Agent

你负责代码质量审查。

收到代码后：
1. 对照 acceptance_criteria.md 检查
2. 运行测试、验证功能
3. 如果有问题 → 通知 Implementer 修复（critic-fixer 循环）
4. 如果通过 → 输出 <verified>Fully Vetted.</verified>

最多循环 5 轮，超过则升级到 Architect。
AGENT_EOF

echo "已创建 $AGENTS_DIR/ : architect.md, implementer.md, reviewer.md"

#---------------------------- 步骤 3: Ralph 项目初始化 -------------------
echo "[4/6] Ralph 项目初始化..."

if [ ! -d ".ralph" ]; then
    echo "初始化 Ralph 项目..."
    ralph-enable --non-interactive --project-name "$RALPH_PROJECT_NAME" 2>/dev/null || \
    ralph-setup "$RALPH_PROJECT_NAME" 2>/dev/null || true
    echo "Ralph 初始化完成"
else
    echo "Ralph 项目已存在"
fi

#---------------------------- 步骤 4: 配置 Ralph --------------------------
echo "[5/6] 配置 Ralph..."

# 写入 .ralphrc
cat > ".ralphrc" << EOF
PROJECT_NAME="$RALPH_PROJECT_NAME"
MAX_CALLS_PER_HOUR=$RALPH_CALLS_PER_HOUR
RALPH_TIMEOUT_MINUTES=15
SESSION_CONTINUITY=true
SESSION_EXPIRY_HOURS=24
CB_NO_PROGRESS_THRESHOLD=3
CB_SAME_ERROR_THRESHOLD=5
EOF

echo "Ralph 配置完成"

#---------------------------- 步骤 5: 启动 --------------------------------
echo "[6/6] 启动 Claude Code..."
echo ""

case "$MODE" in
    full)
        echo "模式: 完整工作流 (Ralph + Superpowers)"
        echo "启动命令: claude"
        echo ""
        echo "启动后执行:"
        echo "  1. /superpowers:brainstorming        # 需求对话"
        echo "  2. /superpowers:writing-plans        # 生成计划"
        echo "  3. /superpowers:executing-plans       # 执行计划 + Ralph Loop"
        echo ""
        claude
        ;;

    quick)
        echo "模式: 快速模式 (仅 Superpowers)"
        echo "启动命令: claude"
        echo ""
        echo "启动后执行:"
        echo "  /superpowers:executing-plans [plan_folder]"
        echo ""
        claude
        ;;

    monitor)
        echo "模式: Ralph 监控模式"
        echo "后台运行: ralph --monitor"
        echo "前台 Claude Code 需另外终端启动"
        echo ""
        ralph --monitor
        ;;
esac
```

## 三种模式说明

| 模式      | 命令       | 用途                                           |
| :-------- | :--------- | :--------------------------------------------- |
| `full`    | 完整工作流 | 大任务：Ralph Loop + Superpowers + Multi-Agent |
| `quick`   | 快速模式   | 小任务：仅 Superpowers stop-hook，节省 token   |
| `monitor` | 监控模式   | Ralph 后台跑，前台 Claude Code 手动控制        |

## 前提条件

```Bash
# 1. 安装 Claude Code
npm install -g @anthropic-ai/claude-code

# 2. 安装 Ralph
git clone https://github.com/frankbria/ralph-claude-code.git
cd ralph-claude-code
./install.sh

# 3. 给脚本执行权限
chmod +x start-claude-code-ralph.sh
```

## 脚本自动创建的文件

```Plain
项目目录/
├── .claude/
│   └── agents/
│       ├── architect.md      # Architect Agent
│       ├── implementer.md    # Implementer Agent
│       └── reviewer.md       # Reviewer Agent
├── .ralph/                   # Ralph 状态文件
│   ├── PROMPT.md
│   ├── fix_plan.md
│   └── AGENT.md
├── .ralphrc                  # Ralph 配置文件
└── start-claude-code-ralph.sh  # 本脚本
```