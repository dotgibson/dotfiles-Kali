---
id: consent-grant-auditlogs
title: Detect illicit consent grant (Entra audit, Consent to application)
detection: kql-entra-audit
event_ids: []
attack:
  tactic: TA0006
  techniques: [T1528]
source: Microsoft / Mandiant, illicit consent grant attacks
pair: consent-grant
---

The invariant is the consent event itself: an Entra audit "Consent to application"
where a *user* (not an admin) grants delegated permissions to a third-party app —
especially high-value mail/file scopes. Hunt `AuditLogs` for the operation and
triage by the app, the scopes, and whether the app is newly registered or
unverified. Restricting user consent to verified-publisher / low-risk scopes turns
this from detection into prevention.

This is **Entra audit telemetry (KQL / Sentinel), not the Windows Security log**,
so it lives only here in the companion — `PURPLE-TEAM.md` is scoped to on-prem
Splunk and deliberately doesn't carry cloud detections.

```kql
AuditLogs
| where OperationName has "Consent to application"
| mv-expand mp = TargetResources[0].modifiedProperties
| extend scopes = tostring(mp.newValue)
| where scopes has_any ("Mail.Read","Mail.ReadWrite","Files.Read.All","offline_access","Sites.Read.All")
| project TimeGenerated, InitiatedBy, OperationName, scopes
```
