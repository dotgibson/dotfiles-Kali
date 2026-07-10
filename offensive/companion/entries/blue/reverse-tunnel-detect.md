---
id: reverse-tunnel-detect
title: Detect reverse tunnels (long-lived outbound session + JA3)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0011
  techniques: [T1572]
source: Zeek conn.log duration/volume + JA3 tunneling fingerprints
pair: reverse-tunnel-chisel
---

A tunnel collapses many sessions into one, so it shows up as a single outbound
connection that lives far longer and moves far more bytes — bidirectionally — than
normal client traffic, often to a raw IP or a young domain on an odd port. From Zeek
`conn.log`, alert on long-duration external connections with high byte counts in
both directions from a server/workstation that shouldn't hold persistent outbound
sessions; enrich with chisel/ligolo JA3 fingerprints and destination reputation.

```spl
index=zeek sourcetype=zeek:conn
| where NOT (cidrmatch("10.0.0.0/8",id.resp_h) OR cidrmatch("172.16.0.0/12",id.resp_h) OR cidrmatch("192.168.0.0/16",id.resp_h))
| where duration>1800 AND orig_bytes>1000000 AND resp_bytes>1000000
| table _time, id.orig_h, id.resp_h, id.resp_p, duration, orig_bytes, resp_bytes, ja3
| sort - duration
```
