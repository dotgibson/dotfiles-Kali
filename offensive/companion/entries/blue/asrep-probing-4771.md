---
id: asrep-probing-4771
title: Detect AS-REP / Kerbrute probing (4771 0x18)
detection: splunk-spl
event_ids: [4771]
attack:
  tactic: TA0006
  techniques: [T1558.004]
source: PURPLE-TEAM.md §"Kerbrute / AS-REP probing"; TrustedSec Actionable Purple Teaming (BH USA 2023)
pair: asreproast-getnpusers
---

One client address generating Kerberos pre-auth failures (`4771`, failure code
`0x18`) across many distinct accounts is the spray/roast tell — a real user
fat-fingers their own name, not five-plus others. Tune the threshold to the
environment.

```spl
index=main EventCode=4771 Failure_Code="0x18"
| stats dc(Account_Name) AS UniqueAccounts by host, Client_Address
| where UniqueAccounts > 5
```
