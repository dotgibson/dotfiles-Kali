---
id: npm-2fa-audit
title: Detect publish-2FA disable (npm audit log)
detection: npm-audit-log
event_ids: []
attack:
  tactic: TA0005
  techniques: [T1562.001]
source: npm supply-chain evasion (2FA requirement tamper)
pair: npm-2fa-disable
---

`action=org.set_2fa` with the mode set to `disabled` is the invariant — the publish
protection being removed. Turning off require-2FA-to-publish is rare and high-impact (it
gates whether a bare token can ship a release), so any disable warrants review, especially
one soon followed by a `package.publish`. Manage the 2FA policy as a locked org setting and
alert on any downgrade; a disable-then-publish-then-re-enable is the cover-tracks shape.

npm audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=npm sourcetype=npm:audit action=org.set_2fa two_factor_auth=disabled
| table _time, actor.name, action, org, two_factor_auth
```
