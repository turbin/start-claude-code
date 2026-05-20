#!/usr/bin/env bash
set -euo pipefail

# install.sh — Install start-claude-code to ~/.local/bin/start-claude-code
#
# Usage:
#   ./install.sh                    # install to default location
#   ./install.sh /custom/path       # install to custom location

# ── Resolve source directory ────────────────────────────────────
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_SOURCE" ]]; do
  LINK_TARGET="$(readlink "$SCRIPT_SOURCE")"
  if [[ "$LINK_TARGET" == /* ]]; then
    SCRIPT_SOURCE="$LINK_TARGET"
  else
    SCRIPT_SOURCE="$(dirname "$SCRIPT_SOURCE")/$LINK_TARGET"
  fi
done
SOURCE_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# ── Default install path ────────────────────────────────────────
INSTALL_DIR="${1:-$HOME/.local/bin/start-claude-code}"

echo "Installing start-claude-code to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

# ── Copy core files ─────────────────────────────────────────────
cp -v "$SOURCE_DIR/start-claude-quick.sh" "$INSTALL_DIR/"
cp -v "$SOURCE_DIR/start-claude-quick.bat" "$INSTALL_DIR/"
cp -v "$SOURCE_DIR/model-env.sh" "$INSTALL_DIR/"
cp -v "$SOURCE_DIR/model-switch.sh" "$INSTALL_DIR/"
cp -v "$SOURCE_DIR/model-switch.bat" "$INSTALL_DIR/"
cp -v "$SOURCE_DIR/model-switch.nu" "$INSTALL_DIR/"
cp -v "$SOURCE_DIR/models.json" "$INSTALL_DIR/"

# ── Create or copy .env ─────────────────────────────────────────
if [[ -f "$SOURCE_DIR/.env" ]]; then
  cp -v "$SOURCE_DIR/.env" "$INSTALL_DIR/.env"
  echo "Copied existing .env with API keys"
else
  cat > "$INSTALL_DIR/.env" << 'EOF'
# Qwen Coding Plan API Key
QWEN_CODING_API_KEY=""

# Moonshot / Kimi API Key (optional)
# MOONSHOT_API_KEY=""
EOF
  echo "Created $INSTALL_DIR/.env — please edit it to add your API keys"
fi

# ── Add / update shell aliases ──────────────────────────────────
for RC in ~/.bashrc ~/.zshrc; do
  if [[ -f "$RC" ]]; then
    if grep -q "# start-claude-quick aliases" "$RC" 2>/dev/null; then
      # Update existing block
      sed -i "s|export PATH=.*start-claude-code.*|export PATH=\"$INSTALL_DIR:\$PATH\"|" "$RC"
      sed -i "s|alias claude-new=.*|alias claude-new='$INSTALL_DIR/start-claude-quick.sh --new'|" "$RC"
      sed -i "s|alias claude-resume=.*|alias claude-resume='$INSTALL_DIR/start-claude-quick.sh --resume'|" "$RC"
      sed -i "s|alias model-switch=.*|alias model-switch='source $INSTALL_DIR/model-switch.sh'|" "$RC"
      echo "Updated aliases in $RC"
    else
      cat >> "$RC" << EOF

# start-claude-quick aliases
export PATH="$INSTALL_DIR:\$PATH"
alias claude-new='$INSTALL_DIR/start-claude-quick.sh --new'
alias claude-resume='$INSTALL_DIR/start-claude-quick.sh --resume'
alias model-switch='source $INSTALL_DIR/model-switch.sh'
EOF
      echo "Added aliases to $RC"
    fi
  fi
done

# ── Summary ─────────────────────────────────────────────────────
echo ""
echo "Installation complete!"
echo "  Directory: $INSTALL_DIR"
echo ""
echo "Next steps:"
echo "  1. Edit $INSTALL_DIR/.env  to add your API keys (if not already set)"
echo "  2. Run: source ~/.bashrc   (or source ~/.zshrc)"
echo "  3. Use:  claude-new        (start new session)"
echo "          claude-resume     (resume last session)"
echo "          model-switch      (list / switch models)"
echo "  Or:    start-claude-quick.sh --switch <model>"
