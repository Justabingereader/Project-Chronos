# Project Chronos

A hybrid IT support lab: on-premises Active Directory synced to a Microsoft Entra tenant, with Intune-managed devices. It's run like an MSP customer, so every fault is diagnosed from evidence, logged as a ticket and closed with a knowledge-base article.

## Goals, in priority order

1. **Diagnosis:** find the root cause from first-party evidence (logs, `dsregcmd`, sign-in logs, Event Viewer) without searching for the fix, up to the point where a tier-2 MSP technician would escalate.
2. **Competency:** do routine admin work correctly and repeatably.
3. **Tool know-how:** Active Directory, DNS, DHCP, Group Policy, Entra ID, Intune, Microsoft 365 admin, PowerShell.

## Environment

| Component | Detail |
| --- | --- |
| Host | Windows 11, Hyper-V, Internal switch `Chronos-Lab` with NAT (gateway `10.20.0.254`) |
| DC01 | Windows Server 2025: AD DS, DNS, DHCP, `10.20.0.1` |
| CL01 | Windows 11 Enterprise: DHCP client, joined to `chronos.lab` |
| Domain | `chronos.lab` |

- [IP plan and topology](Design/ip-plan-and-topology.md)
- [OU design](Design/OU-Design.md)

## Status

| Phase | Scope | Status |
| --- | --- | --- |
| 0 | Local foundation: network, DC, DNS, DHCP, OUs, client, osTicket | In progress (osTicket remaining) |
| 1 | Trial tenant, hybrid sync, joiner/mover/leaver | Not started |
| 2 | Entra for people: MFA, SSPR, Conditional Access | Not started |
| 3 | Intune on a hybrid-joined VM and an Entra-joined laptop | Not started |
| 4 | Microsoft 365 admin basics | Not started |
| — | Blind fault drills | Run throughout |

## Runbooks

- [RB-001: Build the lab network](Notes/Runbooks/RB-001-build_lab_network.md)
- [RB-002: Set up the domain controller](Notes/Runbooks/RB-002-Setting_up_domain_server.md)
- [RB-003: Firewall rule for gateway pings](Notes/Runbooks/RB-003-Setting_up_firewall_rule_for_gateway.md)
- [RB-004: Set up DHCP](Notes/Runbooks/RB-004_Setting_up_DHCP.md)
- [RB-005: Build the OUs](Notes/Runbooks/RB-005-Building_OUs.md)

## Knowledge-base articles

- [KB-001: Default gateway not answering pings](Notes/KBArticles/KB-001-default_gateway_not_answering.md)
- [KB-002: nslookup shows "Server: UnKnown" with a timeout](Notes/KBArticles/KB-002-DNS_server-_not_resolving_DNS_server_name.md)
