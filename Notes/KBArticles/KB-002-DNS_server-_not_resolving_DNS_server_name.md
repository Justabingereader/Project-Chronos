### Every nslookup on DC01 returned a Server: Unknown Response

Symptom: nslookup on DC01 returned a server: unknown response and a 2 second timeout, with subsequent nslookup requests on DC01 just returning the server: unknown response.

Environment: host Windows 11 on a Latitude 5410 with Hyper-V; guest DC01 running Server 2025 Evaluation; switch `Chronos-Lab` (Internal) with NAT; gateway `10.20.0.254` on the host.

![Symptom: DNS server installed, DC01 pointing at loopback, nslookup times out and shows Server: UnKnown via ::1](images/kb-002-dns-installed-loopback-timeout.png)

Root Cause: There was no reverse zone for 10.20.0.0/24, so there was no PTR record. That was fixed with an AD-integrated reverse lookup zone along with an ipconfig /registerdns. nslookup queries the IPv6 DNS server(::1), the address's name is looked up on the internet, which takes longer than the time limit until the "no such name" answer is cached.

Evidence: The IPv4 query (nslookup chronos 10.20.0.1) has no timeout. The PTR record has a timestamp, which means it was dynamically registered. The timeout response only comes after the DNS cache is flushed.

![Reverse zone exists; the IPv4 query to 10.20.0.1 has no timeout](images/kb-002-zones-and-ipv4-query.png)

![PTR record for 10.20.0.1 with a timestamp (dynamically registered); zone accepts secure updates only](images/kb-002-ptr-registered-secure.png)

![Cache test: the timeout appears only on the first lookup after Clear-DnsServerCache](images/kb-002-cache-test.png)

Fix: Tried to use netlogon restart(wrong service: uses locator records, not PTR records), in.addr.appa was continuously used to verify the PTR record instead of in-addr.arpa, leading to false troubleshooting, and a false theory regarding ::1 IPv6 address causing a collision if it wasn't removed.  change of the address name to in-addr.arpa and lookup of the PTR confirmed the fix, although the quirk of server: unknown is still present due to the presence of the harmless ::1 IPv6 address whenever DC01 is queried.

![Reverse zone wizard: AD-integrated, replicated to all DNS servers in chronos.lab](images/kb-002-reverse-zone-replication-scope.png)

![Reverse zone wizard: network ID 10.20.0](images/kb-002-reverse-zone-network-id.png)

![Reverse zone 0.20.10.in-addr.arpa created](images/kb-002-reverse-zone-created.png)

![Dead end: restarting Netlogon (registers locator records, not PTR records)](images/kb-002-netlogon-restart.png)

![Dead end: zone name typed as in-addr.appa, so the zone was "not found"](images/kb-002-zone-name-typo.png)
