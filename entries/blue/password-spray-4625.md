---
id: password-spray-4625
title: Detect password spray (4625 one source, many accounts)
detection: splunk-spl
event_ids: [4625]
attack:
  tactic: TA0006
  techniques: [T1110.003]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: password-spray-kerbrute
---

The shape, not the count: one source address failing (`4625`) against many
*distinct* accounts in a short window — the inverse of a single user who simply
forgot their password. Counting distinct accounts per source beats a raw
failure-rate threshold because the spray is deliberately slow.

```spl
index=main EventCode=4625 NOT (Source_Network_Address IN ("-","127.0.0.1"))
| eval Account=mvindex(Account_Name,1)
| stats dc(Account) AS Accounts by host, Source_Network_Address
| where Accounts > 10 | sort -Accounts
```
