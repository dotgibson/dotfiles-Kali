---
id: asrep-probing-4771
title: Detect AS-REP roast (4768 no-preauth) + Kerbrute probing (4771)
detection: splunk-spl
event_ids: [4768, 4771]
attack:
  tactic: TA0006
  techniques: [T1558.004]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: asreproast-getnpusers
---

Detect on the invariant, not the IOC. The roastable AS-REP is a *successful*
`4768` TGT request with **pre-authentication type 0** (no pre-auth) for a
non-machine account — that is the account `GetNPUsers`/`--asreproast` actually
harvests. The AS-REP is issued under the account's long-term key — RC4 (`0x17`)
where it's enabled, AES (`0x11`/`0x12`) in RC4-disabled domains — and cracked
offline (`hashcat -m 18200` for the RC4 case). Unlike Kerberoasting the attacker
doesn't force the etype, so the *invariant* is the type-0 pre-auth on a user, not
the negotiated cipher — key on it directly and don't constrain the encryption
type, or AES-only domains slip through. A normal account pre-auths with type 2
(encrypted timestamp), so type 0 on a user is the tell. The
one-source-to-many-accounts `4771 0x18` burst is a *secondary* enumeration tell:
it fires on wrong-password pre-auth failures against pre-auth-**required**
accounts (Kerbrute enum / spraying), never on the roast itself — so keep it, but
alert on the `4768` first.

```spl
index=main EventCode=4768 Pre_Authentication_Type=0 Account_Name!="*$"
| stats count values(Account_Name) AS Accounts by Client_Address
| sort -count
```

Secondary tell — Kerbrute enumeration / spray burst (one source, many accounts,
wrong-password pre-auth failures). Tune the threshold to the environment:

```spl
index=main EventCode=4771 Failure_Code="0x18"
| stats dc(Account_Name) AS UniqueAccounts by host, Client_Address
| where UniqueAccounts > 5
```
