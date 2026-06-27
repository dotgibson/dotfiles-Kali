# Purple Team — detections for the attacks in `hacktheplanet`

The offensive half of an engagement lives in
[`offensive/hacktheplanet`](offensive/hacktheplanet). This file is its mirror:
**what each of those attacks looks like to the defender**, and the philosophy
behind hunting it. Field notes from TrustedSec's *Actionable Purple Teaming*
(Black Hat USA 2023), generalized out of the lab.

> Why this lives in an offensive repo: a red operator who knows exactly which
> event ID their action writes is a better operator. Every command in
> `hacktheplanet` has a telemetry footprint — knowing it is OPSEC, and validating
> it is the entire point of purple teaming.

---

## The philosophy

- **Purple, not red-then-blue.** Run the attack and watch the detection fire *in
  the same session*. A detection nobody has triggered on purpose is a hypothesis,
  not a control. Execute → confirm the alert → tune → repeat.
- **Detect on the invariant, not the IOC.** Tool names, file hashes and ports
  change for free. Detect the thing the technique *can't* avoid: Kerberoasting
  needs an RC4 service ticket (`4769`, downgraded encryption); DCSync needs the
  directory-replication right (`4662`); a relay produces a logon whose source
  host ≠ the account's own host. Those don't change when the attacker swaps tools.
- **Honey tokens are the cheapest high-signal control.** A fake user that no
  human should ever touch, a fake SPN no service should ever request — any hit is
  true-positive by construction. Near-zero false positives, near-zero cost.
- **Coverage is a license/logging problem too.** You can't alert on a log you
  don't keep. Sysmon for process/inject visibility on endpoints; in M365, audit
  retention and the high-value events (MailItemsAccessed, Send) gate on the E5/G5
  tier. Decide what you're blind to *before* the assessment.
- **Red OPSEC is the other side of the same coin.** In-memory `execute-assembly`
  / BOFs avoid the `4688` that a dropped binary or `cmd /c` would write — so the
  defender's answer is endpoint telemetry (Sysmon, AMSI, EDR), not just the
  Windows Security log.

---

## Attack → detection map (Splunk SPL unless noted)

Queries assume a Windows Security / Sysmon feed in `index=main`. Field names
follow the common Splunk add-on schema — adjust to your CIM/normalization.

> Blocks fenced by `<!-- companion:gen ID -->` markers are **generated** from the
> structured companion (`offensive/companion/entries/`), which is canonical for
> those — edit the entry and run `offensive/companion/gen-views.sh`, not the block
> here (CI rejects a hand-edit). Everything outside the markers is hand-authored.

### Recon / credential access

**Password spray (many accounts, one source)** — `4625` failed logons:
```spl
index=main EventCode=4625 NOT (Source_Network_Address IN ("-","127.0.0.1"))
| eval Account=mvindex(Account_Name,1)
| stats dc(Account) AS Accounts by host, Source_Network_Address
| where Accounts > 10 | sort -Accounts
```

<!-- companion:gen asrep-probing-4771 -->
**Detect AS-REP / Kerbrute probing (4771 0x18)**

One client address generating Kerberos pre-auth failures (`4771`, failure code
`0x18`) across many distinct accounts is the spray/roast tell — a real user
fat-fingers their own name, not five-plus others. Tune the threshold to the
environment.

```spl
index=main EventCode=4771 Failure_Code="0x18"
| stats dc(Account_Name) AS UniqueAccounts by host, Client_Address
| where UniqueAccounts > 5
```
<!-- companion:end asrep-probing-4771 -->

<!-- companion:gen kerberoasting-4769 -->
**Detect Kerberoasting (4769 RC4 TGS)**

Detect on the invariant, not the IOC: an RC4 (`0x17`) service ticket for a
non-machine, non-krbtgt SPN. The encryption downgrade is the signal even when
ticket flags look normal — tools like Orpheus force RC4 precisely to keep the
roast crackable, so the downgrade itself is the tell.

