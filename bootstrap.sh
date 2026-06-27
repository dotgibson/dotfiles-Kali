#!/usr/bin/env bash
# dotfiles-Kali/bootstrap.sh
# Provision a Kali (Debian-family, apt) box — built for WSL2 — and wire dotfiles.
# Idempotent. Stacks three layers: vendored Core + apt OS-native + OFFENSIVE role.
# The shared symlink/loader/login-shell scaffold lives in core/lib/bootstrap-lib.sh.
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
  --links-only) LINKS_ONLY=1 ;;
  --no-offensive) DO_OFFENSIVE=0 ;;
  -h | --help) sed -n '2,9p' "$0"; exit 0 ;;
  *) echo "unknown arg: $a" >&2; exit 1 ;;
esac; done

# ── core/ subtree present? (inline: can't source a lib out of core/ before this) ─
# Validate the SPECIFIC paths we depend on (zsh modules + the two libs sourced
# next) so a missing/partial subtree fails HERE with a precise message, not later
# with a cryptic `source: No such file`.
for _req in core/zsh/loader.zsh core/lib/ux.sh core/lib/bootstrap-lib.sh; do
  if [[ ! -e "$DOTFILES/$_req" ]]; then
    echo "core/ subtree missing or incomplete (need $_req). One-time, run:" >&2
    echo "  git subtree add  --prefix=core <dotfiles-core remote> main --squash   # first time" >&2
    echo "  git subtree pull --prefix=core <dotfiles-core remote> main --squash   # to update" >&2
    exit 1
  fi
done
unset _req

# Shared bash UX palette + provisioning scaffold (vendored under core/lib).
# shellcheck source=core/lib/ux.sh
source "$DOTFILES/core/lib/ux.sh"
# shellcheck source=core/lib/bootstrap-lib.sh
source "$DOTFILES/core/lib/bootstrap-lib.sh"

# ── sanity: confirm this is Kali ──────────────────────────────────────────────
if ! grep -qE '^ID=kali' /etc/os-release 2>/dev/null; then
  echo "This bootstrap targets Kali Linux (expects ID=kali in /etc/os-release)." >&2
  exit 1
fi

IS_WSL=0
if blib_is_wsl; then IS_WSL=1; fi

apt_install() { # resilient: bulk first, then per-package (apt aborts on one bad name)
  local -a pkgs=("$@")
  if sudo apt-get install -y --no-install-recommends "${pkgs[@]}"; then return 0; fi
  blib_say "bulk install hit a snag — retrying package-by-package"
  local p
  for p in "${pkgs[@]}"; do
    sudo apt-get install -y "$p" || echo "   skipped (unavailable on this box?): $p"
  done
}

