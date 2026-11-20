# RB-008: Modifying AD users through scripts and pushing to Entra

Joiner, leaver and mover scripts on DC01, session revocation through Microsoft Graph, and the scheduled jobs that clean up after the mover. Prerequisite: [RB-007](RB-007-Connecting_Entra_Connect_to_on-prem_AD.md) (Entra Connect Sync running).

## Joiner

After connecting the on-prem AD to Entra through Entra Connect Sync, I ran the following on DC01 to create the groups the scripts add new users to:

```powershell
"Finance","Sales","IT" | ForEach-Object {
  New-ADGroup -Name "GG-$_" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=Chronos,DC=chronos,DC=lab"
}
```

Departments, their birthright groups and their user OUs live in one roles file, [chronos-roles.psd1](../Scripts/chronos-roles.psd1), which every script reads.

![chronos-roles.psd1: each department maps to its birthright groups and its user OU](images/rb-008-roles-file.png)

Then I created [New-ChronosADUser.ps1](../Scripts/New-ChronosADUser.ps1) to create a new user. It takes FirstName, LastName and Department (which is linked to groups) as parameters, checks that the user doesn't already exist, and checks that the department is one of the departments defined in the roles file. The script then generates a random password, which it converts to a secure string. It creates the user, then adds the user to the department's groups using the generated SamAccountName (first name and last name, lowercase, with a dot in between) as the member, printing an error message if the user could not be created or could not be added to a group. Finally,

```powershell
Start-Process powershell -ArgumentList '-NoProfile -Command "Import-Module ADSync; Start-ADSyncSyncCycle -PolicyType Delta"' -Wait -NoNewWindow
```

starts a new PowerShell process and forces a sync to Entra rather than waiting for the scheduled sync. After creating the script, I loaded it with dot notation using the script's path, ran the function with the mandatory parameters, and verified it in Entra.

![Joiner run: user created in the IT OU (temporary password, GUIDs and SIDs redacted)](images/rb-008-joiner-run.png)

![Unknown department rejected before anything is created](images/rb-008-joiner-unknown-dept.png)

## Leaver

Then I created [Disable-ChronosUser.ps1](../Scripts/Disable-ChronosUser.ps1) to disable a user and move it into the Leavers OU. It takes a SamAccountName and a TicketNumber as parameters, and returns an error message if either cannot be verified or the ticket is a duplicate. After creating the script, I loaded it with dot notation and ran the function with the mandatory parameters, then verified in Entra that the account was disabled and in AD that the user had been moved to the Leavers OU.

Then I ran a full joiner-leaver sequence, proving the end-to-end flow.

### Revoking sessions through Microsoft Graph

The next step was revoking the user's sessions after they had been disabled, through Microsoft Graph, cutting off any sessions the user had open before being disabled. I used app-only authentication with a certificate, giving the app permission for session revocation only, with the app proving its identity with a private key that never leaves DC01. The certificate was created on DC01 with:

```powershell
$cert = New-SelfSignedCertificate -Subject "CN=Chronos-JML" -CertStoreLocation Cert:\LocalMachine\My -KeyExportPolicy NonExportable -KeySpec Signature -NotAfter (Get-Date).AddYears(1)
Export-Certificate -Cert $cert -FilePath C:\Install\chronos-jml.cer
$cert.Thumbprint
```

![DC01: non-exportable certificate created, public .cer exported (thumbprint redacted)](images/rb-008-cert-created.png)

Then, on the host laptop in an admin PowerShell, I pulled the public .cer out with:

```powershell
$s = New-PSSession -VMName DC01 -Credential CHRONOS\Administrator
Copy-Item -FromSession $s C:\Install\chronos-jml.cer -Destination $env:USERPROFILE\Downloads\
```

![Host: public certificate copied out of DC01 over PowerShell Direct](images/rb-008-cer-copied.png)

Then in Entra, under App registrations, I created a new registration named Chronos-JML-Automation, and under Certificates & secrets → Certificates I uploaded the public .cer.

![Certificate uploaded to Chronos-JML-Automation (thumbprint redacted)](images/rb-008-cert-uploaded.png)

I then went to API permissions → Add a permission → Microsoft Graph → Application permissions → User.RevokeSessions.All, removed all other permissions and granted admin consent. I then compared the thumbprint under Certificates in Entra with the thumbprint shown on DC01 and confirmed they matched.

