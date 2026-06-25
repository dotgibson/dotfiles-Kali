# dotfiles-Kali

The Kali node of the dotfiles system. Unlike every other OS repo, this one
stacks **three** layers instead of two:

| Layer | Source | What it carries |
|-------|--------|-----------------|
| **Core** | vendored from `dotfiles-core` under `core/` | zsh modules, tmux, nvim, git, starship, mise, clip |
| **OS-native** | `os/kali.*` | apt, clipboard delegation, paths, tmux/git tweaks (Kali is Debian-based) |
| **Offensive (role)** | `offensive/` | engagement scaffolding + workspace workflow — **unique to this repo** |

Built for **Kali on WSL2**.

## The one rule that matters

**This is a public showcase repo. Engagement and client data never live in it.**

All engagement data lives under `~/engagements/` (outside the repo). The repo
ships only tooling, config, and empty workspace scaffolding. The paranoid
`.gitignore` is defense-in-depth, and every engagement folder `newengagement`
creates gets its own `*` gitignore. Keep it that way.

## Loader integration

The offensive layer adds one stage to the zsh loader, slotted in just before
local overrides:

```
tools → aliases → functions → fzf → bindings → plugins → op → os → offensive → local
```

`offensive/offensive.zsh` → `~/.config/zsh/offensive.zsh`. It holds workflow
helpers only (`newengagement`, `eng`/`seteng`/`cde`, `note`, `lhost`, `www`) —
no exploit code, no attack automation; just where your output goes.

## WSL2: read before you run a listener

WSL2 is NAT'd by default, so a reverse shell / handler / responder / file
server started in Kali is **not reachable from your LAN** — traffic hits the
Windows host, not Kali. Fix it with **mirrored networking** (Windows 11 22H2+):
copy `wsl/windows.wslconfig.example` to `%UserProfile%\.wslconfig`, then
`wsl.exe --shutdown` and reopen. The distro-side `wsl/wsl.conf` (systemd +
default user + interop) is installed automatically by `bootstrap.sh`.

GUI tools (Burp, BloodHound UI) work under WSLg but are smoother on the Windows
host — the default tool list is headless-first.

## Install (fresh repo lifecycle)

```sh
# 1. land these files in ~/dotfiles-Kali, then:
cd ~/dotfiles-Kali
git init -b main
git config user.name  "Your Name"
git config user.email "you@example.com"
git add . && git commit -m "Kali OS + offensive layers"

# 2. vendor Core (one time)
git subtree add --prefix=core <dotfiles-core remote> main --squash

# 3. provision + wire
./bootstrap.sh                 # full (add --no-offensive to skip heavy tools)

# 4. apply WSL config
wsl.exe --shutdown             # from a Windows terminal, then reopen Kali
# (also drop windows.wslconfig.example at %UserProfile%\.wslconfig for mirrored net)
```

Keeping Core current later is the same as every repo: from `dotfiles-core`,
`./bin/sync-core.sh dotfiles-Kali`, then `./bootstrap.sh --links-only` here.

## bootstrap flags

- `./bootstrap.sh` — apt base + offensive tools + symlinks
- `./bootstrap.sh --no-offensive` — base + symlinks, skip the heavy tool install
- `./bootstrap.sh --links-only` — just (re)create symlinks

# The offensive layer (Kali specifics)

> This section documents what makes `dotfiles-Kali` different from every other
> repo in the system. Everything here is the **role layer** — it does not, and
> must not, exist in Core. (If it changes when the *operating system* changes
> it's OS-native; if it's identical everywhere it's Core; what's left — the
> offensive tradecraft scaffolding — is this.)

Kali is not stamped from the Fedora template. It's Debian-family (apt) and is
the only repo that carries an **offensive stage** in the zsh loader. Where every
other repo's `.zshrc` sources `… os local`, Kali inserts one more:

```
tools → aliases → functions → fzf → bindings → plugins → op → os → offensive → local
```

`offensive` loads after `os` (so OS paths/clipboard are already resolved) and
before `local` (so a machine-specific override still wins).

---

## What the layer ships

