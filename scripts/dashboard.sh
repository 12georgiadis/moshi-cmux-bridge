#!/bin/bash
# dashboard.sh — Moshi dashboard for cmux workspaces + named tmux sessions
#
# Lists cmux workspaces by their FRIENDLY title (compta, project-X, etc.)
# alongside any named tmux sessions you have, and attaches to whichever you pick.
#
# Auto-invoked from .zshrc when MOSHI_CLIENT=1.
# Or run manually from any shell: `dashboard.sh` (alias `s` if you set it up).
#
# Live reads cmux state every time the menu opens — no cache, no daemon.
# Reflects renames in cmux UI immediately on next refresh.

TMUX_BIN="${TMUX_BIN:-/opt/homebrew/bin/tmux}"
CMUX_BIN="${CMUX_BIN:-/Applications/cmux.app/Contents/Resources/bin/cmux}"

# Resolve cleanup script in same directory as this one
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANUP="${CLEANUP_SCRIPT:-$SCRIPT_DIR/cleanup-orphans.sh}"

# Real tmux without contamination from current cmux/tmux env
rtmux() { env -u TMUX -u TMUX_PANE "$TMUX_BIN" "$@"; }

SESSIONS=()

show_menu() {
  clear
  SESSIONS=()
  local now batt hostname
  now=$(date '+%H:%M')
  batt=$(pmset -g batt 2>/dev/null | grep -oE '[0-9]+%' | head -1)
  hostname=$(scutil --get ComputerName 2>/dev/null || hostname)
  echo "==================================================="
  printf "  Dashboard — %s        %s  %s\n" "$hostname" "$now" "${batt:-?}"
  echo "==================================================="
  echo

  # Build UUID → title map from cmux RPC
  local tmpmap
  tmpmap=$(mktemp)
  "$CMUX_BIN" rpc debug.terminals 2>/dev/null \
    | jq -r '.terminals[] | "\(.workspace_id)\t\(.workspace_title)"' > "$tmpmap" 2>/dev/null

  local i=1
  local found_cmux=0

  # CMUX workspaces: ttysNNN tmux sessions with a live tmux new-session process
  echo "  CMUX workspaces"
  while read -r pid cmd; do
    local sess
    sess=$(echo "$cmd" | sed -nE 's/.*-s ([^ ]+).*/\1/p')
    [ -z "$sess" ] && continue
    rtmux has-session -t "$sess" 2>/dev/null || continue
    local wsid title
    wsid=$(ps eww "$pid" 2>/dev/null | tr ' ' '\n' | grep '^CMUX_WORKSPACE_ID=' | cut -d= -f2)
    title=$(grep -F "$wsid" "$tmpmap" 2>/dev/null | head -1 | cut -f2)
    [ -z "$title" ] && title="$sess"
    SESSIONS+=("$sess")
    printf "   %2d) %s\n" "$i" "$title"
    i=$((i+1)); found_cmux=1
  done < <(ps -Ao pid,command | grep '[t]mux new-session')
  [ "$found_cmux" -eq 0 ] && echo "      (none — is cmux running?)"

  # Named tmux sessions (anything not matching ttysNNN)
  echo
  echo "  Named tmux sessions"
  local found_named=0
  while read -r line; do
    local name att
    name="${line%% *}"
    att="${line##* }"
    [[ "$name" =~ ^ttys[0-9]+$ ]] && continue
    [ -z "$name" ] && continue
    SESSIONS+=("$name")
    if [ "$att" = "1" ]; then
      printf "   %2d) %s  [attached]\n" "$i" "$name"
    else
      printf "   %2d) %s\n" "$i" "$name"
    fi
    i=$((i+1)); found_named=1
  done < <(rtmux list-sessions -F '#{session_name} #{session_attached}' 2>/dev/null)
  [ "$found_named" -eq 0 ] && echo "      (none)"

  rm -f "$tmpmap"

  echo
  echo "  --------------------------------------------------"
  echo "   c) Clean up orphan sessions"
  echo "   s) Plain shell"
  echo "   r) Refresh"
  echo "   q) Quit"
  echo
}

while true; do
  show_menu
  printf "  Choice: "
  read -r choice
  case "$choice" in
    q|Q) clear; exit 0 ;;
    r|R) continue ;;
    s|S) clear; exec "$SHELL" ;;
    c|C)
      echo
      bash "$CLEANUP"
      echo
      printf "  [enter] to return to menu "
      read -r _
      ;;
    ''|*[!0-9]*) ;;  # empty or non-numeric: loop
    *)
      idx=$((choice-1))
      sess="${SESSIONS[$idx]}"
      if [ -n "$sess" ]; then
        rtmux attach -t "$sess"
      fi
      ;;
  esac
done
