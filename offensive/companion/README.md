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
├── gen-views.sh             # render entry-backed blocks into the flat views (+ --check drift gate)
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

## Source of truth (decided — the hybrid)

The "do the entries become canonical?" question is **resolved**, but not as the
original binary. `hacktheplanet` is 489 lines and most of it is *tradecraft prose*
— dorks, enum sequencing, conditional advice, warnings — that doesn't fit the
entry schema; generating the whole file from rigid entries would either lose that
prose or bloat the schema into freeform markdown. So:

- **Entries are canonical for the paired red↔blue attack/detection slice only.**
  That's the part that genuinely *is* `{id, title, attack, command}`-shaped and
  benefits from ATT&CK tags, slot-fill, and the purple pivot.
- **The flat files stay canonical for everything else** — the prose the schema
  can't hold.
- **Where they overlap, the entry wins via generation.** A flat file opts a block
  in with `<!-- companion:gen ID -->` … `<!-- companion:end ID -->` markers;
  `gen-views.sh` regenerates the marked blocks from the entry, and
  `gen-views.sh --check` (run in CI, `.github/workflows/companion.yml`) fails on
  drift. Content outside the markers is never touched.

This kills drift on the overlap *without* a 60-entry migration and *without*
giving up the rich prose. Workflow: edit the entry → `gen-views.sh` → commit both.

`PURPLE-TEAM.md` is wired up first (4 detections; its SPL has no target slots, so
no placeholder translation). The **red-side `hacktheplanet` retrofit is a
deliberate follow-up** — it needs a `{{slot}}` → `<angle-bracket>` reverse map to
match that file's house style.

## Open decisions (before this graduates from MVP)

1. **ATT&CK tagging is 100% manual** — neither source carries technique IDs today.
   Tagging both colours with the *same* technique IDs turns `pair:` into a
   derivable join (not just a hand-kept link).
2. **Standalone vs in-repo.** If this grows real tooling it likely wants its own
   repo (installable independent of the dotfiles); for now it lives in the Kali
   role layer where the content already is.