| File | Role |
|------|------|
| `offensive/offensive.zsh` | sourced in the `offensive` stage — `HAVE_*` detection, tool ergonomics, engagement scaffolding |
| `offensive/tmux/tmux-eng.sh` | `prefix + e` popup — fuzzy-jump to an engagement session (twin of Core's sessionizer) |
| `offensive/hacktheplanet` | CTF/HTB/engagement command cheatsheet — copy-paste syntax per service/port (the field reference under the methodology map). Folds by section in vim; symlinked to `~/hacktheplanet`, opened with `htp` |
| `offensive/ippsec` | **the method** — workflow habits + signature moves distilled from IppSec's HTB catalog (the recon loop, shell stabilization, the scripted pseudo-shell, the unsticking playbook). The altitude *above* the command refs. Same fold UX; symlinked to `~/ippsec`, opened with `ipp` |
| `offensive/templates/pseudo-shell.py` | reusable Python `cmd.Cmd` pseudo-shell for blind/awkward RCE (SSTI/injection/deserialization) — IppSec's signature; copy into an engagement's `exploit/` and wire up the request + capture regex |
| `install/offensive-packages.txt` | the apt tool list (installed after the OS + Core layers) |
| `OFFENSIVE-METHODOLOGY.md` | the phase → MITRE ATT&CK → tool map behind the layer |
| `PURPLE-TEAM.md` | the defensive mirror of `hacktheplanet` — Splunk/Sentinel detections + event-ID reference for each attack (purple-team perspective / red OPSEC) |

Same discipline as Core: every alias/function touching an optional tool is
guarded by a `HAVE_*` flag, so the file is **inert** on a box where the tool
isn't installed instead of erroring on shell start.

---

## Commands

| Command | What it does |
|---------|--------------|
| `mkengagement <name>` | scaffold a dated engagement workspace under `$ENGAGEMENTS_DIR`, seed `scope/scope.txt`, open it in `$EDITOR`, and `cd` in (sets `$ENGAGEMENT`) |
| `eng` | fzf-jump between existing engagements; previews the scope sheet |
| `bhce <dc> <user> <pass\|:hash> [domain]` | run NetExec's BloodHound CE collection, dropping a CE-ready zip into `loot/bloodhound/` |
| `nmapsweep <target\|CIDR>` | conservative `-sCV` sweep, all-formats output into `./nmap/` |
| `logshell` | record a `script(1)` transcript into the engagement's `notes/` for the audit trail |
| `smb` / `ldap` / `winrm` | shorthands for `nxc <proto>` |
| `seclists` | jump to `$SECLISTS_DIR` with the fzf preview stack |
| `htp` / `ipp` / `xdev` / `evade` | open the field refs (`~/hacktheplanet` / `~/ippsec` / `~/exploitdev` / `~/evasion`) in `$EDITOR` |
| `note "<text>"` | timestamped append to the engagement's `notes.md` (IppSec note discipline); `note` with no args opens it |
| `cde` | `cd` back to the active engagement tree (`$ENGAGEMENT`) |
| `lhost [iface]` | print your attacker/VPN IP (the `<your-ip>` for reverse shells) — prefers `tun0`, falls back to primary iface |
| `ttyup` | print the TTY-upgrade stabilization sequence with your local rows/cols pre-filled |
| `rocks <keyword>` | open an `ippsec.rocks` search for a technique/keyword |

## tmux bindings

| Binding | Popup |
|---------|-------|
| `prefix + f` | **projects** — Core sessionizer (unchanged) |
| `prefix + e` | **engagements** — create-or-switch to an engagement session |
| `prefix + w` | **everything** — Core menu, now surfaces engagements as `◆` rows when `~/engagements` exists |

`prefix + e` lives here (the binding is in `os/kali.conf`, the script in
`offensive/tmux/`, symlinked to `~/.config/tmux/scripts/tmux-eng.sh` by
`bootstrap.sh`). `prefix + w` is **Core** but engagement-*agnostic*: the `◆`
section only renders where an engagements dir exists, so it stays portable and
syncs cleanly to all nine repos.

---

## Engagement workspace

Engagement **data never lives in this repo.** It lives in `$ENGAGEMENTS_DIR`
(default `~/engagements`), outside any git tree; the repo's paranoid
`.gitignore` is only a backstop. `mkengagement` lays out:

```
~/engagements/<YYYYMMDD>-<slug>/
  scope/scope.txt        ← written & opened FIRST (ROE, auth ref, window, contacts)
  recon/  scans/  web/    exploit/  screenshots/
  loot/{creds,hashes,bloodhound}
  report/  notes.md
```

> Rule zero: `scope/scope.txt` is created before anything else for a reason.
> Installing a tool is not permission to point it at anything — fill in scope,
> in-scope/out-of-scope, the authorization reference and a "stop" contact first.

---

## Tooling notes that will actually bite you

**CrackMapExec is gone — it's `nxc` now.** CME was archived in 2023; the
maintained successor is **NetExec** (`nxc`), and it's the single
highest-leverage tool in the kit — auth, enumeration, lateral movement,
credential extraction and BloodHound collection across SMB/LDAP/WinRM/MSSQL/
RDP/FTP/SSH in one scriptable interface. Old `cme` muscle memory just becomes
`nxc`.

**BloodHound is now BloodHound CE.** Legacy 4.x collectors don't cleanly ingest
into Community Edition. The `bhce` helper drives nxc's `--bloodhound` module,
which packages a CE-ready zip. Run BloodHound CE itself from its official
docker-compose — it's a Postgres-backed web app, not an apt package.

**Upstream-only tools.** A few move faster than the Kali repo or aren't packaged
— Sliver, Havoc, Caldera, sometimes BBOT/ligolo-ng. `offensive-packages.txt`
flags these with their install method (same pattern Core already uses for
starship/atuin on some distros).

**WSL2 is NAT'd.** A listener / reverse shell / C2 in Kali under WSL2 isn't
reachable from your LAN until you set `networkingMode=mirrored` in the
**Windows-side** `%UserProfile%\.wslconfig` (Win11 22H2+) — *not*
`/etc/wsl.conf`. This bites every Responder/Sliver/Metasploit handler setup.

**Debian binary renames** (handled by Core already): `bat` runs as `batcat`,
`fd-find` installs `fdfind`. Core's `tools.zsh` resolves both, so aliases and
config work unchanged here.

---

## Authorization

Every tool in this layer is for **authorized engagements with written rules of
engagement only.** The scaffolding (scope-first workspace, `logshell` audit
trail, data kept out of the repo) exists to keep that discipline mechanical
rather than optional. See `OFFENSIVE-METHODOLOGY.md` for the full phase → ATT&CK
mapping and the OPSEC hygiene baked into the layer.

## Engagement workflow

```sh
newengagement acme-external     # scaffold ~/engagements/acme-external + make active
eng                             # show the active engagement
cde recon/nmap                  # jump into a subdir of it
note "got creds for svc_sql"    # timestamped line into notes/notes.md
lhost                           # interface IPs for a listener / callback
```
