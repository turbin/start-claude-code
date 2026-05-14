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

# ── Git Bash compatibility ─────────────────────────────────────
# On Windows (Git Bash), convert Unix-style paths to Windows paths
# before passing to python3, and strip \r from outputs.
case "$(uname -o 2>/dev/null || true)" in
  Msys*|MINGW*)
    TO_WIN_PATH() { cygpath -m "$1" 2>/dev/null || echo "$1"; }
    TR_CR="tr -d '\r'"
    ;;
  *)
    TO_WIN_PATH() { echo "$1"; }
    TR_CR="cat"
    ;;
esac

LOG_TAG="[model-env]"

# ── Find python (Windows may have python3 as Store stub) ─────────
if python3 -c "pass" 2>/dev/null; then
  PY=python3
elif python -c "pass" 2>/dev/null; then
  PY=python
else
  echo "$LOG_TAG ERROR: python3/python not found" >&2
  return 1 2>/dev/null || exit 1
fi

SETTINGS_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
SETTINGS_FILE_WIN="$(TO_WIN_PATH "$SETTINGS_FILE")"

log()  { echo "$LOG_TAG $*" >&2; }
warn() { echo "$LOG_TAG ⚠ $*" >&2; }

# ── Script location (for standalone sourcing) ──────────────────
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_SOURCE" ]]; do
  LINK_TARGET="$(readlink "$SCRIPT_SOURCE")"
  if [[ "$LINK_TARGET" == /* ]]; then
    SCRIPT_SOURCE="$LINK_TARGET"
  else
    SCRIPT_SOURCE="$(dirname "$SCRIPT_SOURCE")/$LINK_TARGET"
  fi
done
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)}"

# ── Load local .env file (for API keys) ─────────────────────────
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

# ── Model registry ──────────────────────────────────────────────
# Reads from models.json; returns: context_tokens|max_thinking_tokens|flags|base_url|id|api_key_env
get_model_config() {
  local model_name="$1"
  local config_file="$SCRIPT_DIR/models.json"

  if [[ ! -f "$config_file" ]]; then
    echo ""
    return
  fi

  "$PY" -c "
import json, sys
try:
    with open('$(TO_WIN_PATH "$config_file")') as f:
        d = json.load(f)
    m = d.get('models', {}).get('$model_name')
    if m:
        print(f\"{m.get('context_tokens','')}|{m.get('max_thinking_tokens','')}|{m.get('flags','')}|{m.get('base_url','')}|{m.get('id','')}|{m.get('api_key_env','')}\")
except Exception:
    pass
" 2>/dev/null | $TR_CR
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
  if [[ -f "$SETTINGS_FILE" ]]; then
    log "Reading model from $SETTINGS_FILE"

    # Extract raw model value; handle both clean and polluted strings
    RAW_MODEL=$("$PY" -c "
import json, re, sys

try:
    with open('$SETTINGS_FILE_WIN') as f:
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
" 2>&1 | $TR_CR) || { warn "Failed to parse settings.json: $RAW_MODEL"; return 1 2>/dev/null || exit 1; }

    MODEL="$RAW_MODEL"
  fi
fi

# ── Fallback to default model ───────────────────────────────────
if [[ -z "$MODEL" ]]; then
  DEFAULT_MODEL=$("$PY" -c "
import json
try:
    with open('$(TO_WIN_PATH "$SCRIPT_DIR/models.json")') as f:
        d = json.load(f)
    print(d.get('default_model', ''))
except Exception:
    pass
" 2>/dev/null | $TR_CR)

  if [[ -n "$DEFAULT_MODEL" ]]; then
    MODEL="$DEFAULT_MODEL"
    log "No model detected, using default: $MODEL"
  else
    warn "No model detected and no default configured."
    return 0 2>/dev/null || exit 0
  fi
fi

log "Detected model: $MODEL"

# ── Look up config ──────────────────────────────────────────────
CONFIG="$(get_model_config "$MODEL")"

if [[ -n "$CONFIG" ]]; then
  IFS='|' read -r CONTEXT THINKING FLAGS BASE_URL MODEL_ID API_KEY_ENV <<< "$CONFIG"
  log "Matched known model config"
else
  CONTEXT=128000
  THINKING=16000
  FLAGS="cache"
  warn "Unknown model '$MODEL', using defaults (context=128k, thinking=16k)"
fi

# ── Fix polluted settings.json ──────────────────────────────────
if [[ -f "$SETTINGS_FILE" ]]; then
  CURRENT_MODEL_FIELD=$("$PY" -c "
import json
with open('$SETTINGS_FILE_WIN') as f:
    d = json.load(f)
print(d.get('model', ''))
" 2>/dev/null | $TR_CR || echo "")

  # Check if the field has extra content beyond the model name
  if [[ "$CURRENT_MODEL_FIELD" != "$MODEL" && "$CURRENT_MODEL_FIELD" == *"$MODEL"* ]]; then
    log "Fixing polluted model field in settings.json"
    "$PY" -c "
import json

with open('$SETTINGS_FILE_WIN') as f:
    d = json.load(f)

old = d.get('model', '')
d['model'] = '$MODEL'

with open('$SETTINGS_FILE_WIN', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')

print(f'  Fixed: \"{old[:50]}...\" → \"$MODEL\"')
" 2>&1 | $TR_CR | while read -r line; do log "$line"; done
  fi
fi

# ── Export environment variables ────────────────────────────────
if [[ -n "${MODEL_ID:-}" ]]; then
  export ANTHROPIC_MODEL="$MODEL_ID"
else
  export ANTHROPIC_MODEL="$MODEL"
fi
export MAX_THINKING_TOKENS="$THINKING"

# Context tokens — Claude Code respects this for context management
export CLAUDE_CODE_MAX_CONTEXT_TOKENS="$CONTEXT"

# Export base URL if present
if [[ -n "${BASE_URL:-}" ]]; then
  export ANTHROPIC_BASE_URL="$BASE_URL"
fi

# Export API key if the referenced env var is set
if [[ -n "${API_KEY_ENV:-}" ]]; then
  API_KEY_VALUE="${!API_KEY_ENV:-}"
  if [[ -n "$API_KEY_VALUE" ]]; then
    export ANTHROPIC_AUTH_TOKEN="$API_KEY_VALUE"
    log "Using API key from $API_KEY_ENV"
  else
    warn "$API_KEY_ENV is not set — API calls may fail"
  fi
fi

# Enable prompt caching (default, but explicit for clarity)
# Only unset if it was previously disabled
if [[ -n "${DISABLE_PROMPT_CACHING:-}" ]]; then
  unset DISABLE_PROMPT_CACHING
  log "Re-enabled prompt caching"
fi

# ── Summary ─────────────────────────────────────────────────────
SAFE_CONTEXT=$(( CONTEXT * 80 / 100 ))

log "┌──────────────────────────────────────────────┐"
log "│ Model:    $ANTHROPIC_MODEL"
log "│ Context:  ${CONTEXT} tokens (safe: ~${SAFE_CONTEXT})"
log "│ Thinking: ${THINKING} tokens max"
log "│ Caching:  enabled"
if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
  log "│ Base URL: ${ANTHROPIC_BASE_URL}"
fi
log "└──────────────────────────────────────────────┘"
