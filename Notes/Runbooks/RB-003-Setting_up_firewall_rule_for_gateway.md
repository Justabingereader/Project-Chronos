### Setting up a firewall rule that permits incoming pings to gateway

New-NetFirewallRule -Action Allow -RemoteAddress 10.20.0.0/24

cmdlet New-NetFirewallRule at command pipeline position 1
Supply values for the following parameters:
DisplayName: Chronos-Lab

Name                          : {ebad2b4f-bd7c-4483-b13a-d232b546e803}
DisplayName                   : Chronos-Lab
Description                   :
DisplayGroup                  :
Group                         :
Enabled                       : True
Profile                       : Any
Platform                      : {}
Direction                     : Inbound
Action                        : Allow
EdgeTraversalPolicy           : Block
LooseSourceMapping            : False
LocalOnlyMapping              : False
Owner                         :
PrimaryStatus                 : OK
Status                        : The rule was parsed successfully from the store. (65536)
EnforcementStatus             : NotApplicable
PolicyStoreSource             : PersistentStore
PolicyStoreSourceType         : Local
RemoteDynamicKeywordAddresses : {}
PolicyAppId                   :
PackageFamilyName             :



PS C:\WINDOWS\system32> Remove-NetFirewallRule -DisplayName "Chronos-Lab"
PS C:\WINDOWS\system32> New-NetFirewallRule -Action Allow -RemoteAddress 10.20.0.0/24 -Direction Inbound -Protocol ICMPv4 -IcmpType 8  -InterfaceALias "vEthernet (Chronos-Lab)" -DisplayName Chronos-Lab: Allow Incoming ICMP Traffic
New-NetFirewallRule : A positional parameter cannot be found that accepts argument 'Allow'.
At line:1 char:1

+ New-NetFirewallRule -Action Allow -RemoteAddress 10.20.0.0/24 -Direct ...
+ ```
    + CategoryInfo          : InvalidArgument: (:) [New-NetFirewallRule], ParameterBindingException
    + FullyQualifiedErrorId : PositionalParameterNotFound,New-NetFirewallRule
  
  ```

PS C:\WINDOWS\system32> New-NetFirewallRule -Direction Inbound -Action Allow -RemoteAddress 10.20.0.0/24 -Protocol ICMPv4 -IcmpType 8  -InterfaceALias "vEthernet (Chronos-Lab)" -DisplayName Chronos-Lab: Allow Incoming ICMP Traffic
New-NetFirewallRule : A positional parameter cannot be found that accepts argument 'Allow'.
At line:1 char:1

+ New-NetFirewallRule -Direction Inbound -Action Allow -RemoteAddress 1 ...
+ ```
    + CategoryInfo          : InvalidArgument: (:) [New-NetFirewallRule], ParameterBindingException
    + FullyQualifiedErrorId : PositionalParameterNotFound,New-NetFirewallRule
  
  ```

PS C:\WINDOWS\system32> New-NetFirewallRule -Direction Inbound -Action Allow -RemoteAddress 10.20.0.0/24 -Protocol ICMPv4 -IcmpType 8  -InterfaceALias "vEthernet (Chronos-Lab)" -DisplayName "Chronos-Lab: Allow Incoming ICMP Traffic"

Name                          : {6662c204-4780-4810-a29a-3d76f3cfafe1}
DisplayName                   : Chronos-Lab: Allow Incoming ICMP Traffic
Description                   :
DisplayGroup                  :
Group                         :
Enabled                       : True
Profile                       : Any
Platform                      : {}
Direction                     : Inbound
Action                        : Allow
EdgeTraversalPolicy           : Block
LooseSourceMapping            : False
LocalOnlyMapping              : False
Owner                         :
PrimaryStatus                 : OK
Status                        : The rule was parsed successfully from the store. (65536)
EnforcementStatus             : NotApplicable
PolicyStoreSource             : PersistentStore
PolicyStoreSourceType         : Local
RemoteDynamicKeywordAddresses : {}
PolicyAppId                   :
PackageFamilyName             :