provision() {
  export DEBIAN_FRONTEND=noninteractive
  blib_say "apt update + full-upgrade"
  sudo apt-get update
  sudo apt-get full-upgrade -y

  blib_say "apt base CLI stack (install/packages.txt)"
  local -a base=()
  mapfile -t base < <(blib_read_pkgs "$DOTFILES/install/packages.txt")
  apt_install "${base[@]}"
  blib_ok "base packages requested: ${#base[@]}"

  if ((DO_OFFENSIVE)) && [[ -f "$DOTFILES/install/offensive-packages.txt" ]]; then
    blib_say "offensive tool stack (install/offensive-packages.txt) — heavy, go get coffee"
    local -a off=()
    mapfile -t off < <(blib_read_pkgs "$DOTFILES/install/offensive-packages.txt")
    apt_install "${off[@]}"
    blib_ok "offensive packages requested: ${#off[@]}"
  else
    blib_say "skipping offensive tool install (--no-offensive)"
  fi

  # Tools not reliably in apt — upstream installers (same approach as dotfiles-Fedora).
  # These print progress on purpose: atuin/yazi can fall back to a (silent, multi-minute)
  # source build, and a suppressed installer looks like a hang. '|| true' keeps each one
  # non-fatal — they're all HAVE_*-guarded, so the shell works without them.
  command -v starship >/dev/null || { blib_say "starship (installer)"; curl -fsSL https://starship.rs/install.sh | sh -s -- -y || true; }
  command -v atuin >/dev/null || { blib_say "atuin (installer — may compile from source, be patient)"; curl -fsSL https://setup.atuin.sh | sh || true; }
  if ! command -v mise >/dev/null && [[ ! -x "$HOME/.local/bin/mise" ]]; then
    blib_say "mise (installer)"
    curl -fsSL https://mise.run | sh || true
  fi
  if ! command -v yazi >/dev/null && command -v cargo >/dev/null; then
    # yazi-fm/yazi-cli can't be installed directly from crates.io (their build.rs panics);
    # upstream requires the yazi-build orchestrator, which pulls in both binaries.
    blib_say "yazi (cargo build from source — several minutes, output below)"
    cargo install --force yazi-build || true
  fi
  # uv — Astral's Python package/project manager (not in apt). Installs to ~/.local/bin.
  if ! command -v uv >/dev/null && [[ ! -x "$HOME/.local/bin/uv" ]]; then
    blib_say "uv (installer)"
    curl -fsSL https://astral.sh/uv/install.sh | sh || true
  fi
  # ty — Astral's fast type checker (not in apt). Prefer `uv tool install` when uv is
  # present; fall back to the standalone installer otherwise.
  if ! command -v ty >/dev/null && [[ ! -x "$HOME/.local/bin/ty" ]]; then
    local uv_bin
    uv_bin="$(command -v uv || echo "$HOME/.local/bin/uv")"
    if [[ -x "$uv_bin" ]]; then
      blib_say "ty (via uv tool install)"
      "$uv_bin" tool install ty || true
    else
      blib_say "ty (installer)"
      curl -fsSL https://astral.sh/ty/install.sh | sh || true
    fi
  fi

  if ((IS_WSL)); then
    blib_say "installing /etc/wsl.conf (systemd + default user + interop)"
    local user
    user="$(id -un)"
    sed "s/__WSL_USER__/$user/" "$DOTFILES/wsl/wsl.conf" | sudo tee /etc/wsl.conf >/dev/null
    blib_ok "wsl.conf written. From Windows: 'wsl.exe --shutdown', then reopen Kali."
    blib_say "NOTE: reverse-shell reachability needs mirrored networking — see wsl/windows.wslconfig.example"
  fi
}

wire_links() {
  # Shared Core surface + the Kali OS overlays, both from core/lib/bootstrap-lib.sh.
  blib_link_core "$DOTFILES" "$CONFIG"
  blib_link_os_layer "$DOTFILES" "$CONFIG" kali

  # ── OFFENSIVE role layer (unique to this repo) ──────────────────────────────
  blib_say "symlinking OFFENSIVE role layer"
  blib_link "$DOTFILES/offensive/offensive.zsh" "$CONFIG/zsh/offensive.zsh"
  [[ -d "$DOTFILES/offensive/templates" ]] && blib_link "$DOTFILES/offensive/templates" "$CONFIG/kali/templates"
  # CTF/HTB cheatsheet + companion field references — surfaced at ~/ for htp/xdev/evade/ipp.
  [[ -f "$DOTFILES/offensive/hacktheplanet" ]] && blib_link "$DOTFILES/offensive/hacktheplanet" "$HOME/hacktheplanet"
  [[ -f "$DOTFILES/offensive/exploitdev" ]] && blib_link "$DOTFILES/offensive/exploitdev" "$HOME/exploitdev"
  [[ -f "$DOTFILES/offensive/evasion" ]] && blib_link "$DOTFILES/offensive/evasion" "$HOME/evasion"
  [[ -f "$DOTFILES/offensive/ippsec" ]] && blib_link "$DOTFILES/offensive/ippsec" "$HOME/ippsec"
  # The structured red<->blue companion (the `htpx` browser + its entries/ tree).
  # Linked as a directory so htpx resolves entries/ relative to itself; run via `htpx`.
  [[ -d "$DOTFILES/offensive/companion" ]] && blib_link "$DOTFILES/offensive/companion" "$HOME/companion"

  # The managed .zshrc loader — Kali adds the `offensive` stage just before `local`.
  blib_write_zshrc_loader tools ui options history aliases git functions fzf bindings plugins op maint update os offensive local

  # A login zsh configured the XDG way reads $ZDOTDIR/.zshrc, NOT $HOME/.zshrc. With
  # the entry loader only at $HOME, a fresh login window keys its new-user check off
  # the (absent) $ZDOTDIR/.zshrc and fires zsh-newuser-install before our rc loads.
  # Mirror the entry into ZDOTDIR so both lookup paths resolve to the same loader.
  blib_link "$HOME/.zshrc" "$CONFIG/zsh/.zshrc"

  blib_set_login_shell
  blib_ok "symlinks wired"
}

((LINKS_ONLY)) || provision
wire_links
blib_ok "Kali bootstrap complete — open a new shell, or: exec zsh"
