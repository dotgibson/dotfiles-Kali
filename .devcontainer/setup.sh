#!/usr/bin/env bash
# .devcontainer/setup.sh — provision the instant-on Kali Codespace.
# ──────────────────────────────────────────────────────────────────────────────
# Lean by design: a small modern-CLI toolset + starship, then `bootstrap.sh
# --links-only` (Core + the offensive role layer + zsh as the shell; NO apt package
# stack). The cheatsheets and field helpers are the demo — for the full engagement
# tool stack run `./bootstrap.sh` (no flag) inside the running container.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> apt: lean modern-CLI toolset"
apt-get update -qq
# Critical for the shell to come up at all — fail loudly if these don't install.
apt-get install -y --no-install-recommends \
  zsh git tmux curl ca-certificates less
# Nice-to-have CLIs that Core's aliases light up when present — best-effort, since
# Core degrades gracefully for anything missing. (Debian/Kali rename bat->batcat and
# fd-find->fdfind; Core's tools.zsh already resolves both, so no aliasing needed here.)
apt-get install -y --no-install-recommends \
  fzf ripgrep bat fd-find eza neovim jq 2>/dev/null || true

echo "==> starship prompt"
curl -fsSL https://starship.rs/install.sh | sh -s -- -y >/dev/null 2>&1 ||
  echo "   starship install skipped (offline?) — the shell still works without the prompt"

echo "==> wiring dotfiles (Core + offensive role layer, no package install)"
# --links-only skips provision() entirely (no apt, no heavy offensive stack) but runs
# wire_links: Core via blib_link_core, the offensive symlinks (hacktheplanet/exploitdev/
# evasion/ippsec + offensive.zsh), the offensive loader stage, and chsh to zsh.
./bootstrap.sh --links-only

cat <<'EOF'

  ✔ dotfiles-Kali is wired. Open a NEW terminal (it starts in zsh) and try:

      htp     hack-the-planet cheatsheet        ipp     the IppSec method
      xdev    exploit-dev companion             evade   defense-evasion
      lhost   your attacker / VPN IP            ttyup   stabilize a dumb shell
      note    timestamped engagement log        mkengagement   scope-first workspace

  Full engagement tool stack (heavy, optional):  ./bootstrap.sh
EOF
