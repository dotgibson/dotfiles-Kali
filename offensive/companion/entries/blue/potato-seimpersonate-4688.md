---
id: potato-seimpersonate-4688
title: Detect Potato privesc (service account → SYSTEM shell, 4688)
detection: splunk-spl
event_ids: [4688]
attack:
  tactic: TA0004
  techniques: [T1134.001]
source: itm4n (PrintSpoofer) & BeichenDream (GodPotato), SeImpersonate abuse
pair: potato-seimpersonate
---

Detection posture: **moderate** — the impersonation itself is a legitimate API,
but the *outcome* is anomalous: a service identity (app-pool / `*$` / NETWORK|LOCAL
SERVICE) spawning an interactive shell, which then runs as SYSTEM. The cleaner
signal is endpoint telemetry — Sysmon 17/18 on the `spoolss`/DCOM named pipe, plus
Sysmon 1 showing the SYSTEM child — but the `4688` service-account-to-shell shape
catches the obvious cases. Tune the service-account list to your environment.

```spl
index=main EventCode=4688 New_Process_Name IN ("*\\cmd.exe","*\\powershell.exe")
| search Creator_Subject_Account_Name IN ("*$","*APPPOOL*","NETWORK SERVICE","LOCAL SERVICE")
| table _time, host, Creator_Subject_Account_Name, New_Process_Name, Token_Elevation_Type
```
