---
id: gws-mail-forward-audit
title: Detect external mail forwarding (Google Workspace audit)
detection: gws-audit-log
event_ids: []
attack:
  tactic: TA0009
  techniques: [T1114.003]
source: Google Workspace BEC (external auto-forwarding)
pair: gws-mail-forward
---

`email_forwarding_out_of_domain` is the invariant — a mailbox set to auto-forward outside
the org, the durable exfil channel behind most BEC. Enabling it is uncommon and rarely
legitimate for external destinations, so alert on any occurrence, prioritize forwarding to
new/free-mail domains, and pair with the admin setting that disables automatic external
forwarding org-wide. Also watch delegate-access and filter-create events for the same intent.

Google Workspace audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=gws sourcetype=gws:reports:user_accounts eventName=email_forwarding_out_of_domain
| table _time, actor.email, forwarding_email, ipAddress
```
