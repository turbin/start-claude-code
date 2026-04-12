#!/usr/bin/env bash
#
# model-env.sh — Auto-detect the current model, fix settings.json if
# polluted, and export Claude Code environment variables tuned for that
# model's context window and capabilities.
#
# Usage:
#   source model-env.sh                # detect from settings.json
#   source model-env.sh qwen3.6-plus   # override with explicit model
#   # then launch claude as usual
#

set -euo pipefail

LOG_TAG="[model-env]"
SETTINGS_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"

log()  { echo "$LOG_TAG $*" >&2; }
warn() { echo "$LOG_TAG ⚠ $*" >&2; }

# ── Model registry ──────────────────────────────────────────────
# Returns: context_tokens|max_thinking_tokens|flags
get_model_config() {
  case "$1" in
    minimax-2.7)  echo "245760|16384|cache"  ;;
    minimax-2.5)  echo "245760|16384|cache"  ;;
    qwen3.6-plus) echo "1000000|31999|cache" ;;
    qwen3.5-plus) echo "1000000|31999|cache" ;;
    kimi-k2.5)    echo "256000|16384|cache"  ;;
    *)            echo ""                    ;;
  esac
}

# ── Detect model ────────────────────────────────────────────────
# Only use $1 if it looks like a model name (not a flag or action keyword)
MODEL="${1:-}"
case "${MODEL:-}" in
  --*|-h|--help|help|new|-n|--new|resume|-r|--resume)
    MODEL=""
    ;;
esac

if [[ -z "$MODEL" ]]; then
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    warn "settings.json not found at $SETTINGS_FILE"
    return 0 2>/dev/null || exit 0
  fi

  log "Reading model from $SETTINGS_FILE"

  # Extract raw model value; handle both clean and polluted strings
  RAW_MODEL=$(python3 -c "
import json, re, sys

try:
    with open('$SETTINGS_FILE') as f:
        d = json.load(f)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)

raw = d.get('model', '')
if not raw:
    sys.exit(0)

# If polluted (contains newlines or status text), extract first word
raw = raw.strip()
# Match known model patterns: word chars, digits, dots, hyphens
m = re.match(r'^[\w.\-]+', raw)
if m:
    print(m.group(0))
else:
    print(raw.split()[0])
" 2>&1) || { warn "Failed to parse settings.json: $RAW_MODEL"; return 1 2>/dev/null || exit 1; }

  MODEL="$RAW_MODEL"
fi

if [[ -z "$MODEL" ]]; then
  warn "No model detected. Set ANTHROPIC_MODEL or pass model as argument."
  return 0 2>/dev/null || exit 0
fi

log "Detected model: $MODEL"

# ── Look up config ──────────────────────────────────────────────
CONFIG="$(get_model_config "$MODEL")"

if [[ -n "$CONFIG" ]]; then
  IFS='|' read -r CONTEXT THINKING FLAGS <<< "$CONFIG"
  log "Matched known model config"
else
  CONTEXT=128000
  THINKING=16000
  FLAGS="cache"
  warn "Unknown model '$MODEL', using defaults (context=128k, thinking=16k)"
fi

# ── Fix polluted settings.json ──────────────────────────────────
if [[ -f "$SETTINGS_FILE" ]]; then
  CURRENT_MODEL_FIELD=$(python3 -c "
import json
with open('$SETTINGS_FILE') as f:
    d = json.load(f)
print(d.get('model', ''))
" 2>/dev/null || echo "")

  # Check if the field has extra content beyond the model name
  if [[ "$CURRENT_MODEL_FIELD" != "$MODEL" && "$CURRENT_MODEL_FIELD" == *"$MODEL"* ]]; then
    log "Fixing polluted model field in settings.json"
    python3 -c "
import json

with open('$SETTINGS_FILE') as f:
    d = json.load(f)

old = d.get('model', '')
d['model'] = '$MODEL'

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')

print(f'  Fixed: \"{old[:50]}...\" → \"$MODEL\"')
" 2>&1 | while read -r line; do log "$line"; done
  fi
fi

# ── Export environment variables ────────────────────────────────
export ANTHROPIC_MODEL="$MODEL"
export MAX_THINKING_TOKENS="$THINKING"

# Context tokens — Claude Code respects this for context management
export CLAUDE_CODE_MAX_CONTEXT_TOKENS="$CONTEXT"

# Enable prompt caching (default, but explicit for clarity)
# Only unset if it was previously disabled
if [[ -n "${DISABLE_PROMPT_CACHING:-}" ]]; then
  unset DISABLE_PROMPT_CACHING
  log "Re-enabled prompt caching"
fi

# ── Summary ─────────────────────────────────────────────────────
SAFE_CONTEXT=$(( CONTEXT * 80 / 100 ))

log "┌──────────────────────────────────────────────┐"
log "│ Model:    $MODEL"
log "│ Context:  ${CONTEXT} tokens (safe: ~${SAFE_CONTEXT})"
log "│ Thinking: ${THINKING} tokens max"
log "│ Caching:  enabled"
log "└──────────────────────────────────────────────┘"
