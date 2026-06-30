---
id: wmi-subscription-sysmon
title: Detect WMI subscription persistence (Sysmon 19/20/21)
detection: splunk-spl
event_ids: [19, 20, 21]
attack:
  tactic: TA0003
  techniques: [T1546.003]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: wmi-subscription
---

The Security log barely sees this; Sysmon does. Sysmon `19` (WmiFilter), `20`
(WmiConsumer), and `21` (WmiBinding) fire when a filter/consumer/binding is
registered. A `CommandLineEventConsumer` (event `20`) whose `Destination` runs
PowerShell/cmd/a LOLBin is the high-fidelity tell — legitimate permanent
consumers are rare and usually from known management software, so allowlist those
and alert on the rest. Requires Sysmon with WMI eventing (schema ≥ 4.1).

```spl
index=main (EventCode=20 OR EventCode=21)
| regex Destination="(?i)(powershell|cmd\.exe|mshta|wscript|cscript|rundll32|-enc|FromBase64)"
| table _time, host, User, Name, Type, Destination, Query
```
