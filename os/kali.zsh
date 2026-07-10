# dotfiles-Kali/os/kali.zsh  ->  ~/.config/zsh/os.zsh
# Kali (Debian/apt) OS-native shell layer. Loaded AFTER Core, BEFORE offensive.
# Built for WSL2: clipboard rides Core's clip (clip.exe), GUI via WSLg.
[[ $- == *i* ]] || return 0

[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
[[ -d "$HOME/.cargo/bin"  ]] && export PATH="$HOME/.cargo/bin:$PATH"

_IS_WSL=0
if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then _IS_WSL=1; fi

# clipboard -> Core's cross-OS scripts (under WSL these call clip.exe / Get-Clipboard)
command -v clip       >/dev/null && alias pbcopy='clip'
command -v clip-paste >/dev/null && alias pbpaste='clip-paste'

# ── tool completions / shell hooks (parity with the other os layers) ─────────
# direnv/gh emit DETERMINISTIC scripts (the generated hook/completion TEXT is static for a
# given binary; only the runtime hooks vary per-dir/-shell), so route them through Core's
# _cache_eval (tools.zsh) — one cheap `source` of a cached file instead of forking each
# generator on EVERY interactive shell. _cache_eval self-guards on the binary being present
# and regenerates only when it's newer than the cache. Falls back to the eager eval if
# this OS layer is sourced without Core's tools.zsh — the fallback
# keeps direnv's stderr visible, while the cached path suppresses the generator's
# stderr (as _cache_eval does); direnv's per-dir runtime warnings are unaffected.
if (( $+functions[_cache_eval] )); then
  _cache_eval direnv direnv hook zsh
  _cache_eval gh gh completion -s zsh
else
  command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
  command -v gh >/dev/null 2>&1 && eval "$(gh completion -s zsh 2>/dev/null)"
fi

alias dotsync='cd "$HOME/dotfiles-Kali"'
command -v op >/dev/null 2>&1 && alias opsignin='eval "$(op signin)"'
alias localip='ip -brief -4 addr show scope global'

# ── apt quality-of-life ────────────────────────────────────────────────────────
alias aptu='sudo apt-get update && sudo apt-get full-upgrade -y'
alias apti='sudo apt-get install -y'
alias aptr='sudo apt-get remove'
alias apts='apt-cache search'
alias aptw='dpkg -S'          # which package owns a file / command
alias aptl='dpkg -L'          # list files a package installed
alias aptshow='apt-cache show'

# ── WSL niceties ───────────────────────────────────────────────────────────────
if (( _IS_WSL )); then
  alias open='explorer.exe'
  command -v wslview >/dev/null && alias xdg-open='wslview'
  [[ -n "${WINHOME:-}" ]] && alias cdwin='cd "$WINHOME"'
fi

unset _IS_WSL

# auto-start / attach tmux (skip inside tmux, VS Code, or a non-interactive shell)
if command -v tmux >/dev/null 2>&1 && [[ -z "$TMUX" && -t 1 && "$TERM_PROGRAM" != "vscode" ]]; then
  tmux attach -t main 2>/dev/null || tmux new-session -s main
fi
