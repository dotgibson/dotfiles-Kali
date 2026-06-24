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

unfunction _have 2>/dev/null
