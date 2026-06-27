---
id: lateral-4624-fanout
title: Detect lateral movement (4624 type-3 fan-out)
detection: splunk-spl
event_ids: [4624]
attack:
  tactic: TA0008
  techniques: [T1550.002]
source: PURPLE-TEAM.md §"Lateral movement (one source, many hosts)"; TrustedSec Actionable Purple Teaming (BH USA 2023)
pair: pth-lateral-nxc
---

One source address logging on (`4624` type 3, network) to many distinct hosts in
a short window is the reuse pattern — pass-the-hash, sprayed creds, or a relay all
fan out the same way. The auth succeeds, so the signal is the breadth, not a
failure.

```spl
index=main EventCode=4624 Logon_Type=3 NOT (Source_Network_Address IN ("-","::1"))
| stats dc(host) AS Hosts by Source_Network_Address
| where Hosts > 2 | sort -Hosts
```