```spl
index=main EventCode=4769 Service_Name!="*$" Service_Name!="krbtgt"
    Ticket_Encryption_Type=0x17
| stats dc(Service_Name) AS ServiceAccounts values(Service_Name)
    by Client_Address, Account_Name
| sort -ServiceAccounts
```
<!-- companion:end kerberoasting-4769 -->

**LDAP recon by one principal** — explicit-cred logons `4648` fanning out:
```spl
index=main EventCode=4648 Network_Address!="-"
| stats count by host, Network_Address | sort -count
```

### Poisoning, relay, coercion

<!-- companion:gen ntlm-relay-4624 -->
**Detect NTLM relay (4624 workstation mismatch)**

A relayed logon carries the *victim's* workstation name but arrives from the
*relay's* source address — so the tell is a `4624` whose `Workstation_Name`
doesn't resolve to its `Source_Network_Address`. That mismatch is the invariant;
the attacker can't relay without it.

```spl
index=main EventCode=4624 Workstation_Name!="-" Source_Port!="0"
| eval RelayedFrom=if(host!=Workstation_Name, Workstation_Name, "")
| lookup dnslookup clienthost AS RelayedFrom OUTPUT clientip AS IP
| where RelayedFrom!="" AND Source_Network_Address!=IP
| table _time, host, Account_Name, Source_Network_Address, RelayedFrom, IP
```
<!-- companion:end ntlm-relay-4624 -->

<!-- companion:gen coercion-5145 -->
**Detect coercion (5145 named-pipe access)**

Every coercion vector reaches the same handful of named pipes — `spoolss`,
`efsrpc`, `lsarpc`, `netlogon`, `lsass` — over `IPC$` with a detailed
file-share-access event (`5145`). Detect on the pipe set, not the tool: the
target endpoint can't change even as the coercion technique does.

```spl
index=main EventCode=5145 Access_Mask="0x3"
| regex Share_Name="(?i).*ipc\$$"
| regex Relative_Target_Name="(?i)(spoolss|efsrpc|lsarpc|netlogon|lsass)"
| table _time, host, Account_Name, Source_Address, Share_Name, Relative_Target_Name
```
<!-- companion:end coercion-5145 -->

### Lateral movement & dumping

<!-- companion:gen lateral-4624-fanout -->
**Detect lateral movement (4624 type-3 fan-out)**

One source address logging on (`4624` type 3, network) to many distinct hosts in
a short window is the reuse pattern — pass-the-hash, sprayed creds, or a relay all
fan out the same way. The auth succeeds, so the signal is the breadth, not a
failure.

```spl
index=main EventCode=4624 Logon_Type=3 NOT (Source_Network_Address IN ("-","::1"))
| stats dc(host) AS Hosts by Source_Network_Address
| where Hosts > 2 | sort -Hosts
```
<!-- companion:end lateral-4624-fanout -->

**LSASS access (credential theft)** — `4656` handle to lsass with dump-shaped masks:
```spl
index=main EventCode=4656 Object_Name=*lsass* TaskCategory="Kernel Object"
    Process_Name!=*MsMpEng.exe
    (Access_Mask="0x1010" OR Access_Mask="0x1410" OR Access_Mask="0x1FFFFF")
| table _time, host, Account_Name, Process_Name, Access_Mask, Object_Name
```

**Remote secrets dump (svcctl/winreg over IPC$/ADMIN$)** — `5145`:
```spl
index=main EventCode=5145 Relative_Target_Name IN ("svcctl","winreg")
| regex Share_Name="(?i).*(ipc|admin)\$$"
| table _time, host, Account_Name, Source_Address, Relative_Target_Name
```

<!-- companion:gen dcsync-4662 -->
**Detect DCSync / NTDS replication (4662)**

A `4662` directory-access event with the replication access mask (`0x100`) from a
non-system SID is the signal — legitimate replication comes from DC machine
accounts, so a user/admin SID requesting it is the anomaly.

```spl
index=main EventCode=4662 Access_Mask="0x100" Security_ID!="S-1-5-18"
| stats count by host, Account_Name, Object_Server | sort -count
```

Tighter: alert on `Properties` containing the **DS-Replication-Get-Changes-All**
extended right `1131f6ad-9c07-11d1-f79f-00c04fc2dcd2` requested by anything that
isn't a domain controller.
<!-- companion:end dcsync-4662 -->

