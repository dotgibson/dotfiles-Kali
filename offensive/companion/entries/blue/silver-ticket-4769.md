---
id: silver-ticket-4769
title: Detect Silver Ticket (Kerberos service logon with no 4769)
detection: splunk-spl
event_ids: [4624, 4769]
attack:
  tactic: TA0006
  techniques: [T1558.002]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: silver-ticket
---

Detection posture: **soft** — a silver ticket's whole point is that it never
touches the DC, so there is no `4769` to alert on directly. The realistic tell is
the *absence*: a Kerberos network logon (`4624` type 3) landing on a service host
for an account the DC issued no service ticket (`4769`) to in the window. The join
key is `Account_Name` — `4769` is logged on the DC and `4624` on the member host,
so source/host fields don't share values across the two. Set the search/alert
**time range** to your ticket-renewal cadence (a few hours); the subsearch inherits
it, so don't hard-code a window inside it. The durable backstop is enabling PAC
validation, which rejects the forged ticket outright.

```spl
index=main EventCode=4624 Logon_Type=3 Authentication_Package_Name="Kerberos" Account_Name!="*$"
| join type=left Account_Name
    [ search index=main EventCode=4769 | stats count AS tgs_issued by Account_Name ]
| where isnull(tgs_issued)
| table _time, host, Account_Name, Source_Network_Address
```
