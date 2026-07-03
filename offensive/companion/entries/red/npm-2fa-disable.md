---
id: npm-2fa-disable
title: npm publish-2FA disable (open the publish path)
section: npm / registry
phase: Defense Evasion
attack:
  tactic: TA0005
  techniques: [T1562.001]
platform: [npm]
source: npm supply-chain evasion (2FA requirement tamper)
pair: npm-2fa-audit
---

The org/package "require two-factor to publish" setting is the control that stops a bare
stolen token from shipping a release. Flip it to disabled and an automation token publishes
with no second factor and no interactive prompt — quietly clearing the path for the
malicious-publish step. The change writes an npm audit event `action=org.set_2fa` with the
mode set to `disabled`. (Registry control plane — no slots.)

```sh
# drop the org 2FA-to-publish requirement so a stolen token can publish unattended
npm org set <org> 2fa-mode=disabled
```
