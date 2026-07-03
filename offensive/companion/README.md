# ⚔️ htpx

**Every attack, beside its detection.** An ATT&CK-tagged, red↔blue paired
corpus — browse an attack beside its detection, fill `{{slots}}`, clip.

`fzf` · `mitre-attack` · `purple-team`

[![showcase](https://img.shields.io/badge/showcase-live-7aa2f7?style=flat-square)](https://dotgibson.github.io/dotfiles-web/) ![purple team](https://img.shields.io/badge/purple--team-bb9af7?style=flat-square)

---

**companion** — structured, ATT&CK-tagged, red↔blue-paired pentest reference

Restructures the offensive corpus into machine-readable entries so the same
content can be **searched, ATT&CK-tagged, target-substituted, and paired with its
blue detection** — the shape a standalone terminal companion would take.

For the paired red↔blue **attack/detection slice it covers, the entries are the
source of truth**: where they overlap `hacktheplanet` / `PURPLE-TEAM.md`, the flat
files' blocks are _generated_ from the entries (inside `companion:gen` markers) and
CI rejects drift. Everything those flat files hold that _isn't_ a clean paired
attack — the tradecraft prose, dorks, multi-step chains — stays hand-authored and
canonical there. See _Source of truth_ below for the full model.

## What's here

```
companion/
├── htpx                     # fzf browser: search → preview attack + its detection → fill slots → clip
├── gen-views.sh             # render entry-backed blocks into the flat views (+ --check drift gate)
└── entries/
    ├── red/*.md             # attacks   (frontmatter + command template)
    └── blue/*.md            # detections (frontmatter + SPL), paired back to red
```

This directory is **host-agnostic** (host-agnostic so it lives in its own repo `dotgibson/htpx` and is vendored back like `core/`): `gen-views.sh`'s flat-view targets default to
this repo's `PURPLE-TEAM.md` + `offensive/hacktheplanet` (repo-root-relative) but
can be overridden with
`$COMPANION_TARGETS` (and a target that isn't present is skipped, so a standalone
checkout with no flat views is still green), and `htpx` copies via the first of
`clip`/`pbcopy`/`wl-copy`/`xclip`/`xsel` it finds (stdout otherwise) rather than
requiring the Core `clip` helper.

## The entry schema (Markdown + YAML frontmatter)

Typed metadata up top (greppable, `yq`-queryable); raw copy-paste content in the
body (renders in `bat`/`glow`, `rg`-searchable). One file per entry.

```yaml
id: stable kebab key
title: human label
section: matches a hacktheplanet fold name
phase: engagement phase
attack: { tactic: TA0006, techniques: [T1558.003] } # MITRE ATT&CK
platform: [windows, linux, network]
source: citation
pair: <id of the paired entry in the other colour> # or null
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

## Corpus

65 paired concepts + 1 unpaired recon entry (SMB enum), spanning Credential
Access, Privilege Escalation, Lateral Movement, Persistence, Execution, Defense
Evasion, Collection, Exfiltration, and Discovery — on-prem AD, a multi-cloud slice
(Entra/M365, AWS, GCP), Kubernetes, Okta, Google Workspace, CI/CD (GitHub Actions,
GitLab, Jenkins), the Harbor container registry, HashiCorp Vault, Terraform Cloud,
the Snowflake data cloud, the Cloudflare edge, and the npm registry:

| Attack (red)                      | Detection (blue)                                      | ATT&CK    |
| --------------------------------- | ----------------------------------------------------- | --------- |
| Kerberoast SPNs                   | `4769` RC4 TGS                                        | T1558.003 |
| AS-REP roast                      | `4771` pre-auth `0x18`                                | T1558.004 |
| Password spray (kerbrute)         | `4625` one source, many accounts                      | T1110.003 |
| DCSync                            | `4662` replication                                    | T1003.006 |
| Pass-the-hash lateral             | `4624` type-3 fan-out                                 | T1550.002 |
| NTLM relay                        | `4624` workstation mismatch                           | T1557.001 |
| Coerce DC (PetitPotam/printerbug) | `5145` named-pipe access                              | T1187     |
| AD CS ESC1 (certipy)              | `4886` SAN mismatch                                   | T1649     |
| Remote LSASS dump (lsassy)        | `4656` dump-shaped handle                             | T1003.001 |
| RDP session hijack (tscon)        | `4688` tscon `/dest:rdp-tcp#`                         | T1563.002 |
| Shadow Credentials (certipy)      | `5136` msDS-KeyCredentialLink write                   | T1556     |
| RBCD (impacket)                   | `5136` msDS-AllowedToActOnBehalfOfOtherIdentity write | T1098     |
| Unconstrained delegation → DC TGT | `4624` DC machine-acct → non-DC _(soft)_              | T1558     |
| DPAPI domain backup key           | `5145` protected_storage pipe                         | T1555     |
| SeImpersonate → SYSTEM (Potato)   | `4688` service-acct → SYSTEM shell _(moderate)_       | T1134.001 |
| Device-code phishing (Entra)      | Entra sign-in `deviceCode` flow _(KQL, cloud)_        | T1528     |
| Golden Ticket (forged TGT)        | `4769` TGS with no preceding `4768`                   | T1558.001 |
| GPP cpassword (SYSVOL)            | `5145` SYSVOL `Groups.xml` read                       | T1552.006 |
| NTDS.dit dump (ntdsutil/VSS)      | `4688` ntdsutil/vssadmin + `8222`                     | T1003.003 |
| WMI exec (impacket-wmiexec)       | `4688` `WmiPrvSE.exe` child shell                     | T1047     |
| Scheduled-task persistence        | `4698` task created (suspicious action)               | T1053.005 |
| WMI subscription persistence      | Sysmon `19`/`20`/`21` consumer/binding               | T1546.003 |
| Silver Ticket (forged TGS)        | `4624` Kerberos logon, no `4769` _(soft)_            | T1558.002 |
| DCShadow (rogue DC)               | `4742` `GC/` SPN write + `5137`/`4662`               | T1207     |
| Illicit consent grant (Entra)     | Entra audit "Consent to application" _(KQL, cloud)_  | T1528     |
| SP credential backdoor (Entra)    | Entra audit "Add SP credentials" _(KQL, cloud)_     | T1098.001 |
| Privileged pod → node escape (K8s) | audit: privileged/hostPID/hostPath pod create       | T1610/T1611 |
| Pod exec / attach (K8s)           | audit: `pods/exec` subresource create                | T1609     |
| Cluster-admin binding (K8s)       | audit: roleRef `cluster-admin` binding               | T1098     |
| MFA reset → takeover (Okta)       | System Log `user.mfa.factor.reset_all`               | T1556.006 |
| API token persistence (Okta)      | System Log `system.api_token.create`                 | T1098     |
| Rogue IdP backdoor (Okta)         | System Log `system.idp.lifecycle.create`             | T1556     |
| IAM access-key backdoor (AWS)     | CloudTrail `CreateAccessKey` actor≠target _(cloud)_  | T1098.001 |
| Console takeover (AWS)            | CloudTrail Create/UpdateLoginProfile _(cloud)_       | T1098     |
| SA key creation (GCP)            | Cloud Audit `CreateServiceAccountKey` _(cloud)_      | T1098.001 |
| Rogue self-hosted runner (GitHub) | audit `self_hosted_runner.created` _(cloud)_         | T1543     |
| Branch-protection tamper (GitHub) | audit `protected_branch.destroy` / `protected_branch.policy_override` _(cloud)_ | T1562.001 |
| Deploy-key/PAT backdoor (GitHub)  | audit `repo.create_deploy_key` / `personal_access_token.access_granted` _(cloud)_ | T1098 |
| Backdoored image over trusted tag (Harbor) | audit `operation=push` artifact _(registry)_       | T1525     |
| Robot-account backdoor (Harbor)   | audit `operation=create` `resource_type=robot` _(registry)_ | T1098     |
| Artifact deletion (Harbor)        | audit `operation=delete` artifact/repository _(registry)_ | T1070     |
| Rogue runner association (GitLab) | audit `set_runner_associated_projects` _(cloud)_     | T1543     |
| Protected-branch tamper (GitLab)  | audit `protected_branch_removed` / `protected_branch_created` _(cloud)_ | T1562.001 |
| Access/deploy-token backdoor (GitLab) | audit `project_access_token_created` / `personal_access_token_created` / `deploy_token_created` _(cloud)_ | T1098 |
| Bulk KV secret read (Vault)       | audit `read` breadth over `secret/` paths _(secrets)_ | T1555     |
| Rogue AppRole backdoor (Vault)    | audit create/update on `auth/approle/role/` _(secrets)_ | T1098     |
| Audit-device disable (Vault)      | audit `delete` on `sys/audit/` path _(secrets)_      | T1562.001 |
| Rogue agent pool (Terraform)      | audit `agent_pool` `create` _(IaC)_                  | T1543     |
| Org/team token backdoor (Terraform) | audit `authentication_token` `create` _(IaC)_      | T1098     |
| Variable injection (Terraform)    | audit `variable` `create`/`update` _(IaC)_           | T1072     |
| Script Console RCE (Jenkins)      | audit `/script`/`/scriptText` request _(CI)_         | T1059     |
| User API token backdoor (Jenkins) | audit `generateNewToken` request _(CI)_              | T1098     |
| Job/pipeline backdoor (Jenkins)   | audit `/createItem`/`/job/<name>/configSubmit` request _(CI)_   | T1072     |
| Data exfil via COPY INTO (Snowflake) | `QUERY_HISTORY` `QUERY_TYPE=UNLOAD` _(data)_       | T1567.002 |
| Backdoor user + ACCOUNTADMIN (Snowflake) | `QUERY_HISTORY` `CREATE_USER`/priv `GRANT` _(data)_ | T1136.003 |
| Network-policy tamper (Snowflake) | `QUERY_HISTORY` `NETWORK POLICY` change _(data)_      | T1562.007 |
| Illicit OAuth grant (Workspace)   | token audit `authorize` _(cloud)_                    | T1528     |
| Super-admin grant (Workspace)     | admin audit `GRANT_DELEGATED_ADMIN_PRIVILEGES` _(cloud)_ | T1098.003 |
| External mail forwarding (Workspace) | audit `email_forwarding_out_of_domain` _(cloud)_  | T1114.003 |
| API token backdoor (Cloudflare)   | audit `resource.type=api_token` `create` _(edge)_    | T1098     |
| WAF/firewall rule disable (Cloudflare) | audit `firewall_rule`/`ruleset` `delete`/`update` _(edge)_ | T1562.001 |
| Malicious Worker deploy (Cloudflare) | audit `resource.type=worker`/`workers_script` `create`/`update` _(edge)_ | T1648     |
| Malicious package publish (npm)   | audit `package.publish` off-CI actor _(registry)_    | T1195.002 |
| Rogue maintainer add (npm)        | audit `package.owner_add` / `team.user_add` _(registry)_ | T1098   |
| Publish-2FA disable (npm)         | audit `org.set_2fa` `two_factor_auth=disabled` _(registry)_ | T1562.001 |

Growth is mechanical now that the drift gate exists: author the red+blue entry
pair, mark the matching flat blocks, then `gen-views.sh`. For **on-prem** pairs the
blue detection generates into `PURPLE-TEAM.md` (cloud pairs are companion-only —
see below). The red side generates into
`hacktheplanet` whenever its commands are slot-mappable (even multi-step — see
RBCD); only commands that carry inline comments or are scattered across existing
folds stay hand-authored. Either way the entry powers `htpx` and the paired
preview. **Net-new** techniques (Shadow Credentials, RBCD) were authored as
entries first and flowed into _both_ flat views via the bridge.

**Cloud pairs are companion-only.** The device-code-phishing pair is the first
outside on-prem AD: its detection is an Entra sign-in log (KQL), which doesn't
belong in `PURPLE-TEAM.md`'s Windows-Security-log SPL frame, so it isn't generated
into either flat view — it lives only in the entries, where `htpx` still gives the
full purple pivot. A clean demonstration that the entries are a superset of the
on-prem flat references (and a natural seam for a standalone/cloud split).

## Source of truth (decided — the hybrid)

The "do the entries become canonical?" question is **resolved**, but not as the
original binary. `hacktheplanet` is 489 lines and most of it is _tradecraft prose_
— dorks, enum sequencing, conditional advice, warnings — that doesn't fit the
entry schema; generating the whole file from rigid entries would either lose that
prose or bloat the schema into freeform markdown. So:

- **Entries are canonical for the paired red↔blue attack/detection slice only.**
  That's the part that genuinely _is_ `{id, title, attack, command}`-shaped and
  benefits from ATT&CK tags, slot-fill, and the purple pivot.
- **The flat files stay canonical for everything else** — the prose the schema
  can't hold.
- **Where they overlap, the entry wins via generation.** A flat file opts a block
  in with `companion:gen ID` … `companion:end ID` markers — HTML comments in
  markdown (`PURPLE-TEAM.md`), `#` comments in the shell-style `hacktheplanet`.
  `gen-views.sh` regenerates the marked blocks from the entry, and
  `gen-views.sh --check` (run in CI, `.github/workflows/companion.yml`) fails on
  drift. Content outside the markers is never touched.

This kills drift on the overlap _without_ a 60-entry migration and _without_
giving up the rich prose. Workflow: edit the entry → `gen-views.sh` → commit both.

**Both sides are wired.** The render shape keys off the entry's colour:

- **Blue** (`PURPLE-TEAM.md`) — `**title**` + prose + a fenced `spl` detection
  block. Its SPL has no target slots, so no placeholder translation.
- **Red** (`hacktheplanet`) — just the raw command lines in that file's terse,
  command-first house style, with the entry's `{{slots}}` reverse-mapped to its
  `<angle-bracket>` vocabulary (`{{rhost}}`→`<ip_address>`, `{{nthash}}`→`<NThash>`,
  …; see `SLOT_TO_ANGLE` in `gen-views.sh`). Only attacks whose commands are
  contiguous and map cleanly are marked (Kerberoast, AS-REP, DCSync); ones whose
  lines are scattered across folds or carry inline notes (SMB enum, pass-the-hash)
  stay hand-authored — the entry owns only what it cleanly owns.

## Open decisions (before this graduates from MVP)

1. **ATT&CK tagging is 100% manual** — neither source carries technique IDs today.
   Tagging both colours with the _same_ technique IDs turns `pair:` into a
   derivable join (not just a hand-kept link).
2. **Standalone vs in-repo — resolved.** This now lives in its own repo
   (`dotgibson/htpx`) and is vendored back into `dotfiles-Kali` at
   `offensive/companion/` via `git subtree` (provenance in Kali's `companion.lock`,
   resynced with `scripts/sync-companion.sh`). Kali consumes it; this repo is the
   source of truth.
