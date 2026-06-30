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

After compromising an admin, mint a static API token: long-lived, MFA-free,
non-interactive, carrying the creator's privileges, and surviving the admin's
password/session reset — a clean tenant backdoor. SSWS tokens are created in the
**Admin Console only** (Security → API → Tokens → Create Token) — there is no REST
endpoint that mints one (the API only lists/revokes them); the supported
programmatic alternative is an OAuth 2.0 service app with a private-key JWT. Either
path writes `system.api_token.create`. (Cloud IdP — no slots.)

```sh
# create it in the Admin Console (Security → API → Tokens → Create Token), then use it:
curl -s "https://<org>.okta.com/api/v1/users/me" -H "Authorization: SSWS <new-token>"
```
