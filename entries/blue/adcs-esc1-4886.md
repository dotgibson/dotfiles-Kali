---
id: adcs-esc1-4886
title: Detect AD CS SAN abuse (4886 ESC1/relay)
detection: splunk-spl
event_ids: [4886, 5136]
attack:
  tactic: TA0006
  techniques: [T1649]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: adcs-esc1-certipy
---

The invariant of ESC1 (and relay-to-ADCS) is a certificate request whose
subject-alternative-name names a *different* principal than the requester — pull
the requested SAN out of the `4886` event and compare it to the `Requester`.

```spl
index=main EventCode=4886
| rex field=Message "SAN\s*:.*upn=(?<RequestedSAN>.+$)"
| table _time, host, Requester, RequestedSAN
```

Also watch `5136` writes to the `userCertificate` attribute.
