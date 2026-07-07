---
id: npm-publish-audit
title: Detect package publish (npm audit log)
detection: npm-audit-log
event_ids: []
attack:
  tactic: TA0002
  techniques: [T1195.002]
source: npm supply-chain compromise (trojanized publish)
pair: npm-malicious-publish
---

`action=package.publish` is the invariant. Publishing is routine — but it should come from
one known automation identity, so the tell is a publish by a human/unexpected actor, from
an unusual IP, out of hours, or a first-ever publisher on a package with many dependents.
Pin releases to the CI publish identity, allowlist it, and alert on any `package.publish`
outside it; a publish immediately after an `owner_add` or a 2FA change is the high-signal
sequence.

npm audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=npm sourcetype=npm:audit action=package.publish NOT actor.type=ci
| table _time, actor.name, action, package, version, actor.ip
```
