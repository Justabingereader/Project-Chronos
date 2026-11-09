### Setting up DHCP on DC01

Navigated to server manager

Chose to add roles and features in the manage tab in server manager

went through the installation guide

added DHCP server

![Adding the DHCP Server role](images/rb-004-dhcp-role.png)

![Install succeeded; post-install configuration still required](images/rb-004-dhcp-installed.png)

After install, I authorized the DHCP server in AD

![Post-install wizard: authorising DC01 in AD DS as CHRONOS\Administrator](images/rb-004-authorise-in-ad.png)

I navigated to the DHCP management console to create a new IPv4 scope.

![DHCP console: IPv4 → New Scope](images/rb-004-new-scope.png)

![Scope name DC01_DHCP](images/rb-004-scope-name.png)

![Router (default gateway) 10.20.0.254](images/rb-004-router-option.png)

![Activating the scope](images/rb-004-activate-scope.png)

During the DHCP setup, i added the same DNS address 3 times, potentially causing clients to resolve the same address thrice, wasting compute and time, i solved this by navigating to the DHCP management console, and the scope options under IPv4, then i navigated to the 006 - DNS servers section and removed the two redundant addresses, i then confirmed everything was in order through Get commands in powershell.

![Verification: DC01 authorised; scope 10.20.0.100–200 active; options 003 router, 006 DNS (once), 015 chronos.lab](images/rb-004-verify-dhcp.png)
