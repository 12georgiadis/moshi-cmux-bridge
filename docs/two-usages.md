# Two usages, clarified

There are two distinct mobile-Mac workflows in May 2026. They're complementary, not competing.

## Usage 1: `/remote-control` (Anthropic, official)

**Verb: "I'm WATCHING Claude work on my Mac."**

You start a long-running Claude Code session on your Mac (deep research, large refactor, document drafting), tap `/remote-control` inside that session, then open the Claude iOS/Android app. The session shows up on your phone. You can watch progress, approve tools, type follow-ups. Push notifications when Claude waits for you.

The Mac does an outbound poll to Anthropic's bridge — no inbound port, no SSH, no Tailscale required. Files and MCP servers never leave the Mac; only chat messages and tool results traverse the encrypted bridge.

**Strengths**
- Zero network setup
- Works through corporate firewalls
- Native iOS/Android Claude app you probably already have
- Push notifications

**Limits**
- Claude Code session only — no `vim`, `git`, shell scripts, filesystem browse
- One active session at a time (research preview as of May 2026)
- Session dies if the Mac crashes — no resurrect
- Requires Claude Pro ($20+/month) or Max plan

**When to pick it**
- You started a long Claude task at the Mac, you're leaving the desk, you want to follow it on the train
- You need zero-config mobile access and you don't care about anything else
- You only ever work in Claude Code (no scripts, no terminal life)

## Usage 2: Moshi + this bridge

**Verb: "I'm AT my Mac, through my phone."**

You open Moshi, the dashboard appears, you see all your cmux workspaces by name, you pick "compta" or "client-call-prep" and you're in. You can `vim`, `git push`, run scripts, browse files, run multiple Claude sessions in parallel, ask cmux to spawn a new project, do anything you'd do at the keyboard.

The bridge uses the standard Mosh + tmux stack (which has been mature since 2012) and adds a custom dashboard that resolves cmux's friendly workspace titles. The crash safety comes from `tmux-resurrect` + `tmux-continuum` auto-saving every 5 minutes.

**Strengths**
- Full Mac terminal access
- Multiple Claude / project sessions in parallel
- Survives Mac reboot via `tmux-resurrect`
- No subscription needed
- Works on iPhone AND iPad (Magic Keyboard ideal on iPad)

**Limits**
- Requires Tailscale or any SSH route to the Mac (one-time setup)
- Mac must be powered on
- Slightly higher friction first time you configure it (this README + install.sh = ~10 min)

**When to pick it**
- You do mixed work: compta in `vim`, Claude in another pane, a script in a third
- You want session survival across crashes
- You want to start a project from scratch on the move
- You have multiple projects and want to switch between them by name

## Use both

Run them in parallel. They're not in conflict.

- Start a long Claude task at your Mac. Hit `/remote-control`. Leave. Follow on iPhone.
- Later, you want to open `vim` to read a file, or start a *new* claude session: open Moshi, pick a workspace, work.
- Back at the Mac, both sessions are still there exactly where you left them.

The Anthropic verb is *observation*. The Moshi verb is *presence*. Use the one that matches the moment.
