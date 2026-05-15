# Architecture deep dive

## The orthogonal decomposition

The temptation when designing a "remote dev" workflow is to find one tool that does everything. That always disappoints. The robust design uses several small tools, each doing one thing, with clean boundaries.

This bridge composes five tools:

| Tool | Single responsibility |
|---|---|
| **Tailscale** (or your SSH route) | Private network path between phone and Mac |
| **Mosh** | Connection that survives Wi-Fi → 4G drops, idle timeouts, suspend/resume |
| **tmux** | Persistent shells with resurrect/continuum auto-save |
| **cmux** | Mac-side UI for multiple parallel Claude sessions with friendly names |
| **dashboard.sh** | Live bridge between cmux's friendly names and tmux's session list |

When any one of these evolves (Anthropic adds session restore to cmux in 0.64, Moshi adds Easy Pair, tmux 3.7 changes resurrect format) — the rest are unaffected. That's the value of orthogonality.

## Why a custom dashboard

cmux stores friendly workspace titles (`"compta"`, `"client-call-prep"`) in its internal JSON metadata. It does **not** propagate them to tmux session names — those stay as `ttysNNN` (the controlling pty of the cmux shell).

Moshi's native tmux picker shows tmux session names. So out of the box, you see `ttys000`, `ttys001`, ..., `ttys047` — unusable for picking "the compta one".

The dashboard reconstructs the mapping LIVE, every time the menu opens, via three reads:

```
┌─────────────────────────────────────────────────────────┐
│  1. ps -Ao pid,command | grep '[t]mux new-session'      │
│     → list of (pid, ttysNNN) for live cmux panels       │
├─────────────────────────────────────────────────────────┤
│  2. ps eww <pid>                                         │
│     → extract CMUX_WORKSPACE_ID=<UUID> from env          │
├─────────────────────────────────────────────────────────┤
│  3. cmux rpc debug.terminals                             │
│     → map UUID → friendly workspace_title               │
└─────────────────────────────────────────────────────────┘
              ↓ join
       ttysNNN ↔ friendly title
              ↓ display
       Menu with names you actually recognize
```

No daemon. No cache. No state to maintain. Rename a workspace in cmux UI → next `r` in the dashboard reflects it.

## Why ttysNNN sessions exist at all

The `.zshrc` snippet from cmux itself spawns each shell into its own tmux session named after the controlling tty (`ttys000` etc.). The purpose is crash safety: if cmux quits, the shells survive inside tmux, and continuum auto-restores them on reboot. The session-per-tty model is fine — it's the *naming* that needed bridging.

## Cleanup lifecycle

The downside of session-per-tty: when you close a cmux panel, the tmux session orphans (no client attached, but tmux's `destroy-unattached` is typically `off` to allow resurrect to work).

`cleanup-orphans.sh` solves this with two-criterion safety:

1. **Orphan detection**: no `tmux new-session -s ttysNNN` process running for this session = orphan
2. **Kill safety**: only kill orphans whose pane's `#{pane_current_command}` is a plain shell (`zsh`, `bash`, `sh`)

If you closed a cmux panel while `claude`, `node`, `python`, `vim`, `make` was running inside — the session is **kept**. You can pick it back up from the dashboard. This means: closing a workspace by accident never destroys live work.

Runs every 30 min via launchd, and on demand via `c` in the dashboard.

## Why `exec` in the .zshrc snippet

```bash
if [ -n "$MOSHI_CLIENT" ] && [ -z "$TMUX" ] && [ -t 0 ]; then
  exec "$HOME/.claude/scripts/dashboard.sh"
fi
```

`exec` replaces the current shell process with the dashboard. Consequences:
- When the user picks `q`, the dashboard exits and the SSH connection closes cleanly. No zombie shell underneath.
- If the dashboard crashes, the SSH connection closes — which is the expected behavior for a UI script.
- Memory: one process, not two.

The triple guard `MOSHI_CLIENT && -z $TMUX && -t 0`:
- `MOSHI_CLIENT` (env var set by Moshi when Export ENV is on) — only fire for Moshi connections, not regular SSH
- `-z $TMUX` — don't double-launch if already inside tmux
- `-t 0` — interactive shell only, never in scripted contexts

## Live reads vs caching

Every time the menu opens, three live reads (ps, cmux rpc, tmux list-sessions). This costs ~50ms total but means:
- Rename a workspace in cmux UI → reflected next menu open
- Close a panel → it disappears from the menu next open
- Open a new project → appears next open

No cache invalidation problem. No stale state. Cheap enough that there's no reason to cache.

## What this is NOT

- Not a daemon. Not a server. No long-running process other than the launchd cleanup (which runs 30s every 30 min).
- Not a Claude Code wrapper. Doesn't know what Claude is.
- Not coupled to cmux: removes the cmux block from dashboard.sh and you have a generic friendly-name tmux dashboard.
- Not a replacement for `/remote-control`. See [two-usages.md](./two-usages.md).
