# CLAUDE.md — dotfiles-Kali

Project memory for Claude Code, auto-loaded every session. For the shared Core
rules (the load order, the "is it Core?" test, the manifest contract) see
`core/README.md` and `core/CONTRIBUTING.md`.

## What this repo is

`dotfiles-Kali` is the **Role layer** of a **nine-repo dotfiles system** built on
a three-layer model (Core → OS-native → Role): the OS-native layer for Kali
(Debian-family, `apt`, run under WSL2) **plus** an offensive engagement layer on
top. It is its own lineage — built directly, not stamped from the Fedora template.

## The rule that bites

`core/` is a **vendored `git subtree` copy of [dotfiles-core](https://github.com/Gerrrt/dotfiles-core)** — *not*
editable here; changes under `core/` are overwritten on the next sync. Edit shared
Core config **in dotfiles-core**, `make audit`, then `make sync`.

Three things that actually bite on this repo:

- The zsh loader adds an **`offensive` stage** (`… os offensive local`) on top of
  the Core order — keep offensive config in that layer, not in `core/`.
- **Debian renames binaries** — `bat`→`batcat`, `fd-find`→`fdfind`. Core's
  `tools.zsh` already resolves both; don't "fix" aliases for it.
- **WSL2 is NAT'd** — a listener/reverse shell isn't LAN-reachable until mirrored
  networking is enabled in the *Windows-side* `%UserProfile%\.wslconfig`
  (`networkingMode=mirrored`), **not** `/etc/wsl.conf`.

Keep all engagement data in `~/engagements` (outside the repo); the repo ships a
paranoid `.gitignore` as backup.

## Where things are

- `offensive/` — engagement scaffolding (the role layer)
- `offensive/hacktheplanet` — CTF/HTB/engagement command cheatsheet (field reference under `OFFENSIVE-METHODOLOGY.md`); folds by section in vim, symlinked to `~/hacktheplanet`, opened with `htp`
- `offensive/exploitdev` — binary-exploitation companion (stack/SEH overflows, egghunters, shellcode, DEP/ASLR, PE backdooring, plus a vulnserver command→bug→technique map as the practice target); same vim-fold UX, symlinked to `~/exploitdev`, opened with `xdev`
- `offensive/evasion` — defense-evasion companion (AV/AMSI/AppLocker bypass, client-side macro access, process injection, egress/C2, advanced AD); symlinked to `~/evasion`, opened with `evade`
- `offensive/ippsec` — **the method**: workflow habits + signature moves from IppSec's HTB catalog (the "always be running recon" loop, shell stabilization, the scripted `cmd.Cmd` pseudo-shell, the unsticking playbook) — the altitude *above* the command refs; same vim-fold UX, symlinked to `~/ippsec`, opened with `ipp`. Reusable pseudo-shell starting point: `offensive/templates/pseudo-shell.py`. Helpers in `offensive.zsh`: `ttyup`, `note`, `lhost`, `cde`, `rocks`
- `PURPLE-TEAM.md` — defensive mirror of `hacktheplanet`: Splunk/Sentinel detections + Windows event-ID reference per attack (from TrustedSec's Actionable Purple Teaming, BH USA 2023)
- `offensive/companion` — **experimental** structured/ATT&CK-tagged restructuring of the corpus into machine-readable `entries/red|blue/*.md` (YAML frontmatter + command template), each red attack `pair:`-linked to its blue detection. Browsed with `htpx` (fzf: pick → preview attack beside its detection → fill `{{slots}}` from `$RHOST/$LHOST/...` → `clip`); dir symlinked to `~/companion`. Purely additive — `hacktheplanet`/`PURPLE-TEAM.md` stay canonical until the source-of-truth question in `companion/README.md` is settled
- `install/offensive-packages.txt` — offensive tooling; `install/packages.txt` — base
- `os/kali.zsh`, `os/kali.conf`, `os/kali.gitconfig` — OS overlays
- `OFFENSIVE-METHODOLOGY.md` — the engagement playbook
- `bootstrap.sh` — symlinks Core + OS + offensive files into place
- `core/` — vendored Core (read-only here; edit upstream in dotfiles-core)
