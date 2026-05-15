# Safety: how cleanup decides what to kill

The cleanup script's job is to remove `ttysNNN` tmux sessions whose cmux panel was closed, so the dashboard doesn't accumulate dozens of stale entries.

The risk: killing a session that still has live, valuable work in it.

The safeguards, in order:

## 1. Filter to ttysNNN only

```bash
grep -E '^ttys[0-9]+$'
```

Named sessions you created yourself (`goldberg`, `project-alpha`, etc.) are **never** touched. The cleanup only considers sessions matching `ttys` followed by digits — the pattern cmux uses.

## 2. Orphan definition: no live owning process

For each `ttysNNN` session, check whether any `tmux new-session -A -s ttysNNN` process is currently running. If yes, the cmux panel is still open — **keep**. If no, the panel was closed — candidate for cleanup.

## 3. Kill only idle shells

For each orphan candidate, read the current pane's foreground command via tmux:

```bash
tmux list-panes -t ttysNNN -F '#{pane_current_command}'
```

| Foreground command | Action |
|---|---|
| `zsh`, `-zsh`, `bash`, `-bash`, `sh`, `-sh`, empty | KILL (truly idle, nothing running) |
| Anything else (`claude`, `node`, `python`, `vim`, `make`, ...) | KEEP (work in progress) |

So if you closed a cmux workspace **while claude was still running** in it, the tmux session is preserved. The dashboard will show it on next refresh, and you can reattach to recover the work.

## 4. tmux-resurrect backup before any kill

If `~/.tmux/plugins/tmux-resurrect/scripts/save.sh` exists, it's invoked before any session is killed. Worst case (a bug, an edge case), the most recent state is on disk and `prefix + Ctrl-r` restores it.

## What this means in practice

- Close a cmux panel after `/exit` from Claude → idle zsh → cleaned up in next sweep ✓
- Close a cmux panel while Claude is mid-thinking → session **kept**, recoverable from dashboard ✓
- Mac crashes during work → tmux-resurrect saved 5 min ago, sessions restore on reboot ✓
- Bug in the cleanup script → resurrect backup taken first, recoverable ✓

## What it does NOT protect against

- A long-running shell that's truly idle (you `cd`'d, came back hours later, never typed anything). Pane command is `zsh`, no running child. **It will be killed.** If you have shell state you care about, run something that holds a pane (`watch ls`, `tail -f /dev/null`, even `vim`) or create a named session via `tmux new -s your-name`.
- Manually-created `ttysNNN` sessions you somehow named that way. Don't name your own sessions `ttysNNN`.

## Auditing what happened

The launchd agent logs to `$LOG_DIR/tmux-cleanup.log` (default `~/.claude/logs/tmux-cleanup.log`). Tail it:

```bash
tail -f ~/.claude/logs/tmux-cleanup.log
```

Each run prints what was killed, what was kept, and why.

## Disabling cleanup entirely

If you want manual-only cleanup:

```bash
launchctl unload ~/Library/LaunchAgents/<your-label>.plist
```

The `c` key in the dashboard still works for on-demand cleanup. Cron is just convenience.
