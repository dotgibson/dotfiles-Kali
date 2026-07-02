---
id: cf-waf-disable-audit
title: Detect WAF/firewall rule disable (Cloudflare audit log)
detection: cloudflare-audit-log
event_ids: []
attack:
  tactic: TA0005
  techniques: [T1562.001]
source: Cloudflare defense evasion (WAF/firewall tamper)
pair: cf-waf-disable
---

A `delete`/`update` on `resource.type=firewall_rule`/`ruleset` is the invariant — the edge
control being removed or weakened. These changes are rare and high-impact (they gate what
reaches the origin), so any by an unexpected actor, or a disable quickly followed by
anomalous origin traffic, warrants review. Manage rules as code and alert on out-of-band
firewall/WAF changes; a delete followed by a re-create is the cover-tracks shape.

Cloudflare audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=cloudflare sourcetype=cloudflare:audit resource.type IN (firewall_rule, ruleset) action.type IN (delete, update)
| table _time, actor.email, resource.type, action.type, action.description
```
