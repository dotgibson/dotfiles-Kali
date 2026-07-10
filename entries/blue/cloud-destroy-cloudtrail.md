---
id: cloud-destroy-cloudtrail
title: Detect cloud data destruction (CloudTrail delete burst)
detection: splunk-cloudtrail
event_ids: []
attack:
  tactic: TA0040
  techniques: [T1485]
source: CloudTrail management events; data-destruction analytics
pair: cloud-snapshot-destroy
---

Destruction is a rare, high-impact verb set on the control plane: `DeleteSnapshot`,
`DeleteDBClusterSnapshot`, `DeleteBucket` / `DeleteObject*` on a versioned bucket,
`DeleteTable`. A single delete may be housekeeping; a *burst* of them across storage
services from one `userIdentity` in a short window — especially from a new IP/role
or with `errorCode` mixed in as it probes — is the pattern. Alert on the aggregate,
and defend structurally with S3 Object Lock, MFA-delete, and cross-account backup
copies the compromised principal can't reach.

```spl
index=aws sourcetype=aws:cloudtrail (eventName IN ("DeleteSnapshot","DeleteDBClusterSnapshot","DeleteDBSnapshot","DeleteBucket","DeleteObject","DeleteObjects","DeleteTable"))
| bucket _time span=5m
| stats count, dc(eventName) as verbs, values(eventName) as which by _time, userIdentity.arn, sourceIPAddress
| where count>10
| sort - count
```
