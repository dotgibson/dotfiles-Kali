#!/usr/bin/env bash
# dotfiles-Kali/bootstrap.sh
# Provision a Kali (Debian-family, apt) box — built for WSL2 — and wire dotfiles.
# Idempotent. Stacks three layers: vendored Core + apt OS-native + OFFENSIVE role.
#
#   ./bootstrap.sh                 # full: apt base + offensive tools + symlinks
#   ./bootstrap.sh --links-only    # just (re)create symlinks (no apt)
#   ./bootstrap.sh --no-offensive  # base + symlinks, skip the heavy tool install
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
LINKS_ONLY=0
DO_OFFENSIVE=1

for a in "$@"; do case "$a" in
  --links-only)   LINKS_ONLY=1 ;;
  --no-offensive) DO_OFFENSIVE=0 ;;
  -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
  *) echo "unknown arg: $a" >&2; exit 1 ;;
esac; done

say(){ printf '\e[36m::\e[0m %s\n' "$*"; }
ok(){  printf '\e[32m+\e[0m %s\n'  "$*"; }

# ── detect WSL ────────────────────────────────────────────────────────────────
IS_WSL=0
if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  IS_WSL=1
fi

# ── sanity: confirm this is Kali ──────────────────────────────────────────────
if ! grep -qE '^ID=kali' /etc/os-release 2>/dev/null; then
  echo "This bootstrap targets Kali Linux (expects ID=kali in /etc/os-release)." >&2
  exit 1
fi

# ── core/ subtree present? ────────────────────────────────────────────────────
if [[ ! -d "$DOTFILES/core/zsh" ]]; then
  echo "core/ subtree missing. One time, from the repo root run:" >&2
  echo "  git subtree add --prefix=core <dotfiles-core remote> main --squash" >&2
  exit 1
fi

link(){
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then rm -f "$dst"
  elif [[ -e "$dst" ]]; then mv "$dst" "$dst.pre-dotfiles.$(date +%s)"; fi
  ln -s "$src" "$dst"
}

read_pkgs(){  # strip comments + blank lines from a package list
  local line
  while IFS= read -r line; do
    line="${line%%#*}"; line="${line//[[:space:]]/}"
    [[ -n "$line" ]] && printf '%s\n' "$line"
  done < "$1"
}

apt_install(){  # resilient: bulk first, then per-package (apt aborts on one bad name)
  local -a pkgs=("$@")
  if sudo apt-get install -y --no-install-recommends "${pkgs[@]}"; then return 0; fi
  say "bulk install hit a snag — retrying package-by-package"
  local p
  for p in "${pkgs[@]}"; do
    sudo apt-get install -y "$p" || echo "   skipped (unavailable on this box?): $p"
  done
}

