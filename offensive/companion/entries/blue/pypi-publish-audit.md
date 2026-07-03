---
id: pypi-publish-audit
title: Detect token release upload (PyPI journal)
detection: pypi-audit-log
event_ids: []
attack:
  tactic: TA0002
  techniques: [T1195.002]
source: PyPI supply-chain compromise (trojanized release)
pair: pypi-malicious-publish
---

`action="new release"` NOT published via a trusted publisher is the invariant. Trusted
publishing (OIDC) is the secure norm, so a release uploaded with a long-lived API token — a
`new release` where `publisher_type` is not `trusted_publisher` — is the higher-signal case:
it is how a stolen token ships a trojanized version, and it bypasses the OIDC path entirely.
Alert on token-based uploads to projects that normally publish via trusted publishing, and
on any first-ever uploader of a widely depended-on package.

PyPI journal telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=pypi sourcetype=pypi:journal action="new release" NOT publisher_type=trusted_publisher
| table _time, actor, action, project, version, publisher_type
```
