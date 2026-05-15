#!/bin/bash
# cleanup-orphans.sh — kill orphan ttysNNN tmux sessions, safely.
#
# A ttysNNN tmux session is ORPHAN when no `tmux new-session -s ttysNNN` process
# is currently running (= the cmux panel that owned it has been closed).
#
# SAFETY: only kills orphans whose pane is an IDLE shell (zsh/bash/sh).
# If `claude`, `node`, `python`, etc. is still running inside, the session is
# KEPT — you can pick it back up from the dashboard. This way, closing a cmux
# workspace while claude is still working does not destroy the session.
#
# Runs tmux-resurrect save BEFORE any kill, as an extra safety net.
#
# Invoked by launchd every 30 minutes + via the `c` key in dashboard.sh.

TMUX_BIN="${TMUX_BIN:-/opt/homebrew/bin/tmux}"
RESURRECT_SAVE="${RESURRECT_SAVE:-$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh}"

rtmux() { env -u TMUX -u TMUX_PANE "$TMUX_BIN" "$@"; }

# ttysNNN sessions that still have a live owning process
LIVE=$(ps -Ao command | grep '[t]mux new-session' | sed -nE 's/.*-s ([^ ]+).*/\1/p' | sort -u)

# All ttysNNN sessions on the tmux server
ALL=$(rtmux list-sessions -F '#{session_name}' 2>/dev/null | grep -E '^ttys[0-9]+$')

if [ -z "$ALL" ]; then
  echo "$(date '+%H:%M') cleanup: no ttys sessions"
  exit 0
fi

# Diff: orphans
ORPHANS=()
while read -r s; do
  [ -z "$s" ] && continue
  echo "$LIVE" | grep -qx "$s" || ORPHANS+=("$s")
done <<< "$ALL"

if [ ${#ORPHANS[@]} -eq 0 ]; then
  echo "$(date '+%H:%M') cleanup: no orphans"
  exit 0
fi

# resurrect backup before any kill
if [ -x "$RESURRECT_SAVE" ]; then
  rtmux run-shell "$RESURRECT_SAVE" 2>/dev/null
  sleep 1
fi

killed=0
kept=0
for s in "${ORPHANS[@]}"; do
  cmd=$(rtmux list-panes -t "$s" -F '#{pane_current_command}' 2>/dev/null | head -1)
  case "$cmd" in
    zsh|-zsh|bash|-bash|sh|-sh|"")
      rtmux kill-session -t "$s" 2>/dev/null && { echo "  killed $s (idle)"; killed=$((killed+1)); }
      ;;
    *)
      echo "  kept   $s ($cmd active)"
      kept=$((kept+1))
      ;;
  esac
done

echo "$(date '+%H:%M') cleanup: $killed killed, $kept kept (process active)"
