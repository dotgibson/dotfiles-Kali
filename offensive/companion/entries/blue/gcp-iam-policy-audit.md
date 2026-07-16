---
id: gcp-iam-policy-audit
title: Detect IAM policy backdoor (GCP audit, SetIamPolicy binding ADD)
detection: gcp-logging
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
source: GCP IAM abuse (resource IAM policy binding persistence)
pair: gcp-iam-policy-backdoor
---

Every IAM grant lands in Cloud Audit Logs (Admin Activity) as a `SetIamPolicy`
call whose `serviceData.policyDelta.bindingDeltas` carries the `ADD` action, the
role, and the member. Alert on additions of sensitive roles
(`roles/owner`, `roles/editor`, `*Admin`) or grants to unexpected/external
principals — and treat a binding whose member is `allUsers`/`allAuthenticatedUsers`
as an immediate, standalone finding.

GCP Cloud Audit Logs telemetry (native Cloud Logging filter below; also queryable
as Sentinel `GCPAuditLogs`), companion-only — `PURPLE-TEAM.md` is on-prem Windows.
Triage each hit by `protoPayload.authenticationInfo.principalEmail` (the actor)
and the added `member`/`role`.

```text
logName=~"cloudaudit.googleapis.com%2Factivity"
protoPayload.methodName=~"SetIamPolicy$"
protoPayload.serviceData.policyDelta.bindingDeltas.action="ADD"
protoPayload.serviceData.policyDelta.bindingDeltas.role=("roles/owner" OR "roles/editor" OR "roles/resourcemanager.projectIamAdmin")
```
