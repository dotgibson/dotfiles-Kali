# dotfiles-Kali/offensive/offensive.zsh
# ──────────────────────────────────────────────────────────────────────────────
# The OFFENSIVE layer. Sourced by the Kali .zshrc loader in the dedicated stage:
#   tools → aliases → functions → fzf → bindings → plugins → op → os → OFFENSIVE → local
# (PORTING-MATRIX.md: Kali adds the `offensive` stage that no other repo has.)
#
# Same discipline as Core: every alias/function touching an optional tool is
# GUARDED by a HAVE_* flag, so this file is inert on a box where the tool isn't
# installed instead of erroring on shell start. Nothing here is target-specific
# — it's tool ergonomics + engagement scaffolding only.
#
# ⚠ SCOPE: every tool below is for AUTHORIZED engagements with written ROE only.
#   `mkengagement` seeds a scope.txt FIRST for exactly this reason.
#
# Engagement DATA never lives in this repo — it lives in $ENGAGEMENTS_DIR
# (default ~/engagements), which the repo .gitignore also blocks as a backstop.
# ──────────────────────────────────────────────────────────────────────────────

# Interactive shells only — scripts get raw POSIX (mirrors Core's tools.zsh).
[[ $- == *i* ]] || return 0

_have() { command -v "$1" >/dev/null 2>&1; }

# ── Detection: HAVE_* flags for the offensive stack ───────────────────────────
# Network / AD
_have nxc          && HAVE_NXC=1            # NetExec — CrackMapExec's successor
_have nmap         && HAVE_NMAP=1
_have responder    && HAVE_RESPONDER=1
_have evil-winrm   && HAVE_EVILWINRM=1
_have certipy-ad   && HAVE_CERTIPY=1        # AD CS abuse (ESC1-ESC16)
# Impacket ships ~60 scripts; probe one canonical entrypoint.
_have impacket-secretsdump && HAVE_IMPACKET=1
# BloodHound CE collectors (python collector is the cross-platform one)
_have bloodhound-python && HAVE_BHPY=1
# Web / recon (ProjectDiscovery + classics)
_have nuclei       && HAVE_NUCLEI=1
_have httpx        && HAVE_HTTPX=1
_have katana       && HAVE_KATANA=1
_have bbot         && HAVE_BBOT=1
_have ffuf         && HAVE_FFUF=1
_have feroxbuster  && HAVE_FEROX=1
_have gobuster     && HAVE_GOBUSTER=1
_have amass        && HAVE_AMASS=1
# C2 / emulation
_have sliver-client && HAVE_SLIVER=1
_have msfconsole    && HAVE_MSF=1
_have caldera       && HAVE_CALDERA=1
# Cracking
_have hashcat      && HAVE_HASHCAT=1
_have john         && HAVE_JOHN=1

# ── Engagement workspace root (OUTSIDE the repo — keep it that way) ───────────
: "${ENGAGEMENTS_DIR:=$HOME/engagements}"
: "${SECLISTS_DIR:=/usr/share/seclists}"          # Kali default install path
: "${WORDLISTS_DIR:=/usr/share/wordlists}"
export ENGAGEMENTS_DIR SECLISTS_DIR WORDLISTS_DIR

# ── Tool ergonomics (guarded) ─────────────────────────────────────────────────
[[ -n ${HAVE_NXC:-}    ]] && alias smb='nxc smb' && alias ldap='nxc ldap' && alias winrm='nxc winrm'
[[ -n ${HAVE_MSF:-}    ]] && alias msf='msfconsole -q'
[[ -n ${HAVE_SLIVER:-} ]] && alias sliver='sliver-client'
# Quick stand-up of a delivery web server in the CURRENT dir (note the port).
alias hethttp='echo "serving $(pwd) on :8000"; python3 -m http.server 8000'
# SecLists fast-path: jump to the wordlist tree with your fzf preview stack.
[[ -d "$SECLISTS_DIR" ]] && alias seclists='cd "$SECLISTS_DIR"'
# Open the CTF/HTB command cheatsheet (folds by service — `za` toggles a fold).
[[ -f "$HOME/hacktheplanet" ]] && alias htp='${EDITOR:-nvim} "$HOME/hacktheplanet"'
# Companion field references (same fold UX): exploit-dev and defense-evasion.
[[ -f "$HOME/exploitdev" ]] && alias xdev='${EDITOR:-nvim} "$HOME/exploitdev"'
[[ -f "$HOME/evasion" ]] && alias evade='${EDITOR:-nvim} "$HOME/evasion"'
# The IppSec method — workflow habits + signature moves (the altitude above the
# command refs: the recon loop, shell stabilization, the scripted pseudo-shell).
[[ -f "$HOME/ippsec" ]] && alias ipp='${EDITOR:-nvim} "$HOME/ippsec"'
# The structured companion (the experimental sibling of the flat refs above):
# fuzzy-pick an attack, preview it beside its paired blue detection, fill the
# {{slots}} from $RHOST/$LHOST/... and copy. A function so args pass through and
# $0 stays the real script path (htpx re-execs itself for the fzf preview).
[[ -x "$HOME/companion/htpx" ]] && htpx() { "$HOME/companion/htpx" "$@"; }