provision(){
  export DEBIAN_FRONTEND=noninteractive
  say "apt update + full-upgrade"
  sudo apt-get update
  sudo apt-get full-upgrade -y

  say "apt base CLI stack (install/packages.txt)"
  local -a base=(); mapfile -t base < <(read_pkgs "$DOTFILES/install/packages.txt")
  apt_install "${base[@]}"
  ok "base packages requested: ${#base[@]}"

  if (( DO_OFFENSIVE )) && [[ -f "$DOTFILES/install/offensive-packages.txt" ]]; then
    say "offensive tool stack (install/offensive-packages.txt) — heavy, go get coffee"
    local -a off=(); mapfile -t off < <(read_pkgs "$DOTFILES/install/offensive-packages.txt")
    apt_install "${off[@]}"
    ok "offensive packages requested: ${#off[@]}"
  else
    say "skipping offensive tool install (--no-offensive)"
  fi

  # Tools not reliably in apt — upstream installers (same approach as dotfiles-Fedora).
  # These print progress on purpose: atuin/yazi can fall back to a (silent, multi-minute)
  # source build, and a suppressed installer looks like a hang. '|| true' keeps each one
  # non-fatal — they're all HAVE_*-guarded, so the shell works without them.
  command -v starship >/dev/null || { say "starship (installer)"; curl -fsSL https://starship.rs/install.sh | sh -s -- -y || true; }
  command -v atuin    >/dev/null || { say "atuin (installer — may compile from source, be patient)"; curl -fsSL https://setup.atuin.sh | sh || true; }
  if ! command -v mise >/dev/null && [[ ! -x "$HOME/.local/bin/mise" ]]; then
    say "mise (installer)"; curl -fsSL https://mise.run | sh || true
  fi
  if ! command -v yazi >/dev/null && command -v cargo >/dev/null; then
    say "yazi (cargo build from source — several minutes, output below)"; cargo install --locked yazi-fs yazi-cli || true
  fi

  if (( IS_WSL )); then
    say "installing /etc/wsl.conf (systemd + default user + interop)"
    local user; user="$(id -un)"
    sed "s/__WSL_USER__/$user/" "$DOTFILES/wsl/wsl.conf" | sudo tee /etc/wsl.conf >/dev/null
    ok "wsl.conf written. From Windows: 'wsl.exe --shutdown', then reopen Kali."
    say "NOTE: reverse-shell reachability needs mirrored networking — see wsl/windows.wslconfig.example"
  fi
}

wire_links(){
  say "symlinking Core"
  for f in "$DOTFILES"/core/zsh/*.zsh; do link "$f" "$CONFIG/zsh/$(basename "$f")"; done
  [[ -f "$DOTFILES/core/tmux/tmux.conf" ]] && link "$DOTFILES/core/tmux/tmux.conf" "$CONFIG/tmux/tmux.conf"
  [[ -f "$DOTFILES/core/tmux/tmux.reset.conf" ]] && link "$DOTFILES/core/tmux/tmux.reset.conf" "$CONFIG/tmux/tmux.reset.conf"
  if [[ -d "$DOTFILES/core/tmux/scripts" ]]; then
    link "$DOTFILES/core/tmux/scripts" "$CONFIG/tmux/scripts"
    chmod +x "$DOTFILES"/core/tmux/scripts/*.sh 2>/dev/null || true
  fi
  [[ -f "$DOTFILES/os/kali.conf" ]] && link "$DOTFILES/os/kali.conf" "$CONFIG/tmux/os.conf"
  if [[ ! -d "$CONFIG/tmux/plugins/tpm" ]]; then
    say "cloning tpm"
    git clone --depth=1 https://github.com/tmux-plugins/tpm "$CONFIG/tmux/plugins/tpm" >/dev/null 2>&1 \
      && ok "tpm cloned — run prefix + I inside tmux to fetch plugins" || say "tpm clone failed — clone it manually"
  fi
  [[ -f "$DOTFILES/core/starship/starship.toml" ]] && link "$DOTFILES/core/starship/starship.toml" "$CONFIG/starship.toml"
  [[ -d "$DOTFILES/core/nvim" ]] && link "$DOTFILES/core/nvim" "$CONFIG/nvim"
  [[ -f "$DOTFILES/core/mise/config.toml" ]] && link "$DOTFILES/core/mise/config.toml" "$CONFIG/mise/config.toml"
  [[ -f "$DOTFILES/core/git/gitconfig" ]] && link "$DOTFILES/core/git/gitconfig" "$HOME/.gitconfig"
  [[ -f "$DOTFILES/os/kali.gitconfig" ]] && link "$DOTFILES/os/kali.gitconfig" "$CONFIG/git/os.gitconfig"
  if [[ ! -f "$CONFIG/git/local.gitconfig" && -f "$DOTFILES/core/git/local.gitconfig.example" ]]; then
    mkdir -p "$CONFIG/git"; cp "$DOTFILES/core/git/local.gitconfig.example" "$CONFIG/git/local.gitconfig"
    say "seeded ~/.config/git/local.gitconfig — FILL IN your name & email"
  fi
  # cross-OS clipboard scripts (clip uses clip.exe under WSL)
  if [[ -d "$DOTFILES/core/bin" ]]; then
    mkdir -p "$HOME/.local/bin"
    for s in clip clip-paste; do
      [[ -f "$DOTFILES/core/bin/$s" ]] && { link "$DOTFILES/core/bin/$s" "$HOME/.local/bin/$s"; chmod +x "$DOTFILES/core/bin/$s" 2>/dev/null || true; }
    done
  fi
  # ssh
  if [[ -f "$DOTFILES/ssh/config" ]]; then
    say "symlinking ssh/config"
    mkdir -p "$HOME/.ssh/sockets"; chmod 700 "$HOME/.ssh" "$HOME/.ssh/sockets"
    chmod 600 "$DOTFILES/ssh/config" 2>/dev/null || true
    link "$DOTFILES/ssh/config" "$HOME/.ssh/config"
  fi

  say "symlinking Kali OS-native layer"
  link "$DOTFILES/os/kali.zsh" "$CONFIG/zsh/os.zsh"

  say "symlinking OFFENSIVE role layer"
  link "$DOTFILES/offensive/offensive.zsh" "$CONFIG/zsh/offensive.zsh"
  [[ -d "$DOTFILES/offensive/templates" ]] && link "$DOTFILES/offensive/templates" "$CONFIG/kali/templates"
  # CTF/HTB command cheatsheet — surfaced at ~/hacktheplanet for `vim ~/hacktheplanet`
  [[ -f "$DOTFILES/offensive/hacktheplanet" ]] && link "$DOTFILES/offensive/hacktheplanet" "$HOME/hacktheplanet"
  # Companion field references (same fold style) — surfaced at ~/ for `xdev` / `evade`
  [[ -f "$DOTFILES/offensive/exploitdev" ]] && link "$DOTFILES/offensive/exploitdev" "$HOME/exploitdev"
  [[ -f "$DOTFILES/offensive/evasion" ]] && link "$DOTFILES/offensive/evasion" "$HOME/evasion"
  # The IppSec method (workflow + signature moves) — surfaced at ~/ for `ipp`
  [[ -f "$DOTFILES/offensive/ippsec" ]] && link "$DOTFILES/offensive/ippsec" "$HOME/ippsec"

  if [[ ! -f "$HOME/.zshrc" ]] || ! grep -q "dotfiles-managed v2" "$HOME/.zshrc" 2>/dev/null; then
    say "writing .zshrc loader (adds the 'offensive' stage)"
    [[ -f "$HOME/.zshrc" ]] && cp "$HOME/.zshrc" "$HOME/.zshrc.pre-dotfiles.$(date +%s)"
    cat > "$HOME/.zshrc" <<'ZRC'
# dotfiles-managed v2 — do not hand-edit; local tweaks go in ~/.config/zsh/local.zsh
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
export EDITOR=nvim VISUAL=nvim

# ── Core modules -> Kali os -> OFFENSIVE -> local, in canonical order ────────
# history.zsh owns HISTFILE/HISTSIZE + history setopts; options.zsh owns the nav/glob
# setopts + compinit + completion zstyles — so this entry file no longer hand-rolls
# them. It declares the load order and sources the vendored Core loader
# (core/zsh/loader.zsh -> $ZSH_CFG/loader.zsh). `offensive` is unique to this repo and
# slots in just before local overrides. Loading the FULL Core set (ui/git/maint/update
# were silently missing) is the fix.
: "${ZDOTDIR:=$XDG_CONFIG_HOME/zsh}"
export ZDOTDIR              # Core modules (history/options) key state off ZDOTDIR;
ZSH_CFG="$ZDOTDIR"          # align the loader to the SAME dir so state never splits
_CORE_MODULES=(tools ui options history aliases git functions fzf bindings plugins op maint update os offensive local)
if [[ -r "$ZSH_CFG/loader.zsh" ]]; then
  source "$ZSH_CFG/loader.zsh"
else
  print -u2 -- "zshrc: Core loader not found at $ZSH_CFG/loader.zsh — re-run the dotfiles bootstrap to (re)link Core."
fi
unset _CORE_MODULES
ZRC
  fi

  if command -v zsh >/dev/null; then
    local zsh_path; zsh_path="$(command -v zsh)"
    if ! getent passwd "$USER" | grep -q ":$zsh_path$"; then
      say "setting zsh as default login shell"
      grep -qxF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
      sudo chsh -s "$zsh_path" "$USER" && ok "default shell -> zsh (takes effect on next login)"
    fi
  fi
  ok "symlinks wired"
}

(( LINKS_ONLY )) || provision
wire_links
ok "Kali bootstrap complete — open a new shell, or: exec zsh"
