#!/usr/bin/env bash
# tmux-eng.sh — fuzzy-find an engagement and create/switch to its tmux session.
# The offensive-layer twin of Core's tmux-sessionizer.sh.
# Bound to: prefix + e   (in dotfiles-Kali os/kali.conf — the `offensive` bits)
#
# Switch-only by design: NEW engagements are created with `mkengagement` in a
# shell (it opens scope/scope.txt in your editor first). This popup just gets you
# back into an existing one fast. The session is rooted at the engagement dir and
# its $ENGAGEMENT env var is set, so `bhce` / `logshell` target the right tree.

# Honor the env if the shell exported it; else fall back to the Core default.
ENGAGEMENTS_DIR="${ENGAGEMENTS_DIR:-$HOME/engagements}"

if [[ ! -d "$ENGAGEMENTS_DIR" ]]; then
	echo "No engagements dir at $ENGAGEMENTS_DIR — run 'mkengagement <name>' first."
	read -r -p "Press enter to close…" _
	exit 0
fi

# Newest first; preview the scope sheet (the thing you actually want to see).
selected=$(find "$ENGAGEMENTS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
	sort -r |
	fzf \
		--prompt="Engagement ❯ " \
		--preview="bat --color=always --style=plain {}/scope/scope.txt 2>/dev/null || eza --icons --tree --level=1 {}" \
		--preview-window="right:55%:wrap:border-left")

[[ -z "$selected" ]] && exit 0

# Session name from the dir basename (already date-prefixed by mkengagement).
session_name=$(basename "$selected" | tr '[:upper:] .' '[:lower:]__')

if ! tmux has-session -t "$session_name" 2>/dev/null; then
	tmux new-session -ds "$session_name" -c "$selected"
	# Make $ENGAGEMENT available to panes/windows opened in this session.
	tmux set-environment -t "$session_name" ENGAGEMENT "$selected"
fi

tmux switch-client -t "$session_name"