# ── nmap: a sane default sweep that writes all-formats output into the cwd ────
# Usage: nmapsweep <target/CIDR>   → ./nmap/<target>.{nmap,gnmap,xml}
# Intentionally conservative defaults; tune per engagement & ROE.
nmapsweep() {
  [[ -z "$1" ]] && { echo "Usage: nmapsweep <target|CIDR>"; return 1; }
  [[ -n ${HAVE_NMAP:-} ]] || { echo "nmap not installed"; return 1; }
  local out="nmap"; mkdir -p "$out"
  local stamp; stamp=$(echo "$1" | tr '/:' '__')
  nmap -sCV -T4 -oA "$out/$stamp" "$1"
}

# ── NetExec → BloodHound CE collection wrapper ────────────────────────────────
# Thin convenience around the documented one-liner; drops the zip into the
# current engagement's loot/ dir so it's ready to drag into BloodHound CE.
# Usage: bhce <dc-ip> <user> <pass-or-hash> [domain]
bhce() {
  [[ -n ${HAVE_NXC:-} ]] || { echo "NetExec (nxc) not installed"; return 1; }
  if [[ $# -lt 3 ]]; then
    echo "Usage: bhce <dc-ip> <user> <pass|:NThash> [domain]"
    echo "  collects All methods via LDAP and zips for BloodHound CE ingest"
    return 1
  fi
  local dc="$1" user="$2" secret="$3" dom="${4:-}"
  local loot="${ENGAGEMENT:-$PWD}/loot/bloodhound"; mkdir -p "$loot"
  local creds=(-u "$user" -p "$secret")
  # `:hash` form → pass-the-hash via -H instead of -p
  [[ "$secret" == :* ]] && creds=(-u "$user" -H "${secret#:}")
  local dflag=(); [[ -n "$dom" ]] && dflag=(-d "$dom")
  echo ":: nxc ldap $dc --bloodhound --collection All  (→ $loot)"
  ( cd "$loot" && nxc ldap "$dc" "${creds[@]}" "${dflag[@]}" \
      --bloodhound --collection All --dns-server "$dc" )
}

# ── Engagement scaffolding ────────────────────────────────────────────────────
# mkengagement <name> — create a dated, structured engagement workspace and cd
# into it. Sets $ENGAGEMENT for the session so other helpers (bhce) target it.
# Layout follows a recon→loot→report flow; scope.txt is created FIRST and opened
# so the rules of engagement are written down before any tool runs.
mkengagement() {
  [[ -z "$1" ]] && { echo "Usage: mkengagement <client-or-codename>"; return 1; }
  local name slug root
  slug=$(echo "$1" | tr '[:upper:] ' '[:lower:]_' | tr -cd '[:alnum:]_-')
  name="$(date +%Y%m%d)-${slug}"
  root="$ENGAGEMENTS_DIR/$name"
  if [[ -d "$root" ]]; then
    echo "Engagement already exists: $root"; export ENGAGEMENT="$root"; cd "$root"; return 0
  fi
  mkdir -p "$root"/{scope,recon,scans,loot/{creds,bloodhound,hashes},web,screenshots,exploit,report}
  cat > "$root/scope/scope.txt" <<EOF
ENGAGEMENT : $name
CREATED    : $(date -Iseconds)
CLIENT     :
AUTH REF   :          # contract / ROE / authorization-letter reference
WINDOW     :          # permitted start–end (date + time + TZ)

IN SCOPE   :          # hosts / CIDRs / domains / apps explicitly authorized

OUT SCOPE  :          # explicitly off-limits — DO NOT TOUCH

CONSTRAINTS:          # no-DoS, business hours only, data-handling, etc.
EMERGENCY  :          # client contact + your team lead, for "stop" calls
EOF
  : > "$root/notes.md"
  export ENGAGEMENT="$root"
  cd "$root"
  echo "✓ engagement at $root  (\$ENGAGEMENT set)"
  echo "  → fill in scope/scope.txt BEFORE you run anything."
  ${EDITOR:-nvim} "$root/scope/scope.txt"
}

# eng — fzf-jump between existing engagements (mirrors Core's fzf widget style)
eng() {
  [[ -d "$ENGAGEMENTS_DIR" ]] || { echo "no $ENGAGEMENTS_DIR yet — run mkengagement"; return 1; }
  local sel
  sel=$(find "$ENGAGEMENTS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
        | sort -r \
        | fzf --prompt="Engagement ❯ " \
              --preview="bat --color=always {}/scope/scope.txt 2>/dev/null || ls -la {}")
  [[ -z "$sel" ]] && return 0
  export ENGAGEMENT="$sel"; cd "$sel"
}

# logshell — record a full terminal session into the engagement's notes for the
# audit trail (typescript + timing). Stop with Ctrl-D / `exit`.
logshell() {
  local dir="${ENGAGEMENT:-$PWD}/notes"; mkdir -p "$dir"
  local f="$dir/session-$(date +%Y%m%d-%H%M%S).log"
  echo ":: recording shell → $f  (exit/Ctrl-D to stop)"
  script -q "$f"
}

# ── IppSec-method ergonomics (see ~/ippsec / `ipp`) ───────────────────────────
# These turn the file's habits into one-keystroke moves: the recon loop only
# pays off if stabilizing a shell and jotting a note are frictionless.

# cde — cd back to the active engagement tree ($ENGAGEMENT, set by mkengagement/eng).
cde() {
  [[ -n "${ENGAGEMENT:-}" && -d "$ENGAGEMENT" ]] || {
    echo "no active engagement — run mkengagement/eng first"; return 1; }
  cd "$ENGAGEMENT"
}

# note — append a timestamped line to the engagement's notes.md. Note discipline
# is IppSec's force-multiplier: capture every state change, cred, and host the
# instant it happens, so the report (and your re-entry) writes itself.
# Usage: note "got www-data via Gobox SSTI"   |   note   (opens notes.md in $EDITOR)
note() {
  local f="${ENGAGEMENT:-$PWD}/notes.md"; mkdir -p "$(dirname "$f")"
  if [[ $# -eq 0 ]]; then ${EDITOR:-nvim} "$f"; return; fi
  printf '%s  %s\n' "$(date '+%F %T')" "$*" >> "$f"
  echo ":: noted → $f"
}

# lhost — print YOUR attacker IP (the <your-ip> that fills reverse shells / file
# servers). Prefers the VPN tun (HTB/engagement) and falls back to the primary
# global iface. Pass an iface name to force one: lhost eth0
lhost() {
  local iface="${1:-}" ip=""
  if [[ -z "$iface" ]]; then
    for iface in tun0 tun1 tap0 wg0; do
      ip=$(ip -4 -brief addr show "$iface" 2>/dev/null | awk '{print $3}' | cut -d/ -f1)
      [[ -n "$ip" ]] && break
    done
    # Fallback: the default-route SOURCE IP (Core's idiom in functions.zsh) — picks
    # the routable LAN address, not the first global iface (which may be a docker bridge).
    [[ -z "$ip" ]] && ip=$(ip route get 1.1.1.1 2>/dev/null \
                            | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}')
  else
    ip=$(ip -4 -brief addr show "$iface" 2>/dev/null | awk '{print $3}' | cut -d/ -f1)
  fi
  [[ -z "$ip" ]] && { echo "no IPv4 found (try: lhost <iface>)"; return 1; }
  echo "$ip"
}

# ttyup — print the IppSec TTY-upgrade sequence with YOUR local rows/cols already
# filled in, so stabilizing a dumb shell is copy-paste. Run it on the ATTACKER
# side (it reads your terminal size), then paste the steps in order.
ttyup() {
  local rows cols; rows=$(tput lines 2>/dev/null) cols=$(tput cols 2>/dev/null)
  cat <<EOF
# ── stabilize a dumb shell (run these in order) ───────────────────────────────
# 1) on the TARGET:
python3 -c 'import pty;pty.spawn("/bin/bash")'   # or: script -qc /bin/bash /dev/null
# 2) background it:  Ctrl-Z
# 3) on YOUR box:
stty raw -echo; fg
# 4) press Enter, then on the TARGET:
export TERM=xterm
stty rows ${rows:-50} cols ${cols:-200}
# (prompt wrecked after the shell dies?  ->  stty sane   or   reset)
EOF
}

# rocks — open an ippsec.rocks search for a technique/keyword. The index is a
# tool: "I don't know how to attack X" is a search, not a wall.
# Usage: rocks forward shell    |    rocks kerberoast
rocks() {
  [[ $# -eq 0 ]] && { echo "Usage: rocks <keyword…>   (searches ippsec.rocks)"; return 1; }
  # Percent-encode the WHOLE query — the term lands in the URL fragment, so a bare
  # '#', '?', '&' or '%' would otherwise break it. Only unreserved chars pass through.
  local s="$*" q="" c i
  for (( i = 1; i <= ${#s}; i++ )); do
    c="${s[i]}"
    case "$c" in
      [a-zA-Z0-9._~-]) q+="$c" ;;
      *) q+=$(printf '%%%02X' "'$c") ;;
    esac
  done
  local url="https://ippsec.rocks/?#$q"
  if command -v xdg-open >/dev/null 2>&1; then xdg-open "$url" >/dev/null 2>&1
  elif command -v wslview >/dev/null 2>&1; then wslview "$url"
  elif command -v explorer.exe >/dev/null 2>&1; then explorer.exe "$url" 2>/dev/null
  else echo "$url"; fi
}

unfunction _have 2>/dev/null
