#!/bin/bash
# install.sh — opinionated installer for moshi-cmux-bridge.
#
# Env vars you can override:
#   INSTALL_DIR    where to copy scripts        (default: $HOME/.claude/scripts)
#   LOG_DIR        where launchd writes logs    (default: $HOME/.claude/logs)
#   LAUNCHD_LABEL  reverse-domain agent label   (default: com.user.moshi-cmux-bridge.cleanup)

set -e

INSTALL_DIR="${INSTALL_DIR:-$HOME/.claude/scripts}"
LOG_DIR="${LOG_DIR:-$HOME/.claude/logs}"
LAUNCHD_LABEL="${LAUNCHD_LABEL:-com.user.moshi-cmux-bridge.cleanup}"
ZSHRC="$HOME/.zshrc"
ZSHRC_BACKUP="$HOME/.zshrc.bak-$(date +%Y-%m-%d-%H%M)"
MARKER="$HOME/.moshi-cmux-bridge.installed"

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "moshi-cmux-bridge installer"
echo "  INSTALL_DIR   = $INSTALL_DIR"
echo "  LOG_DIR       = $LOG_DIR"
echo "  LAUNCHD_LABEL = $LAUNCHD_LABEL"
echo

# 1. Prereqs
for cmd in tmux mosh-server jq; do
  command -v "$cmd" >/dev/null || { echo "Missing: $cmd. Install with: brew install $cmd"; exit 1; }
done

# 2. Dirs
mkdir -p "$INSTALL_DIR" "$LOG_DIR" "$HOME/Library/LaunchAgents"

# 3. Backup .zshrc
if [ -f "$ZSHRC" ]; then
  cp "$ZSHRC" "$ZSHRC_BACKUP"
  echo "  ok  .zshrc backed up to $ZSHRC_BACKUP"
fi

# 4. Copy scripts
cp "$SRC_DIR/scripts/dashboard.sh"        "$INSTALL_DIR/dashboard.sh"
cp "$SRC_DIR/scripts/cleanup-orphans.sh"  "$INSTALL_DIR/cleanup-orphans.sh"
cp "$SRC_DIR/scripts/uninstall.sh"        "$INSTALL_DIR/moshi-bridge-uninstall.sh"
chmod +x "$INSTALL_DIR/dashboard.sh" "$INSTALL_DIR/cleanup-orphans.sh" "$INSTALL_DIR/moshi-bridge-uninstall.sh"
echo "  ok  scripts installed in $INSTALL_DIR"

# 5. Patch .zshrc if snippet not already there
if ! grep -q "moshi-cmux-bridge" "$ZSHRC" 2>/dev/null; then
  {
    echo ""
    cat "$SRC_DIR/zshrc-snippet.sh" | sed "s|\$HOME/.claude/scripts|$INSTALL_DIR|g"
  } >> "$ZSHRC.new"
  cat "$ZSHRC" >> "$ZSHRC.new" 2>/dev/null || true
  mv "$ZSHRC.new" "$ZSHRC"
  echo "  ok  .zshrc patched (snippet inserted at top)"
else
  echo "  -- .zshrc already contains moshi-cmux-bridge, skipping patch"
fi

# 6. Template + load launchd
PLIST="$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"
sed -e "s|__LAUNCHD_LABEL__|$LAUNCHD_LABEL|g" \
    -e "s|__INSTALL_DIR__|$INSTALL_DIR|g" \
    -e "s|__LOG_DIR__|$LOG_DIR|g" \
    "$SRC_DIR/launchd/tmux-cleanup.plist.template" > "$PLIST"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "  ok  launchd agent loaded ($LAUNCHD_LABEL, every 30 min)"

# 7. Marker file for uninstall.sh
cat > "$MARKER" <<EOF
INSTALL_DIR="$INSTALL_DIR"
LOG_DIR="$LOG_DIR"
LAUNCHD_LABEL="$LAUNCHD_LABEL"
ZSHRC_BACKUP="$ZSHRC_BACKUP"
INSTALL_DATE="$(date -Iseconds)"
EOF
echo "  ok  install marker written to $MARKER"

echo
echo "Done."
echo
echo "Test:"
echo "  1. Open a new shell or run: zsh -c 'MOSHI_CLIENT=1 source ~/.zshrc' (don't actually exec, just dry test syntax)"
echo "  2. From your phone: Moshi → connect → dashboard should appear"
echo
echo "Revert anytime: bash $INSTALL_DIR/moshi-bridge-uninstall.sh"
