#!/bin/bash
# uninstall.sh — one-shot revert of moshi-cmux-bridge.
#
# Restores .zshrc from the backup, unloads launchd, removes installed files.
# The backup path is read from ~/.moshi-cmux-bridge.installed (written by install.sh).

set -e

MARKER="$HOME/.moshi-cmux-bridge.installed"

if [ ! -f "$MARKER" ]; then
  echo "No installation marker found at $MARKER"
  echo "Manual revert: restore your .zshrc backup and remove ~/.claude/scripts/dashboard.sh etc."
  exit 1
fi

# shellcheck disable=SC1090
. "$MARKER"

echo "Reverting moshi-cmux-bridge..."

# 1. Unload launchd agent
PLIST="$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"
if launchctl list 2>/dev/null | grep -q "$LAUNCHD_LABEL"; then
  launchctl unload "$PLIST" 2>/dev/null
  echo "  ok  launchd agent unloaded ($LAUNCHD_LABEL)"
fi

# 2. Restore .zshrc from backup
if [ -f "$ZSHRC_BACKUP" ]; then
  cp "$ZSHRC_BACKUP" "$HOME/.zshrc"
  echo "  ok  .zshrc restored from $ZSHRC_BACKUP"
else
  echo "  !!  backup not found at $ZSHRC_BACKUP — .zshrc untouched"
fi

# 3. Remove installed files
rm -f "$PLIST"
rm -f "$INSTALL_DIR/dashboard.sh"
rm -f "$INSTALL_DIR/cleanup-orphans.sh"
rm -f "$INSTALL_DIR/moshi-bridge-uninstall.sh"
rm -f "$MARKER"
echo "  ok  installed files removed"

echo
echo "Revert complete. Open a new shell to reload the original .zshrc."
