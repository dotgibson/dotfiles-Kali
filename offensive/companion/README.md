# companion — structured, ATT&CK-tagged, red↔blue-paired pentest reference (MVP)

An **experiment / MVP proof**, not yet the source of truth. It restructures a
small slice of the offensive corpus into machine-readable entries so the same
content can be **searched, ATT&CK-tagged, target-substituted, and paired with its
blue detection** — the shape a standalone terminal companion would take.

It is **purely additive**: it does **not** touch `hacktheplanet` or
`PURPLE-TEAM.md`. Those remain canonical. The "which file is the source of truth"
question is deliberately deferred until this earns its place (see *Open
decisions*).

## What's here

```
companion/
├── htpx                     # fzf browser: search → preview attack + its detection → fill slots → clip
└── entries/
    ├── red/*.md             # attacks   (frontmatter + command template)
    └── blue/*.md            # detections (frontmatter + SPL), paired back to red
```

## The entry schema (Markdown + YAML frontmatter)

Typed metadata up top (greppable, `yq`-queryable); raw copy-paste content in the
body (renders in `bat`/`glow`, `rg`-searchable). One file per entry.

```yaml
id:         stable kebab key
title:      human label
section:    matches a hacktheplanet fold name
phase:      engagement phase
attack:     { tactic: TA0006, techniques: [T1558.003] }   # MITRE ATT&CK
platform:   [windows, linux, network]
source:     citation
pair:       <id of the paired entry in the other colour>  # or null
```

Command templates normalize the corpus's `<angle-bracket>` placeholders to
`{{slots}}` (`{{rhost}}`, `{{lhost}}`, `{{user}}`, `{{password}}`, `{{domain}}`,
`{{hostname}}`, `{{nthash}}`, `{{port}}`, `{{share}}`).

## Using it

```sh
export RHOST=10.10.10.5 DOMAIN=corp.local USER_T=svc_sql PASS='…'
htpx            # pick an attack; preview shows it + its blue detection;
                # the command is slot-filled and copied via `clip`
```

`htpx` is on the shell as of bootstrap: `companion/` symlinks to `~/companion`
and `offensive.zsh` defines an `htpx` function. From a checkout you can also run
`./htpx` directly. It needs `fzf`; `bat` (preview) and `clip` (Core clipboard)
are used if present, else it falls back to `cat`/stdout. No `yq` dependency —
`htpx` reads only the scalar top-level fields it needs (`title:`, `pair:`) from
the frontmatter with `awk` (the nested `attack:` block is for humans/greppers).

## The differentiator

The `pair:` field makes the **purple pivot** nearly free: selecting an attack
previews its detection right beside it (see Kerberoast ↔ `4769`, DCSync ↔ `4662`).
No mainstream tool ships attacks paired with the telemetry they trip.

## Scope of this MVP

4 paired concepts (Kerberoast ↔ `4769`, DCSync ↔ `4662`, AS-REP roasting ↔
`4771`, pass-the-hash ↔ `4624`) + 1 unpaired recon entry (SMB enum) — enough to
prove the schema, the purple pivot, and slot-substitution across multiple ATT&CK
tactics (Credential Access, Lateral Movement, Discovery).

## Open decisions (before this graduates from MVP)

1. **Source of truth / drift.** Either these entries *become* canonical (generate
   the folded `hacktheplanet`/`PURPLE-TEAM.md` views *from* them), or they stay a
   secondary view (and risk drift — the repo's own `/doc-audit` worry). Pick one
   before converting the full ~60 entries.
2. **ATT&CK tagging is 100% manual** — neither source carries technique IDs today.
   Tagging both colours with the *same* technique IDs turns `pair:` into a
   derivable join (not just a hand-kept link).
3. **Standalone vs in-repo.** If this grows real tooling it likely wants its own
   repo (installable independent of the dotfiles); for now it lives in the Kali
   role layer where the content already is.
