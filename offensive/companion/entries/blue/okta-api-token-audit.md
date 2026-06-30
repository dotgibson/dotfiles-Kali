---
id: okta-api-token-audit
title: Detect API token creation (Okta System Log)
detection: okta-system-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
source: Okta post-compromise persistence
pair: okta-api-token
---

`system.api_token.create` is the invariant. API tokens should come from a small,
known set of service integrations, so one minted by an unexpected actor — especially
a human admin during an incident — is the tell. Pair with token *use* from a new IP
shortly after, and rotate/scope tokens so a leaked one is bounded.

Okta System Log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=okta sourcetype=OktaIM2:log eventType=system.api_token.create
| table _time, actor.alternateId, target{}.displayName, client.ipAddress
```
