### Setting up the domain controller (DC01)

#### 1. Create the VM

![New VM: DC01, Generation 2, 4 GB, Chronos-Lab switch, Server 2025 ISO](images/rb-002-new-vm-summary.png)

#### 2. Install Windows Server

Had to press a button immediately after to avoid operating system not found error

![Windows Server 2025 installing on DC01](images/rb-002-installing-windows-server.png)

![First boot into Server Manager](images/rb-002-server-manager-first-boot.png)

#### 3. Name, static IP and DNS

changed the computer name and IP settings to the specified design in the lab topology and IP Plan

![IPv4 settings: 10.20.0.1/24, gateway 10.20.0.254, DNS 10.20.0.1 then 127.0.0.1](images/rb-002-dns-client-settings.png)

![ipconfig /all confirming host name DC01 and the static address](images/rb-002-ipconfig-static.png)

I set up the DC as the DNS Active Directory stores the records clients use to find domain name in the DC DNS, and the DC registers them there itself.

#### 4. Install AD DS and create the chronos.lab forest

Navigated to Dashboard

Went through the installation setup

![Installing the AD DS role on DC01](images/rb-002-adds-role-install.png)

Created an AD DS

Promoted DC01 to Domain controller

set forest name to chronos.lab

![Deployment configuration: add a new forest, root domain chronos.lab](images/rb-002-new-forest-chronos-lab.png)

server restarted

![Promotion succeeded; DC01 restarts as a domain controller](images/rb-002-promotion-complete-restart.png)

Confirmed the presence through Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode command

![Verification: domain chronos.lab exists, and DC01 resolves both chronos.lab and microsoft.com](images/rb-002-verify-domain-and-dns.png)
