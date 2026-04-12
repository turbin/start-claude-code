#!/usr/bin/env bash
set -euo pipefail

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
  PROJECT_KEY="$(echo "$SCRIPT_DIR" | sed 's|^/|-|; s|/|-|g')"
  PROJECT_DIR="$HOME/.claude/projects/$PROJECT_KEY"

  # Count existing sessions
  SESSION_COUNT=$(find "$PROJECT_DIR" -maxdepth 1 -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')

  if [[ "$SESSION_COUNT" -gt 0 ]]; then
    echo ""
    echo "  [1] New session (default)"
    echo "  [2] Resume latest"
    echo "  [3] Pick session..."
    echo ""
    read -r -n 1 -p "  Choice (Enter=1): " CHOICE
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

exec claude "${CLAUDE_ARGS[@]}"