### Execution, persistence, AD CS

**LOLBAS execution** — `4688` process creation, regex on known abuse shapes:
```spl
index=main EventCode=4688
| regex Process_Command_Line="(?i)(\.(hta|sct)|msbuild\.exe|^hh\s|,ShellExec_RunDLL|regasm|process\s+call\s+create|/u\s+.*\.dll|urlcache.*(http|file))"
| table _time, host, Account_Name, New_Process_Name, Process_Command_Line
```

**Obfuscated command lines** — `4688` heavy in `,` `^` `%`:
```spl
index=main EventCode=4688 (Process_Command_Line="*,*" OR Process_Command_Line="*^*" OR Process_Command_Line="*%*")
| eval n=len(Process_Command_Line)-len(replace(Process_Command_Line,"[,^%]",""))
| where n > 1
```

**Service creation (psexec / RDP-hijack service)** — `7045`, allowlist the known:
```spl
index=main EventCode=7045 Service_Name!="MpKsl*"
| regex Service_File_Name!="(?i)(SplunkUniversalForwarder|Microsoft.Net\\Framework64)"
| table _time, host, Service_Name, Service_File_Name, Service_Account
```

**RDP session hijack** — `4688` with the `tscon /dest:rdp-tcp#` tell:
```spl
index=main EventCode=4688
| regex Process_Command_Line="(?i)/dest:rdp-tcp#"
```

**Rogue account creation** — `4720` (created), pair with `4722` (enabled):
```spl
index=main EventCode IN (4720,4722)
| eval Creator=mvindex(Account_Name,0), NewAccount=mvindex(Account_Name,1)
| table _time, host, Creator, NewAccount
```

**AD CS cert request with a SAN that isn't the requester (ESC1/relay)** — `4886`:
```spl
index=main EventCode=4886
| rex field=Message "SAN\s*:.*upn=(?<RequestedSAN>.+$)"
| table _time, host, Requester, RequestedSAN
```
Also watch `5136` writes to the `userCertificate` attribute.

---

## Windows Event ID quick reference

| ID | Meaning | Shows up for |
|----|---------|--------------|
| 4624 / 4625 | logon success / failure | spray, lateral movement, relay |
| 4648 | logon w/ explicit creds | runas, LDAP recon fan-out |
| 4662 | directory-service object access | **DCSync** |
| 4688 | process creation | LOLBAS, obfuscation, hijack, recon binaries |
| 4720 / 4722 | account created / enabled | persistence |
| 4769 | Kerberos TGS request | **Kerberoasting** (RC4 downgrade) |
| 4771 | Kerberos pre-auth failed (`0x18`) | Kerbrute / AS-REP probing |
| 4886 / 4887 | cert requested / issued | AD CS abuse (SAN mismatch) |
| 5136 | directory object modified | `userCertificate` writes, ACL abuse |
| 5145 | detailed file-share access | coercion pipes, remote secretsdump |
| 5156 | WFP connection allowed | NFS/SMB/LDAP flow detection (firewall) |
| 7045 | service installed | psexec, RDP-hijack service |
| Sysmon 1 / 8 / 10 | proc create / CreateRemoteThread / process access | injection, migration, LSASS access |

## Honey tokens (build these before you're attacked)

- **Honey user** — a never-used account; any `4625`/`4624` referencing it is real.
  ```spl
  index=main EventCode=4625 TERM("<honey-username>")
  ```
- **Honey SPN** — register a fake SPN (`setspn -A MSSQLSvc/fake:1433 <acct>`); any
  `4769` for it means someone enumerated/roasted SPNs:
  ```spl
  index=main EventCode=4769 Service_Name="<honey-spn-account>"
  ```
- **Responder honeypot (HoneyCreds)** — broadcast fake creds so an attacker's
  Responder/relay tooling bites a poisoned credential you can alarm on.

---

*Credit: TrustedSec, "Actionable Purple Teaming," Black Hat USA 2023. Queries
generalized and cleaned from the class command reference; tune field names and
thresholds to your environment before relying on them.*
