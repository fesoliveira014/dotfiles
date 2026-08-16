#!/usr/bin/env bash
# Link every tracked dotfile into $HOME.
#
# The file list comes from `git ls-files`, so adding a file to the repo is all
# that is needed for it to be deployed - there is no manifest to keep in sync.
#
# Individual files are linked rather than whole directories. That matters for
# ~/.config/systemd/user, which also holds the *.wants symlinks systemd creates
# when a unit is enabled; linking the directory itself would hide them.
#
#   ./install.sh            link everything
#   ./install.sh --dry-run  print what would happen, change nothing
#
# Anything already present and not already the right link is moved into
# ./backups/<timestamp>/ first, preserving its path.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
BACKUP_DIR="$REPO/backups/$(date +%Y%m%d-%H%M%S)"

# Repo housekeeping, not configuration - these never get linked into $HOME.
readonly NOT_DOTFILES=(
    "install.sh"
    "README.md"
    ".gitignore"
)

usage() {
    sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
    exit "${1:-0}"
}

case "${1:-}" in
--dry-run | -n) DRY_RUN=1 ;;
--help | -h) usage 0 ;;
"") ;;
*)
    printf 'unknown argument: %s\n\n' "$1" >&2
    usage 2
    ;;
esac

is_excluded() {
    local candidate="$1" excluded
    for excluded in "${NOT_DOTFILES[@]}"; do
        [[ "$candidate" == "$excluded" ]] && return 0
    done
    # backups/ holds displaced files; never redeploy them.
    [[ "$candidate" == backups/* ]]
}

say() { printf '  %-9s %s\n' "$1" "$2"; }

linked=0 skipped=0 backed_up=0

cd "$REPO"
while IFS= read -r relative; do
    is_excluded "$relative" && continue

    source_path="$REPO/$relative"
    target_path="$HOME/$relative"

    # Already pointing where it should - nothing to do.
    if [[ -L "$target_path" && "$(readlink -f "$target_path")" == "$(readlink -f "$source_path")" ]]; then
        say "ok" "$relative"
        skipped=$((skipped + 1))
        continue
    fi

    if [[ -e "$target_path" || -L "$target_path" ]]; then
        say "backup" "$relative"
        if ((DRY_RUN == 0)); then
            mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
            mv "$target_path" "$BACKUP_DIR/$relative"
        fi
        backed_up=$((backed_up + 1))
    fi

    say "link" "$relative"
    if ((DRY_RUN == 0)); then
        mkdir -p "$(dirname "$target_path")"
        ln -s "$source_path" "$target_path"
    fi
    linked=$((linked + 1))
done < <(git ls-files)

printf '\n%d linked, %d already correct, %d backed up' "$linked" "$skipped" "$backed_up"
if ((DRY_RUN == 1)); then
    printf ' (dry run - nothing changed)\n'
    exit 0
fi
printf '\n'
((backed_up > 0)) && printf 'Displaced files are in %s\n' "$BACKUP_DIR"

cat <<'EOF'

Some of this only takes effect on the next login:
  - .config/environment.d/10-path.conf  (systemd user PATH)
  - .config/systemd/user/*.service      (or: systemctl --user daemon-reload)

Neovim is deliberately not here - it lives in its own repository at
~/.config/nvim, tracking the kickstart.nvim upstream.
EOF
