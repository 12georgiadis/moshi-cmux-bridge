# --- moshi-cmux-bridge: auto-attach when launched from Moshi -----------------
# Paste this near the TOP of your ~/.zshrc, BEFORE any auto-tmux logic.
# It checks for MOSHI_CLIENT=1 (set by Moshi when "Export ENV" is on in
# Settings → Integrations) and exec's into the dashboard.
# Type `q` in the dashboard to quit, which closes the SSH session cleanly.

if [ -n "$MOSHI_CLIENT" ] && [ -z "$TMUX" ] && [ -t 0 ]; then
  exec "$HOME/.claude/scripts/dashboard.sh"
fi

# Manual menu shortcut from any shell:
s() { "$HOME/.claude/scripts/dashboard.sh"; }
# --- end moshi-cmux-bridge ---------------------------------------------------
