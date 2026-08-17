# dotfiles

Configuration for a 14" HiDPI laptop running **niri**, a scrollable-tiling
Wayland compositor, on Ubuntu 24.04.

```sh
git clone https://github.com/fesoliveira014/dotfiles ~/repos/dotfiles
cd ~/repos/dotfiles
./install.sh --dry-run   # see what it would do
./install.sh             # symlink everything into $HOME
```

`install.sh` takes its file list from `git ls-files`, so adding a file to the
repo is all that is needed to deploy it. Anything already in `$HOME` is moved
into `backups/<timestamp>/` before being replaced.

## What's here

| Path | Purpose |
| --- | --- |
| `.config/niri/` | Compositor: layout, keybindings, startup |
| `.config/waybar/` | Status bar, ayu-dark themed |
| `.config/mako/` | Notifications, and the OSD styling |
| `.config/alacritty/` | Terminal (built from source, not the apt 0.13.2) |
| `.config/systemd/user/` | `niri.service`, and the power-profile watcher |
| `.config/environment.d/` | PATH for the systemd user manager — see below |
| `.local/bin/` | Session scripts (see table below) |
| `.zshrc` / `.bashrc` | Shell, Oh My Zsh with the TUI stack wired in |
| `.Xresources`, `.config/regolith3/` | Regolith/i3 — kept as the rollback path |

### Scripts

| Script | What it does |
| --- | --- |
| `osd` | Volume, mic and brightness, drawn through mako |
| `power-profile-watch` | Sets the power profile from AC/battery state |
| `waybar-powerprofile` | waybar module for power-profiles-daemon |
| `waybar-dnd` | waybar module toggling mako do-not-disturb |
| `niri-waybar-workspaces` | Bridges niri workspaces into waybar |
| `niri-waybar-window` | Bridges the focused window title into waybar |
| `niri-session` | Session entry point used by the display manager |

## Things that will bite you

**The systemd user manager does not read shell rc files.** Its PATH omits
`~/.local/bin` and `~/go/bin`. niri is started by systemd, so everything niri
spawns inherits that PATH — a `spawn "foo"` for anything in those directories
fails silently. `.config/environment.d/10-path.conf` fixes this at login;
absolute paths are used in `config.kdl` regardless, as a second line of defence.

**Brightness needs the `video` group.**
`/sys/class/backlight/*/brightness` is `root:video` mode 664:

```sh
sudo usermod -aG video "$USER"   # then log out and back in
```

**`.config/systemd/user/waybar.service` is a symlink to `/dev/null`, on
purpose.** Ubuntu ships `/usr/lib/systemd/user/waybar.service` and enables it
from `/etc/systemd/user/graphical-session.target.wants/`, which is system-owned
and so cannot be removed with `systemctl --user disable`. Left alone it starts a
second waybar alongside niri's `spawn-at-startup`, giving two stacked bars on
every monitor. Masking it at user level is what keeps the session described in
`config.kdl` alone. systemd honours the mask through `install.sh`'s extra
symlink hop.

**waybar draws one bar per output.** There is no `"output"` key in
`config.jsonc`, so with two monitors connected you get two bars and *four*
bridge script chains — one pair of `niri msg event-stream` subscriptions per
bar. That is expected, not a leak.

**waybar 0.9.24 has no niri modules and no `power-profiles-daemon` module.**
Hence the four bridge scripts. On a newer waybar, delete
`niri-waybar-workspaces` and `niri-waybar-window` and use the native
`niri/workspaces` and `niri/window` modules instead.

**Display scaling is 1.8, not 1.75.** 2880/1.8 = 1600 exactly; 1.75 gives
1645.71, which is not a whole number of pixels. The next roomier clean stop is
1.6 → 1800x1125.

## Not here

**Neovim** lives in its own repository at `~/.config/nvim`, tracking the
[kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) upstream. Keeping
it separate preserves that fork relationship.

`.git-credentials` is gitignored. `.gitconfig` sets `credential.helper = store`,
which writes tokens to that file **in plaintext** — worth replacing with
`libsecret` at some point.
