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
_have certipy-ad   && HAVE_CERTIPY=1        # AD CS abuse (ESC1-ESC17, since Certipy v5.1.0)
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
# Quick stand-up of a delivery web server in the CURRENT dir. Binds ALL interfaces
# (0.0.0.0) on purpose — a target has to reach it over your VPN/tun — so it advertises the
# REACHABLE callback URL (via lhost) instead of a bare `:8000` you'd have to resolve by hand.
# Optional port arg (default 8000).
hethttp() {
  local port="${1:-8000}" addr
  # Validate the port before advertising a URL (mirrors Core's `serve`): a bad value
  # should fail in the tool's voice on stderr, not print "serving …" then let
  # http.server crash. `<->` is zsh's non-negative-integer glob.
  if [[ "$port" != <-> ]] || ((port < 1 || port > 65535)); then
    echo "usage: hethttp [port]   (port must be 1-65535; default 8000)" >&2
    return 1
  fi
  addr=$(lhost 2>/dev/null)
  if [[ -n "$addr" ]]; then
    echo "serving $(pwd) on http://${addr}:${port}/  (bound 0.0.0.0 — reachable on every interface)"
  else
    echo "serving $(pwd) on 0.0.0.0:${port}  (no tun/LAN IP found; reachable on every interface)"
  fi
  python3 -m http.server "$port"
}
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
  [[ -z "$1" ]] && { echo "Usage: nmapsweep <target|CIDR>" >&2; return 1; }
  [[ -n ${HAVE_NMAP:-} ]] || { echo "nmap not installed" >&2; return 1; }
  local out="nmap"; mkdir -p "$out"
  local stamp; stamp=$(echo "$1" | tr '/:' '__')
  nmap -sCV -T4 -oA "$out/$stamp" "$1"
}

# ── NetExec → BloodHound CE collection wrapper ────────────────────────────────
# Thin convenience around the documented one-liner; drops the zip into the
# current engagement's loot/ dir so it's ready to drag into BloodHound CE.
# Usage: bhce <dc-ip> <user> <pass-or-hash> [domain]
bhce() {
  [[ -n ${HAVE_NXC:-} ]] || { echo "NetExec (nxc) not installed" >&2; return 1; }
  if [[ $# -lt 3 ]]; then
    echo "Usage: bhce <dc-ip> <user> <pass|:NThash> [domain]" >&2
    echo "  collects All methods via LDAP and zips for BloodHound CE ingest" >&2
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
  [[ -z "$1" ]] && { echo "Usage: mkengagement <client-or-codename>" >&2; return 1; }
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
  [[ -d "$ENGAGEMENTS_DIR" ]] || { echo "no $ENGAGEMENTS_DIR yet — run mkengagement" >&2; return 1; }
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
    echo "no active engagement — run mkengagement/eng first" >&2; return 1; }
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
  [[ -z "$ip" ]] && { echo "no IPv4 found (try: lhost <iface>)" >&2; return 1; }
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
  [[ $# -eq 0 ]] && { echo "Usage: rocks <keyword…>   (searches ippsec.rocks)" >&2; return 1; }
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

# ── redup — MANUAL offensive-tool refresh (opt-in; NEVER automatic) ───────────
# apt owns the packaged tools (`up` / `sudo apt upgrade`); THIS refreshes the fast-movers
# that carry their OWN updater and rot between apt syncs — nuclei's engine + templates
# (templates move daily), searchsploit's exploit-DB, and the go-installed tools that
# aren't in apt. Run it DELIBERATELY on your attacker box — NEVER on a client/engagement
# host mid-op, where updating a tool under a working chain is exactly how you break it.
# Each step is guarded by tool presence (command -v, not _have — that's unfunctioned at
# load). It only ever runs each tool's own updater; it installs nothing new and touches
# no engagement data.
redup() {
  emulate -L zsh
  if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
    print -- "redup — manually refresh the fast-moving offensive tools (opt-in, attacker box only,"
    print -- "        never mid-engagement): nuclei engine+templates, searchsploit exploit-DB, and"
    print -- "        the go-installed tools. apt-packaged tools update via 'up'."
    return 0
  fi
  print -P "%F{yellow}⚠ redup: manual offensive-tool refresh — attacker box only, never mid-engagement.%f"
  local updated=0 failed=0

  # nuclei — engine + templates. Count a step only when its updater EXITS 0; a failure
  # prints a hint and is tallied, so the summary can't read green on a silent failure.
  if command -v nuclei >/dev/null 2>&1; then
    print -P "%F{cyan}» nuclei — engine + templates%f"
    if nuclei -update -silent 2>/dev/null || nuclei -update 2>/dev/null; then
      ((updated++))
    else
      print -P "  %F{red}✗ nuclei engine update failed%f"; ((failed++))
    fi
    if nuclei -update-templates -silent 2>/dev/null || nuclei -update-templates 2>/dev/null; then
      ((updated++))
    else
      print -P "  %F{red}✗ nuclei template update failed%f"; ((failed++))
    fi
  else
    print -- "  – nuclei not installed — skipping"
  fi

  # searchsploit — exploit-DB refresh (only counted on success).
  if command -v searchsploit >/dev/null 2>&1; then
    print -P "%F{cyan}» searchsploit — exploit-DB refresh%f"
    if searchsploit -u; then
      ((updated++))
    else
      print -P "  %F{red}✗ searchsploit -u failed%f"; ((failed++))
    fi
  else
    print -- "  – searchsploit not installed — skipping"
  fi

  # go-installed, apt-ABSENT fast-movers (see install/offensive-packages.txt UPSTREAM
  # notes). REINSTALL-ONLY: each tool is guarded by its OWN binary, so redup never installs
  # something new — it only re-fetches @latest for a tool you already have. Curated to the
  # go-ONLY tools; apt-packaged ones (gobuster/ffuf) update via `up`. `go` must be present.
  #
  # The list is EMPTY by design: kerbrute (the former sole entry) is upstream-frozen (last
  # release v1.0.3, Dec 2019), so `go install …/kerbrute@latest` every run just re-fetched
  # an unchanging commit — a no-op that padded the "refreshed" tally. Dropped; kerbrute is a
  # manual UPSTREAM install (release binary / `go install`, never apt-packaged — see its note
  # in install/offensive-packages.txt), so redup dropping it changes nothing about how you get
  # or keep it. Keep this machinery for the next genuinely fast-moving go-only tool: add a
  # `bin=module@latest` pair to go_fast_movers.
  if command -v go >/dev/null 2>&1; then
    local pair bin mod
    local -a go_fast_movers=()
    for pair in "${go_fast_movers[@]}"; do
      bin="${pair%%=*}"; mod="${pair#*=}"
      if ! command -v "$bin" >/dev/null 2>&1; then
        print -- "  – $bin not installed — skipping (redup re-fetches, it never installs new)"
        continue
      fi
      print -P "%F{cyan}» go: $bin — go install $mod%f"
      if go install "$mod" 2>/dev/null; then
        ((updated++))
      else
        print -P "  %F{red}✗ go install $mod failed (module path / network?)%f"; ((failed++))
      fi
    done
  else
    print -- "  – go not installed — skipping go tools"
  fi

  print
  if ((failed)); then
    print -P "%F{yellow}redup: ${updated} refreshed, ${failed} failed.%f Re-run, or update the failed tool by hand."
  elif ((updated)); then
    print -P "%F{green}✓ redup: ${updated} tool step(s) refreshed.%f Restart any long-running tool that caches state."
  else
    print -- "redup: nothing to update (none of the fast-movers are installed)."
  fi
}

unfunction _have 2>/dev/null
