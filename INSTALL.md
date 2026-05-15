# Manual install

If you'd rather not run `install.sh`, here are the explicit steps.

## Prerequisites

```bash
brew install tmux mosh jq
```

Install [cmux](https://cmux.com), [Tailscale](https://tailscale.com) (recommended), and [Moshi iOS](https://getmoshi.app).

Enable SSH Remote Login: `System Settings → General → Sharing → Remote Login` → ON.

In Moshi iOS: `Settings → Integrations → Export ENV` → ON.

## tmux plugins (for crash safety)

If you don't already have tmux-resurrect + tmux-continuum:

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Add to your `~/.tmux.conf`:

```tmux
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'
set -g @continuum-save-interval '5'
run '~/.tmux/plugins/tpm/tpm'
```

Reload tmux, then press `prefix + I` to install plugins.

## Install scripts

```bash
INSTALL_DIR="$HOME/.claude/scripts"
LOG_DIR="$HOME/.claude/logs"
mkdir -p "$INSTALL_DIR" "$LOG_DIR"

cp scripts/dashboard.sh        "$INSTALL_DIR/dashboard.sh"
cp scripts/cleanup-orphans.sh  "$INSTALL_DIR/cleanup-orphans.sh"
cp scripts/uninstall.sh        "$INSTALL_DIR/moshi-bridge-uninstall.sh"
chmod +x "$INSTALL_DIR"/dashboard.sh "$INSTALL_DIR"/cleanup-orphans.sh "$INSTALL_DIR"/moshi-bridge-uninstall.sh
```

## Patch .zshrc

Back up first:

```bash
cp ~/.zshrc ~/.zshrc.bak-$(date +%Y-%m-%d)
```

Paste this near the TOP of your `~/.zshrc`, BEFORE any auto-tmux block:

```bash
# moshi-cmux-bridge: auto-attach when launched from Moshi
if [ -n "$MOSHI_CLIENT" ] && [ -z "$TMUX" ] && [ -t 0 ]; then
  exec "$HOME/.claude/scripts/dashboard.sh"
fi

# manual menu from any shell
s() { "$HOME/.claude/scripts/dashboard.sh"; }
```

Validate: `zsh -n ~/.zshrc && echo OK`.

## Templated launchd agent

```bash
LAUNCHD_LABEL="com.$(whoami).moshi-cmux-bridge.cleanup"
PLIST="$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"

sed -e "s|__LAUNCHD_LABEL__|$LAUNCHD_LABEL|g" \
    -e "s|__INSTALL_DIR__|$INSTALL_DIR|g" \
    -e "s|__LOG_DIR__|$LOG_DIR|g" \
    launchd/tmux-cleanup.plist.template > "$PLIST"

launchctl load "$PLIST"
launchctl list | grep "$LAUNCHD_LABEL"
```

## Test

```bash
zsh -n ~/.zshrc && echo zsh OK
bash -n "$INSTALL_DIR/dashboard.sh" && echo dashboard OK
bash "$INSTALL_DIR/cleanup-orphans.sh"  # dry-test
```

From your iPhone or iPad: open Moshi, connect to your Mac. The dashboard should appear.

## Revert

If you used `install.sh`:

```bash
bash ~/.claude/scripts/moshi-bridge-uninstall.sh
```

If you installed manually: restore your `.zshrc` backup, `launchctl unload <PLIST>`, remove the three scripts and the plist.
