---
id: vault-secret-read-audit
title: Detect bulk secret read (Vault audit log)
detection: vault-audit-log
event_ids: []
attack:
  tactic: TA0006
  techniques: [T1555]
source: HashiCorp Vault post-compromise (secret-store exfil)
pair: vault-secret-exfil
---

The invariant is **breadth**: one identity issuing `read` against many distinct KV paths
in a short window (a single read is normal automation). Profile each token's usual
secret set and alert on a token reading well beyond it, on a human/interactive token
sweeping `secret/`, or on reads from a new source IP. Scope tokens tightly and prefer
short leases so a stolen one drains less.

HashiCorp Vault audit-device telemetry, companion-only — `PURPLE-TEAM.md` is on-prem
Windows.

```spl
index=vault sourcetype=vault:audit type=request request.operation=read request.path=secret/*
| stats dc(request.path) AS distinct_paths, min(_time) AS first, max(_time) AS last BY auth.display_name, request.remote_address
| where distinct_paths > 25
```
