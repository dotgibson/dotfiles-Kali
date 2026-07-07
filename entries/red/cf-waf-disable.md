---
id: cf-waf-disable
title: Cloudflare WAF/firewall rule disable (open the edge)
section: Cloudflare / edge
phase: Defense Evasion
attack:
  tactic: TA0005
  techniques: [T1562.001]
platform: [cloudflare]
source: Cloudflare defense evasion (WAF/firewall tamper)
pair: cf-waf-disable-audit
---

The WAF and firewall rules are the edge control that blocks the exploit you want to land.
Delete a firewall rule or flip a ruleset's rules to disabled and the origin is exposed to
the traffic they were dropping — no origin change needed, just an API call. The change
writes a Cloudflare audit event on `resource.type=firewall_rule`/`ruleset` with
`action.type=delete`/`update`. (Edge control plane — no slots.)

```sh
# delete a firewall/WAF rule so blocked traffic reaches the origin
curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/<zone>/firewall/rules/<rule_id>" \
  -H "Authorization: Bearer <token>"
```
