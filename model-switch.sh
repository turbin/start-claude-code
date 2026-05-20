#!/usr/bin/env bash
set -euo pipefail

# model-switch.sh — Switch the active Claude Code model
#
# Usage:
#   source model-switch.sh              # interactive picker
#   source model-switch.sh qwen3.6-plus # switch to specific model
#   model-switch                        # if installed in PATH
#   model-switch --list                 # show available models

# ── Git Bash compatibility ─────────────────────────────────────
case "$(uname -o 2>/dev/null || true)" in
  Msys*|MINGW*)
    TO_WIN_PATH() { cygpath -m "$1" 2>/dev/null || echo "$1"; }
    ;;
  *)
    TO_WIN_PATH() { echo "$1"; }
    ;;
esac

# ── Script location ─────────────────────────────────────────────
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_SOURCE" ]]; do
  LINK_TARGET="$(readlink "$SCRIPT_SOURCE")"
  if [[ "$LINK_TARGET" == /* ]]; then
    SCRIPT_SOURCE="$LINK_TARGET"
  else
    SCRIPT_SOURCE="$(dirname "$SCRIPT_SOURCE")/$LINK_TARGET"
  fi
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
SCRIPT_DIR_WIN="$(TO_WIN_PATH "$SCRIPT_DIR")"

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CONFIG_DIR_WIN="$(TO_WIN_PATH "$CONFIG_DIR")"
SETTINGS_FILE="$CONFIG_DIR/settings.json"
SETTINGS_FILE_WIN="$CONFIG_DIR_WIN/settings.json"

# ── Helpers ─────────────────────────────────────────────────────
log()  { echo "[model-switch] $*" >&2; }
warn() { echo "[model-switch] ⚠ $*" >&2; }

# ── Find python ─────────────────────────────────────────────────
if python3 -c "pass" 2>/dev/null; then
  PY=python3
elif python -c "pass" 2>/dev/null; then
  PY=python
else
  warn "python3/python not found"
  return 1 2>/dev/null || exit 1
fi

MODELS_FILE="$SCRIPT_DIR/models.json"
MODELS_FILE_WIN="$SCRIPT_DIR_WIN/models.json"

# ── List models ─────────────────────────────────────────────────
list_models() {
  if [[ ! -f "$MODELS_FILE" ]]; then
    warn "models.json not found at $MODELS_FILE"
    return 1
  fi

  local current_model=""
  if [[ -f "$SETTINGS_FILE" ]]; then
    current_model=$("$PY" -c "
import json
try:
    with open('$SETTINGS_FILE_WIN') as f: d = json.load(f)
    print(d.get('model', ''))
except: pass
" 2>/dev/null || true)
  fi

  echo "Available models in models.json:"
  echo ""
  "$PY" -c "
import json
with open('$MODELS_FILE_WIN') as f: d = json.load(f)
models = d.get('models', {})
default = d.get('default_model', '')
for name, cfg in models.items():
    marker = '*' if name == '$current_model' else ' '
    ctx = cfg.get('context_tokens', '?')
    think = cfg.get('max_thinking_tokens', '?')
    base = cfg.get('base_url', '').split('/')[2] if cfg.get('base_url') else '?'
    print(f'  {marker} {name:<20} context={ctx:>8}  thinking={think:>6}  [{base}]')
print()
if default:
    print(f'  Default model: {default}')
"
}

# ── Get model info ──────────────────────────────────────────────
get_model_info() {
  local model_name="$1"
  "$PY" -c "
import json, sys
with open('$MODELS_FILE_WIN') as f: d = json.load(f)
m = d.get('models', {}).get('$model_name')
if m:
    print(f\"id={m.get('id', '')}\")
    print(f\"base_url={m.get('base_url', '')}\")
    print(f\"context={m.get('context_tokens', '')}\")
    print(f\"thinking={m.get('max_thinking_tokens', '')}\")
else:
    sys.exit(1)
" 2>/dev/null
}

# ── Switch model ────────────────────────────────────────────────
switch_model() {
  local model_name="$1"

  # Validate model exists in models.json
  if [[ -f "$MODELS_FILE" ]]; then
    if ! "$PY" -c "
import json, sys
with open('$MODELS_FILE_WIN') as f: d = json.load(f)
if '$model_name' not in d.get('models', {}):
    sys.exit(1)
" 2>/dev/null; then
      warn "Unknown model: $model_name"
      echo ""
      list_models
      return 1
    fi
  fi

  # Create config dir if needed
  mkdir -p "$CONFIG_DIR"

  # Update settings.json
  if [[ -f "$SETTINGS_FILE" ]]; then
    "$PY" -c "
import json
with open('$SETTINGS_FILE_WIN') as f: d = json.load(f)
old = d.get('model', '')
d['model'] = '$model_name'
with open('$SETTINGS_FILE_WIN', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
if old:
    print(f'Switched: {old} → $model_name')
else:
    print(f'Set model: $model_name')
"
  else
    "$PY" -c "
import json
d = {'model': '$model_name'}
with open('$SETTINGS_FILE_WIN', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
print(f'Created settings.json with model: $model_name')
"
  fi

  # Show model info
  echo ""
  if info=$(get_model_info "$model_name"); then
    while IFS='=' read -r key value; do
      log "$key = $value"
    done <<< "$info"
  fi
}

# ── Parse args ──────────────────────────────────────────────────
case "${1:-}" in
  --list|-l|list)
    list_models
    return 0 2>/dev/null || exit 0
    ;;
  --help|-h|help)
    cat <<'EOF'
Usage: model-switch [MODEL]

Switch the active Claude Code model.

Arguments:
  MODEL         Model name from models.json (e.g. qwen3.6-plus)
  --list, -l    Show available models and current selection
  --help, -h    Show this help

Examples:
  model-switch                    # interactive picker
  model-switch qwen3.6-plus       # switch directly
  model-switch --list             # show available models
EOF
    return 0 2>/dev/null || exit 0
    ;;
  "")
    # Interactive picker
    ;;
  *)
    switch_model "$1"
    return 0 2>/dev/null || exit 0
    ;;
esac

# ── Interactive picker ──────────────────────────────────────────
if [[ ! -f "$MODELS_FILE" ]]; then
  warn "models.json not found at $MODELS_FILE"
  return 1 2>/dev/null || exit 1
fi

# Get current model
current_model=""
if [[ -f "$SETTINGS_FILE" ]]; then
  current_model=$("$PY" -c "
import json
try:
    with open('$SETTINGS_FILE_WIN') as f: d = json.load(f)
    print(d.get('model', ''))
except: pass
" 2>/dev/null || true)
fi

echo "Available models:"
echo ""

# Build numbered list
"$PY" -c "
import json
with open('$MODELS_FILE_WIN') as f: d = json.load(f)
models = d.get('models', {})
for i, (name, cfg) in enumerate(models.items(), 1):
    marker = ' (current)' if name == '$current_model' else ''
    ctx = cfg.get('context_tokens', '?')
    think = cfg.get('max_thinking_tokens', '?')
    print(f'  [{i}] {name}  (context={ctx}, thinking={think}){marker}')
print()
print(f'  Enter number to switch, or press Enter to cancel')
"

read -r -p "Choice: " CHOICE
CHOICE=$(echo "$CHOICE" | tr -d '[:space:]')

if [[ -z "$CHOICE" ]]; then
  log "Cancelled"
  return 0 2>/dev/null || exit 0
fi

# Resolve choice to model name
MODEL_NAME=$("$PY" -c "
import json, sys
with open('$MODELS_FILE_WIN') as f: d = json.load(f)
models = list(d.get('models', {}).keys())
idx = int('$CHOICE') - 1
if 0 <= idx < len(models):
    print(models[idx])
" 2>/dev/null || true)

if [[ -z "$MODEL_NAME" ]]; then
  warn "Invalid choice: $CHOICE"
  return 1 2>/dev/null || exit 1
fi

switch_model "$MODEL_NAME"
