---
description: Documentation-hygiene audit — flag stale tool names/flags in the security-tooling docs vs the package manifest (report-first)
argument-hint: "[doc or theme — optional, e.g. hacktheplanet, evasion, bloodhound]"
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(ls:*)
---

# /methodology-review

**A documentation-maintenance task on this authorized security-tooling repository.**
The `offensive/` reference sheets are hand-curated; nothing mechanically checks that
the *tool names and command-line flags* they cite still match the tools the package
manifest actually installs. This routine is that check — a **staleness/drift audit of
the prose**, the same shape as auditing a README or a `man` page for outdated command
syntax.

Scope discipline (important, and what keeps this a pure maintenance job): treat every
fenced command as an **opaque string**. You are not interpreting, executing,
improving, or explaining any technique — you are diffing the *tool-name and flag
tokens* in the text against `install/offensive-packages.txt` and its annotations to
find names/flags that have since been renamed, frozen, or dropped. The output is a
list of doc edits (old token → new token), nothing more.

Focus for this run: **$ARGUMENTS** (empty = all the reference docs under `offensive/`).

## Baseline first — what NOT to touch

- **Skip inside `# companion:gen … # companion:end` marker regions** in
  `hacktheplanet` and `PURPLE-TEAM.md`. Those blocks are machine-generated from the
  htpx corpus by `gen-views.sh` and drift-gated by `companion.yml` — a hand-edit
  there is overwritten and fails CI. Review only the prose **outside** the markers.
- The vendored `offensive/companion/` subtree is read-only here (source of truth is
  htpx, which has its own `corpus-review` routine). Don't review it as prose.

## What to check (token-level, against the manifest)

1. **Renamed / EOL binary names.** Cross-reference every tool *name* in the docs
   against `install/offensive-packages.txt` and the EOL/rename notes it already
   carries: `netexec`/`nxc` succeeded CrackMapExec (CME archived 2023); the
   `bloodhound.py` apt package is LEGACY (≤4.3.1) vs `bloodhound-ce-python`;
   `kerbrute` is FROZEN (v1.0.3, 2019); the apt name is `python3-ldapdomaindump`.
   Flag any doc still naming `crackmapexec`/`cme`, legacy `bloodhound.py`, or a tool
   the manifest dropped or renamed.
2. **Stale flag / subcommand tokens.** A cited flag or subcommand that the current
   tool renamed or removed (impacket script renames, a tool that moved to
   subcommands). Note where you're unsure and a human should verify.
3. **Docs ↔ manifest consistency (both directions).** A tool named in the docs but
   absent from `offensive-packages.txt` (should it be listed, or is it an
   `# UPSTREAM` install?), and a package in the list no doc references.
4. **`CLAUDE.md` "Where things are" ↔ reality.** The tree description vs the files
   that exist.

## How to report

Ranked, most-impactful first; cite `file:line` and the exact edit (old token → new
token / name):

- **Stale (won't match a current box)** — a name or flag that has since changed.
- **Drifted** — renamed but still aliased, or a stale annotation.
- **Clean** — reviewed and still accurate, so a green run is trustworthy.

Report-first. Prose fixes land in `hacktheplanet` / `OFFENSIVE-METHODOLOGY.md` / etc.
**outside** the markers; corpus fixes route upstream to htpx. Do not edit anything
unless I explicitly ask.
