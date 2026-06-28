---
id: coercion-5145
title: Detect coercion (5145 named-pipe access)
detection: splunk-spl
event_ids: [5145]
attack:
  tactic: TA0006
  techniques: [T1187]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: coerce-petitpotam
---

Every coercion vector reaches the same handful of named pipes — `spoolss`,
`efsrpc`, `lsarpc`, `netlogon`, `lsass` — over `IPC$` with a detailed
file-share-access event (`5145`). Detect on the pipe set, not the tool: the
target endpoint can't change even as the coercion technique does.

```spl
index=main EventCode=5145 Access_Mask="0x3"
| regex Share_Name="(?i).*ipc\$$"
| regex Relative_Target_Name="(?i)(spoolss|efsrpc|lsarpc|netlogon|lsass)"
| table _time, host, Account_Name, Source_Address, Share_Name, Relative_Target_Name
```
