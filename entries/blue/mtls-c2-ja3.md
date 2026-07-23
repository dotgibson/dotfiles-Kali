---
id: mtls-c2-ja3
title: Detect encrypted C2 by TLS fingerprint (JA3 / JA3S)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0011
  techniques: [T1573.002]
source: Zeek ssl.log JA3/JA3S fingerprinting
pair: mtls-c2-sliver
---

Encryption hides the payload, not the handshake. Each implant's TLS ClientHello
(cipher list + extension order) hashes to a stable JA3, and the C2 server's
ServerHello to a JA3S; frameworks reuse these across builds, so a known-implant
JA3/JA3S pair is a high-fidelity match regardless of destination or sleep. Maintain
a blocklist of framework fingerprints (Zeek + community JA3 sets) and alert on any
hit; then hunt self-signed / very-short-chain certs to a rare destination as the
unknown-implant fallback. Prefer **JA4/JA4S** (FoxIO, 2023+, emitted by current
Zeek) where available — JA3 is increasingly defeated by TLS randomization (uTLS),
and JA4 is its more resilient successor.

```spl
index=zeek sourcetype=zeek:ssl
| lookup ja3_c2_implants ja3 OUTPUT framework AS ja3_hit
| lookup ja3s_c2_servers ja3s OUTPUT framework AS ja3s_hit
| where isnotnull(ja3_hit) OR isnotnull(ja3s_hit)
| table _time, id.orig_h, id.resp_h, server_name, ja3, ja3s, ja3_hit, ja3s_hit
```
