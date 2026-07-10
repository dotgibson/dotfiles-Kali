---
id: domain-fronting-sni-mismatch
title: Detect domain fronting (TLS SNI vs HTTP Host mismatch)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0011
  techniques: [T1090.004]
source: TLS SNI / HTTP Host correlation (Zeek ssl.log + http.log)
pair: domain-fronting-cdn
---

Fronting only works because the SNI and the inner Host differ; where you can see
both, the mismatch is the invariant. With a TLS-inspecting proxy (or Zeek pairing
`ssl.log` SNI to the decrypted `http.log` Host), alert when the SNI's registrable
domain differs from the Host header for the same connection — the CDN case that
isn't a legitimate multi-tenant vhost. Without decryption, fall back to
non-browser processes making TLS to CDN edges with rare/young inner destinations.

```spl
index=zeek (sourcetype=zeek:ssl OR sourcetype=zeek:http)
| transaction uid maxspan=30s
| eval sni_dom=replace(server_name,"^.*\.([^.]+\.[^.]+)$","\1")
| eval host_dom=replace(host,"^.*\.([^.]+\.[^.]+)$","\1")
| where isnotnull(server_name) AND isnotnull(host) AND sni_dom!=host_dom
| table _time, id.orig_h, server_name, host, uri
```
