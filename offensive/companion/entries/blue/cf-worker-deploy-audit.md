---
id: cf-worker-deploy-audit
title: Detect Worker deploy (Cloudflare audit log)
detection: cloudflare-audit-log
event_ids: []
attack:
  tactic: TA0002
  techniques: [T1648]
source: Cloudflare abuse (malicious Worker deploy)
pair: cf-worker-deploy
---

A `create`/`update` on `resource.type=worker`/`workers_script` is the invariant — code
published to the edge in front of live traffic. Worker deploys should come from CI, so one
by a human/unexpected actor, outside the deploy pipeline, or on a sensitive zone is the
tell for edge interception/exfil. Require Workers to ship via version-controlled CI, and
alert on API-side script writes that bypass it; diff the deployed script against its
source.

Cloudflare audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=cloudflare sourcetype=cloudflare:audit resource.type IN (worker, workers_script) action.type IN (create, update)
| table _time, actor.email, resource.type, action.type, action.description
```
