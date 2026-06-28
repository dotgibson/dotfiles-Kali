#!/usr/bin/env bash
# Install htpx standalone (no dotfiles required). Symlinks a thin wrapper onto PATH
# so htpx resolves its entries/ relative to THIS checkout.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd)"
BIN="${HOME}/.local/bin"
mkdir -p "$BIN"
cat > "$BIN/htpx" <<EOF
#!/usr/bin/env bash
exec "$REPO/htpx" "\$@"
EOF
chmod +x "$BIN/htpx"
echo "installed: $BIN/htpx -> $REPO/htpx"
echo "ensure $BIN is on your PATH; deps: fzf (required), bat + a clipboard tool (optional)"
