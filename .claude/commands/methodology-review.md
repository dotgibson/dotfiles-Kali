---
description: Audit the offensive docs for deprecated flags / renamed tools vs offensive-packages.txt (report-first)
argument-hint: "[doc or theme — optional, e.g. hacktheplanet, evasion, bloodhound]"
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(ls:*)
---

# /methodology-review

Audit the offensive method docs — `offensive/hacktheplanet`,
`OFFENSIVE-METHODOLOGY.md`, `offensive/exploitdev`, `offensive/evasion`,
`offensive/ippsec` — for **tooling drift**: a command that names a deprecated flag,
a renamed / EOL binary, or a tool the package list no longer installs under that
name. These are hand-curated vim-fold cheat-sheets; nothing mechanically checks that
the tradecraft in them still matches the tools actually shipped.

Focus for this run: **$ARGUMENTS** (empty = all the offensive docs).

## Baseline first — what NOT to touch

- **Skip inside `# companion:gen … # companion:end` marker regions** in
  `hacktheplanet` and `PURPLE-TEAM.md`. Those blocks are machine-generated from the
  htpx corpus by `gen-views.sh` and drift-gated by `companion.yml` — a hand-edit
  there is overwritten and fails CI. Review only the prose **outside** the markers.
- The vendored `offensive/companion/` subtree is read-only here (source of truth is
  htpx, which has its own `corpus-review` routine). Don't review it as prose.

## What to check

1. **Renamed / EOL binaries.** Cross-reference every tool named in the docs against
   `install/offensive-packages.txt` and its annotations — the canonical names plus
   the EOL/rename notes it already carries: `netexec`/`nxc` is CrackMapExec's
   successor (CME archived 2023); the `bloodhound.py` apt package is LEGACY (≤4.3.1)
   vs `bloodhound-ce-python`; `kerbrute` is FROZEN (v1.0.3, 2019); the apt name is
   `python3-ldapdomaindump`. Flag any doc still teaching `crackmapexec`/`cme`, legacy
   `bloodhound.py`, or a tool the package list dropped or renamed.
2. **Deprecated flags / subcommands.** A command using a flag the current tool
   removed or renamed (impacket script renames, nmap NSE changes, a tool that moved
   to subcommands). Note where you're unsure and it needs a human to verify.
3. **Docs ↔ package-list consistency (both directions).** A tool taught in the docs
   but absent from `offensive-packages.txt` (should it be added, or is it an
   `# UPSTREAM` go-install?), and a package in the list no doc actually uses.
4. **`CLAUDE.md` "Where things are" ↔ reality.** The offensive-tree description vs
   the files that exist.

## How to report

Ranked, most-impactful first; cite `file:line` and the exact fix
(old → new command / flag / name):

- **Broken (teaches a dead tool/flag)** — a command that won't run as written on a
  current box.
- **Drifted** — renamed but still works via an alias, or a stale annotation.
- **Clean** — docs reviewed and still accurate, so a green run is trustworthy.

Report-first. Fixes to the prose land in `hacktheplanet` /
`OFFENSIVE-METHODOLOGY.md` / etc. **outside** the markers; corpus fixes route upstream
to htpx. Do not edit anything unless I explicitly ask.
