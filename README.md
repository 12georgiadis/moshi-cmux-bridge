# moshi-cmux-bridge

> A dashboard that turns an iPhone or iPad into a real entry point to your Mac. Full terminal. Real files. Your actual Claude Code workspaces, listed by their friendly cmux names. Crash-safe via `tmux-resurrect`.

Built by [Ismaël Joffroy Chandoutis](https://ismaeljoffroychandoutis.com) — artist and filmmaker. Daily-driven from a MacBook Air M3 since May 2026.

## What it does, in one sentence

Open Moshi on your phone → tap your Mac → **bam, you see a menu of your real cmux workspaces by name** ("compta", "goldberg-edit", "client-call-prep"...), pick one, you're attached.

## The 30-second demo

```
===================================================
  Dashboard — MacBook Air M3        18:42  92%
===================================================

  CMUX workspaces
    1) compta
    2) goldberg-edit
    3) client-call-prep
    4) INBOX
    5) research-foia-appeal

  Sessions tmux nommées
    6) project-alpha  [attachée]
    7) deploy-staging

  --------------------------------------------------
   c) Nettoyer les sessions orphelines
   s) Shell nu
   r) Rafraîchir
   q) Quitter

  Choix : _
```

Tap a number → attached. `Ctrl-b d` to detach → back to the menu. `q` to close.

## Why not just `/remote-control` from Anthropic?

Anthropic shipped Claude Code Remote Control in February 2026 — `/remote-control` in any Claude Code session bridges your Mac to the iPhone Claude app. It's great. It also does about 30% of what some of us need.

| Need | `/remote-control` | This bridge |
|---|---|---|
| Monitor one long Claude session from your phone | ✅ native, zero setup | ✅ |
| Full terminal (`vim`, `git`, scripts, filesystem) | ❌ Claude Code only | ✅ |
| Multiple Claude sessions in parallel | ⚠ one at a time (research preview) | ✅ N workspaces |
| Survive Mac crash + restore | ❌ session dies with the Mac | ✅ `tmux-resurrect` |
| No SSH / Tailscale to set up | ✅ | ❌ |
| Cost | Pro $20+/month | Free if you already have Tailscale or any SSH path |

**Use both.** They cover different verbs.

- `/remote-control` = "I'm **watching** Claude work on my Mac"
- This bridge = "I'm **at** my Mac, through my phone"

## Architecture

```
[iPhone / iPad mini]
         │  Mosh (over Tailscale or any SSH path)
         ▼
[Mac: SSH → .zshrc detects MOSHI_CLIENT → exec dashboard.sh]
         │
         ▼
┌────────── dashboard.sh ──────────────────────┐
│  Live read of cmux state every time it opens │
│   • ps eww of tmux new-session processes     │
│     → extract CMUX_WORKSPACE_ID from env     │
│   • cmux rpc debug.terminals                 │
│     → map UUID → friendly title              │
│   • tmux list-sessions                       │
│     → named non-cmux sessions                │
└──────────────────┬───────────────────────────┘
                   ▼
        tmux attach -t <session>
```

The key insight: **cmux gives terminals friendly names in its UI database but never propagates them to tmux session names.** This bridge reconstructs the mapping LIVE each time the menu opens, via the three sources above. No cache, no daemon, no state to maintain. Rename a workspace in cmux UI → reflected next time you open the menu.

## Prerequisites

- macOS 13+
- [Homebrew](https://brew.sh): `brew install tmux mosh jq`
- [cmux](https://cmux.com) installed at `/Applications/cmux.app/`
- A way for your phone to reach your Mac:
  - [Tailscale](https://tailscale.com) (recommended, zero-config)
  - Or any other SSH path (port forward, VPN, etc.)
- [Moshi](https://getmoshi.app) iOS app on iPhone or iPad

## Install

```bash
git clone https://github.com/12georgiadis/moshi-cmux-bridge.git
cd moshi-cmux-bridge
bash install.sh
```

What `install.sh` does:
1. Backs up your `.zshrc` to `~/.zshrc.bak-<date>`
2. Copies the 3 scripts to `~/.claude/scripts/` (or `$INSTALL_DIR` if you set it)
3. Inserts the auto-attach snippet at the top of `.zshrc`
4. Templates the launchd plist with your username and loads it
5. Tells you the test path

If something breaks: `bash ~/.claude/scripts/moshi-bridge-uninstall.sh` → full revert from the backup.

Manual install: see [INSTALL.md](INSTALL.md).

## Configuration on the iPhone side

1. Open Moshi → `Settings → Integrations → Export ENV` → turn **on** (this sets `MOSHI_CLIENT=1` on connect)
2. Add host:
   - Address: your Mac's Tailscale IP (or LAN IP)
   - User: your macOS username
   - Transport: Mosh (preferred) or SSH
3. Connect. The dashboard appears immediately.

## How crash recovery works

`tmux-continuum` auto-saves the full tmux state every 5 minutes. `tmux-resurrect` restores on tmux server start. If your Mac reboots:
- Mac comes back up
- tmux server starts (via your shell or launchd)
- continuum auto-restores all named sessions
- You connect from Moshi → dashboard shows them again, you reattach

The cleanup script is **safe by design**: it only kills `ttys*` sessions whose pane is a *truly idle* shell (`zsh`, `bash`, `sh`). If `claude`, `node`, `python`, etc. is still running in there, it's kept. You can pick up post-crash work from the dashboard. See [docs/safety.md](docs/safety.md).

## Files

- [`scripts/dashboard.sh`](scripts/dashboard.sh) — the menu
- [`scripts/cleanup-orphans.sh`](scripts/cleanup-orphans.sh) — kill orphan `ttys*` sessions safely
- [`scripts/uninstall.sh`](scripts/uninstall.sh) — one-shot revert
- [`launchd/tmux-cleanup.plist.template`](launchd/tmux-cleanup.plist.template) — auto-cleanup every 30 min (templated with `$USERNAME`)
- [`zshrc-snippet.sh`](zshrc-snippet.sh) — block to paste near the top of your `.zshrc`
- [`install.sh`](install.sh) — opinionated installer (backs up + copies + patches + loads)

## Docs

- [Two usages, clarified](docs/two-usages.md) — Moshi+dashboard vs `/remote-control`, when to pick which
- [Architecture deep dive](docs/architecture.md) — why three orthogonal tools instead of one
- [Safety: how cleanup decides what to kill](docs/safety.md)

## Compatibility

| Component | Tested version |
|---|---|
| macOS | 13, 14, 15 |
| tmux | 3.4, 3.5, 3.6 |
| mosh-server | 1.4.0 |
| cmux | 0.63, 0.64 |
| Moshi iOS | 2.6 — 2.11 |
| Tailscale | any current |

## License

MIT. Use whatever you want, no attribution required (though appreciated).

## Author

Ismaël Joffroy Chandoutis — artist and filmmaker based in Paris. I work at the intersection of cinema, AI, and contemporary art. Tools I build for my own practice get open-sourced when they generalize.

- Site: [ismaeljoffroychandoutis.com](https://ismaeljoffroychandoutis.com)
- See also: [`claude-code-setup`](https://github.com/12georgiadis/claude-code-setup) — how I use Claude Code as a filmmaker