![Application permission User.RevokeSessions.All](images/rb-008-api-permission.png)

![Admin consent granted; it is the only permission on the app](images/rb-008-admin-consent.png)

Then on DC01 I ran the following to install the Graph authentication and user-actions modules:

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users.Actions -Scope AllUsers
```

![Graph modules installed for all users on DC01 (thumbprint redacted)](images/rb-008-graph-modules.png)

![Connect-MgGraph fails with TypeLoadException in a console where ADSync was already loaded (IDs redacted)](images/rb-008-graph-dll-clash.png)

![In a fresh session: app-only connection as Chronos-JML-Automation with only User.RevokeSessions.All, and a test revoke returning True (IDs redacted)](images/rb-008-graph-app-only-test.png)

I then added the client ID, tenant ID and thumbprint to a PowerShell data file (`C:\Scripts\chronos-config.psd1`, gitignored, never committed), imported it into Disable-ChronosUser, and added:

```powershell
Connect-MgGraph -ClientId $($Config.ClientId) -TenantId $($Config.TenantId) -CertificateThumbprint $($Config.Thumbprint) -NoWelcome
$ADUser = Get-ADUser -Identity $SamAccountName -Properties UserPrincipalName
$UserUPN = $ADUser.UserPrincipalName
$RevokeResult = Revoke-MgUserSignInSession -UserId $UserUPN
$isRevoked = $RevokeResult.Value
Disconnect-MgGraph | Out-Null
```

to connect to Graph, revoke the specified user through its UPN, and disconnect. The output of `Disconnect-MgGraph` is sent to `Out-Null` so the connection details aren't displayed to anyone watching the console.

![Leaver run: test.run disabled and its sessions revoked](images/rb-008-leaver-run.png)

![Entra: Test Run shows as disabled](images/rb-008-leaver-entra-disabled.png)

![Offboarding log row: ticket, user, who ran it, revoke result](images/rb-008-leaver-csv-log.png)

The Entra audit log shows the order: the sync disables the account and removes its groups at 18:40:20, and the revoke follows at 18:40:27.

![Audit log: disable and group removal at 18:40:20, revoke at 18:40:27](images/rb-008-leaver-audit-order.png)

![Disable account: done by the Connect Sync app (IDs redacted)](images/rb-008-leaver-audit-sync.png)

![Update StsRefreshTokenValidFrom: done by Chronos-JML-Automation (IDs redacted)](images/rb-008-leaver-audit-revoke.png)

Failure path: with the thumbprint deliberately broken, the account is still disabled, the script warns that the revoke failed, and the log records the reason.

![Revoke failure surfaced as a warning (temporary password redacted)](images/rb-008-leaver-revoke-failure.png)

![Log row records FAILED with the reason (thumbprint redacted)](images/rb-008-leaver-revoke-failure-log.png)

## Mover

Then I created [Move-ChronosADUser.ps1](../Scripts/Move-ChronosADUser.ps1). The script takes the user's requested (ad-hoc) access groups, the ones that aren't birthright groups for any department, and moves them into a per-user shadow group in the Transition OU under the Groups OU, nested into each of those groups. This gives the user that extra access for the number of days set in `$GraceDays`. It removes the old department's groups, adds the new department's groups, updates the department and OU, syncs, revokes sessions, and logs a BEFORE and AFTER snapshot to `C:\Logs\MoverAuditLog.csv`.

![Mover run: user.02 moves from IT to Finance; GG-ProjectY is kept through TEMP_Expire_2026-12-18_user.02](images/rb-008-mover-run.png)

![Shadow groups in OU=Transition](images/rb-008-shadow-groups-transition.png)

![Audit log: group changes at 17:34:48, revoke at 17:35:00](images/rb-008-mover-audit-order.png)

![Group change done by the Connect Sync app (IDs redacted)](images/rb-008-mover-audit-sync.png)

![Revoke done by Chronos-JML-Automation (IDs redacted)](images/rb-008-mover-audit-revoke.png)

## Cleanup job for expired shadow groups

The next step was creating a cleanup job to clear the shadow groups in the Transition OU once their expiry date had passed. I added a KDS root key, backdating its effective time by 10 hours:

```powershell
Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10))
```

![KDS root key added](images/rb-008-kds-root-key.png)

Then I created a group managed service account named gmsa-cleanup, with a DNSHostName and `PrincipalsAllowedToRetrieveManagedPassword` set to DC01's computer account, installed it on DC01, and tested it with `Test-ADServiceAccount`, which returned True.

```powershell
New-ADServiceAccount -Name "gmsa-cleanup" -DNSHostName "gmsa-cleanup.chronos.lab" -PrincipalsAllowedToRetrieveManagedPassword "DC01$"
Install-ADServiceAccount -Identity "gmsa-cleanup"
Test-ADServiceAccount -Identity "gmsa-cleanup"
```

![gMSA created](images/rb-008-gmsa-cleanup-create.png)

![Install-ADServiceAccount takes the gMSA's name, not the DC's](images/rb-008-gmsa-cleanup-install.png)

![Test-ADServiceAccount returns True](images/rb-008-gmsa-cleanup-test.png)

Then I granted gmsa-cleanup permission to delete group objects in the Transition OU only:

```powershell
dsacls "OU=Transition,OU=Groups,OU=Chronos,DC=chronos,DC=lab" /G 'CHRONOS\gmsa-cleanup$:DC;group'
```

and verified it with:

```powershell
dsacls "OU=Transition,OU=Groups,OU=Chronos,DC=chronos,DC=lab" | Select-String gmsa -Context 0,2
```

which shows DELETE CHILD for group objects granted to the gMSA.

![DELETE CHILD for groups granted to gmsa-cleanup on OU=Transition](images/rb-008-dsacls-verify.png)

Then I granted the gMSA Modify on `C:\Logs`:

```powershell
icacls "C:\Logs" /grant 'CHRONOS\gmsa-cleanup$:(OI)(CI)M'
```

![gmsa-cleanup has Modify on C:\Logs](images/rb-008-icacls-logs.png)

Then I created [Remove-ExpiredShadowGroups.ps1](../Scripts/Remove-ExpiredShadowGroups.ps1), which searches only the Transition OU and reads each group's expiry date. If the expiry date is on or before today, it first records and logs the group's members and the groups it's nested into, then deletes it.

![Dry run with -WhatIf against test groups: only the expired one would be deleted](images/rb-008-cleanup-whatif.png)

![Cleanup log: expired group deleted, unexpired ones skipped, invalid date flagged](images/rb-008-cleanup-log.png)

I registered the event log source once, as admin (used by the stale check below):

```powershell
New-EventLog -LogName Application -Source ChronosStaleCheck
```

The next step was creating a scheduled task:

```powershell
$Action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\Remove-ExpiredShadowGroups.ps1"'
$Trigger   = New-ScheduledTaskTrigger -Daily -At 2am
$Principal = New-ScheduledTaskPrincipal -UserId 'CHRONOS\gmsa-cleanup$' -LogonType Password
Register-ScheduledTask -TaskName "Chronos - Remove Expired Shadow Groups" -Action $Action -Trigger $Trigger -Principal $Principal
```

![Task registered and started (0x41301 = still running)](images/rb-008-cleanup-task-registered.png)

![Task runs as gmsa-cleanup$; last run completed successfully](images/rb-008-cleanup-task-scheduler.png)

![Scope test: with the search base temporarily widened to OU=Groups, the gMSA is denied deleting a bait group outside Transition](images/rb-008-cleanup-scope-test.png)

![Search base back on OU=Transition](images/rb-008-cleanup-searchbase-restored.png)

## Stale shadow group check

The next step was creating a second gMSA called gmsa-stalecheck, with a DNSHostName and `PrincipalsAllowedToRetrieveManagedPassword` set to DC01's computer account, then installing and testing it, which returned True.

![gmsa-stalecheck created, installed and tested](images/rb-008-gmsa-stalecheck.png)

Then I created [Test-StaleShadowGroups.ps1](../Scripts/Test-StaleShadowGroups.ps1), which finds any `TEMP_Expire_*` group in the Transition OU with an expired or invalid date and writes a warning to the Windows Application event log if any group matches; otherwise it writes an all-clear information event.

![Stale check task registered (daily, 3am, as gmsa-stalecheck$)](images/rb-008-stalecheck-task-registered.png)

![Task result 0xFFFD0000 traced to a doubled .ps1.ps1 extension; after the rename the task returns 0](images/rb-008-stalecheck-task-fix.png)

![Application log: warning (1001) for a deliberately broken group, then all clear (1000)](images/rb-008-stalecheck-events.png)
