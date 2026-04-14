#!/usr/bin/env bash
set -euo pipefail

# ── Git Bash compatibility ─────────────────────────────────────
# In Git Bash on Windows, ensure we use Unix-style tools and strip
# carriage returns that Windows line-endings may introduce.
case "$(uname -o 2>/dev/null || true)" in
  Msys*|MINGW*)
    # Force Unix find (not Windows find.exe) and strip \r everywhere
    FIND_CMD="/usr/bin/find"
    TR_CR="tr -d '\r'"
    ;;
  *)
    FIND_CMD="find"
    TR_CR="cat"
    ;;
esac

# ── Help (handle before sourcing env) ─────────────────────────
case "$*" in
  help|-h|--help)
    cat <<'EOF'
Usage: start-claude-quick.sh [OPTIONS] [EXTRA_ARGS...]

Start Claude Code with auto-detected model environment and session management.

Actions:
  resume, -r, --resume    Resume the most recent conversation
  new, -n, --new          Start a fresh conversation
  (none)                  Interactive picker (new / resume / pick)

Session picker:
  When no action is specified and past sessions exist, a menu appears:
    [1] New session (default, press Enter)
    [2] Resume latest
    [3] Pick session...  → opens claude --resume interactive picker

Extra args:
  Any unrecognized arguments are passed through to claude directly.
  Examples:
    ./start-claude-quick.sh --model sonnet
    ./start-claude-quick.sh -c "explain the project structure"
    ./start-claude-quick.sh --name "refactor auth"

Environment:
  Automatically sources model-env.sh to set:
    ANTHROPIC_MODEL            — model from settings.json
    MAX_THINKING_TOKENS        — model-specific thinking budget
    CLAUDE_CODE_MAX_CONTEXT_TOKENS — model context window

Model switching:
  1. Run: cc switch <model>    (updates settings.json)
  2. Run: ./start-claude-quick.sh  (auto-reads new model)
EOF
    exit 0
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Load model environment variables ──────────────────────────
source "$SCRIPT_DIR/model-env.sh"

# ── Parse arguments ───────────────────────────────────────────
ACTION=""
EXTRA_ARGS=()

for arg in "$@"; do
  case "$arg" in
    resume|-r|--resume)
      ACTION="resume"
      ;;
    new|-n|--new)
      ACTION="new"
      ;;
    *)
      EXTRA_ARGS+=("$arg")
      ;;
  esac
done

# ── Auto-prompt when no action specified ─────────────────────
if [[ -z "$ACTION" ]]; then
  # Derive project directory name from script location
  # Claude Code maps /a/b/c → -a-b-c for the projects dir
  # In Git Bash, SCRIPT_DIR is already Unix-style (/d/workspace/...)
  PROJECT_KEY="$(echo "$SCRIPT_DIR" | sed 's|^/|-|; s|/|-|g' | $TR_CR)"
  PROJECT_DIR="$HOME/.claude/projects/$PROJECT_KEY"

  # Count existing sessions (use Unix find, strip \r from wc output)
  SESSION_COUNT=$($FIND_CMD "$PROJECT_DIR" -maxdepth 1 -name '*.jsonl' 2>/dev/null | wc -l | $TR_CR | tr -d '[:space:]')

  if [[ "$SESSION_COUNT" -gt 0 ]]; then
    echo ""
    echo "  [1] New session (default)"
    echo "  [2] Resume latest"
    echo "  [3] Pick session..."
    echo ""
    read -r -n 1 -p "  Choice (Enter=1): " CHOICE || CHOICE=""
    echo ""
    case "$CHOICE" in
      2) ACTION="resume" ;;
      3) ACTION="pick"   ;;
      *) ACTION="new"    ;;
    esac
  else
    ACTION="new"
  fi
fi

# ── Build claude command ──────────────────────────────────────
CLAUDE_ARGS=("--allow-dangerously-skip-permissions" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"})

case "$ACTION" in
  resume)
    CLAUDE_ARGS+=("--continue")
    ;;
  pick)
    CLAUDE_ARGS+=("--resume")
    ;;
  new|*)
    # Default: fresh session, no extra flags needed
    ;;
esac

exec claude "${CLAUDE_ARGS[@]}" || claude "${CLAUDE_ARGS[@]}"
