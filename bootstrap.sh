#!/usr/bin/env bash
# dotfiles-Kali/bootstrap.sh
# Provision a Kali (Debian-family, apt) box — built for WSL2 — and wire dotfiles.
# Idempotent. Stacks three layers: vendored Core + apt OS-native + OFFENSIVE role.
# The shared symlink/loader/login-shell scaffold lives in core/lib/bootstrap-lib.sh.
#
#   ./bootstrap.sh                 # full: apt base + offensive tools + symlinks
#   ./bootstrap.sh --links-only    # just (re)create symlinks (no apt)
#   ./bootstrap.sh --no-offensive  # base + symlinks, skip the heavy tool install
#   ./bootstrap.sh --only zsh,nvim # link ONLY these Core module groups
#   ./bootstrap.sh --skip tmux     # link everything EXCEPT these groups
#
# Module groups (for --only/--skip): zsh nvim tmux git prompt tools — Core wiring
# only; the offensive role layer is separate (governed by --no-offensive).
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
LINKS_ONLY=0
DO_OFFENSIVE=1
# --only/--skip are validated by the shared lib (blib_select), sourced AFTER this
# loop — capture the raw values now and apply them below.
ONLY_RAW="" SKIP_RAW="" ONLY_SEEN=0 SKIP_SEEN=0

while [[ $# -gt 0 ]]; do case "$1" in
  --links-only) LINKS_ONLY=1 ;;
  --no-offensive) DO_OFFENSIVE=0 ;;
  --only) [[ $# -ge 2 ]] || { echo "--only requires module names, e.g. --only zsh,nvim" >&2; exit 1; }; ONLY_RAW="$2"; ONLY_SEEN=1; shift ;;
  --only=*) ONLY_RAW="${1#*=}"; ONLY_SEEN=1 ;;
  --skip) [[ $# -ge 2 ]] || { echo "--skip requires module names, e.g. --skip tmux" >&2; exit 1; }; SKIP_RAW="$2"; SKIP_SEEN=1; shift ;;
  --skip=*) SKIP_RAW="${1#*=}"; SKIP_SEEN=1 ;;
  -h | --help) sed -n '2,14p' "$0"; exit 0 ;;
  *) echo "unknown arg: $1" >&2; exit 1 ;;
esac; shift; done

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

# Apply any --only/--skip module selection now the validator (blib_select) exists;
# it aborts on a malformed selector or an unknown group.
if ((ONLY_SEEN)); then blib_select --only "$ONLY_RAW"; fi
if ((SKIP_SEEN)); then blib_select --skip "$SKIP_RAW"; fi

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

_dotfiles_go_install() { # <import-path@version> <binary-name>
  # go install drops binaries in ~/go/bin, which the shell layer does NOT put on
  # PATH (it prefixes ~/.local/bin and ~/.cargo/bin) — so pin GOBIN to ~/.local/bin
  # or the tool would still read as "missing" after bootstrap.
  [ "$#" -ge 2 ] || return 0
  if command -v "$2" >/dev/null 2>&1; then return 0; fi
  local gobin="$HOME/.local/bin"
  mkdir -p "$gobin" 2>/dev/null || true
  if command -v go >/dev/null 2>&1; then
    GOBIN="$gobin" go install "$1" >/dev/null 2>&1 ||
      echo "   $2: go install failed — retry later: GOBIN=$gobin go install $1"
  elif command -v mise >/dev/null 2>&1; then
    GOBIN="$gobin" mise exec go@latest -- go install "$1" >/dev/null 2>&1 ||
      echo "   $2: go install failed — retry later: GOBIN=$gobin go install $1"
  else
    echo "   $2: needs Go — install later with: GOBIN=$gobin go install $1"
  fi
  return 0
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
  # viddy (watch replacement; Core aliases watch->viddy, HAVE_VIDDY-guarded) is a Rust
  # CLI, not in Debian/Kali apt — build from source via cargo.
  if ! command -v viddy >/dev/null && command -v cargo >/dev/null; then
    blib_say "viddy (cargo — watch replacement; not in apt)"
    cargo install --locked viddy >/dev/null 2>&1 || true
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

  # The remaining core-doctor tools that aren't reliably in apt: doggo/carapace/sesh
  # are go binaries; op is 1Password's signed apt repo. All presence-guarded and
  # best-effort ('|| true') — they're HAVE_*-guarded in the shell, so a failure here
  # never aborts bootstrap (and never trips set -e).
  command -v doggo >/dev/null 2>&1 || { blib_say "doggo (go install)"; _dotfiles_go_install github.com/mr-karan/doggo/cmd/doggo@latest doggo; }
  command -v carapace >/dev/null 2>&1 || { blib_say "carapace (go install — not in Debian)"; _dotfiles_go_install github.com/carapace-sh/carapace-bin/cmd/carapace@latest carapace; }
  command -v sesh >/dev/null 2>&1 || { blib_say "sesh (go install — /v2 module path)"; _dotfiles_go_install github.com/joshmedeski/sesh/v2@latest sesh; }

  # op — 1Password CLI, from 1Password's official signed apt repo. Whole block is
  # guarded on `command -v op` and each step is best-effort so it can't abort bootstrap.
  if ! command -v op >/dev/null 2>&1; then
    blib_say "op (1Password CLI — official signed apt repo)"
    sudo mkdir -p /usr/share/keyrings
    curl -fsSL https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
    # The repo file is written before `apt-get update`; if update OR install fails,
    # a stale entry would wedge every future `apt-get update`. Roll it back on failure.
    if ! (sudo apt-get update && sudo apt-get install -y 1password-cli); then
      sudo rm -f /etc/apt/sources.list.d/1password.list /usr/share/keyrings/1password-archive-keyring.gpg
      echo "   op install failed — repo entry rolled back; see developer.1password.com/docs/cli/get-started"
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
  # The `prefix + e` engagement-session popup (os/kali.conf). It CANNOT live under
  # $CONFIG/tmux/scripts — that path is a whole-dir symlink to core/tmux/scripts (Core-
  # owned, no offensive script) — so link it a level up, beside tmux.conf, and the
  # binding points there. Gated on `blib_want tmux` so `--skip tmux` / `--only …` behave
  # consistently with how Core wires its own tmux files.
  blib_want tmux && [[ -f "$DOTFILES/offensive/tmux/tmux-eng.sh" ]] && blib_link "$DOTFILES/offensive/tmux/tmux-eng.sh" "$CONFIG/tmux/tmux-eng.sh"
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
  # Part of the zsh group — skip it when zsh isn't being wired (--only/--skip).
  if blib_want zsh; then blib_link "$HOME/.zshrc" "$CONFIG/zsh/.zshrc"; fi

  blib_set_login_shell
  blib_ok "symlinks wired$(blib_selected_note)"
}

((LINKS_ONLY)) || provision
wire_links
blib_ok "Kali bootstrap complete — open a new shell, or: exec zsh"
