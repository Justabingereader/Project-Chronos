After connecting the on-prem AD to entra through Azure connect sync, I ran "Finance","Sales","IT" | ForEach-Object {
  New-ADGroup -Name "GG-$_" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=Chronos,DC=chronos,DC=lab"
} on DC01 to create the groups the scripts will add new users too.

Then i created the <Claude add New-ChronosADUser script link here> in order to create a new user, taking in its FirstName, LastName and Department(which is linked to groups) as parameters, ensuring the absence of user duplication and validation of allowed sets in the department to the objects defined in the Groups OU. The script then generates a random password which it converts to a secure string text. It then adds a new user, then adds the new user to the an AD Group using the department parameter for its identity and its $GeneratedSam(concatenation of firstname and lastname, automatically converted to lowercase with a dot in between the names) as its member value, before printing an error message if the user could not be successfully created or the member could not be added to the ADGroup. and then the Start-Process powershell -ArgumentList '-NoProfile -Command "Import-Module ADSync; Start-ADSyncSyncCycle -PolicyType Delta"' -Wait -NoNewWindow cmdlet starts a new powershell process and forces a sync to Entra rather than waiting for the scheduled sync. after i created the script, i called it through the dot notation with the directory path of the script defined, ran the function while passing the mandatory paramenters, and verified its functionality on Entra.

Then i went about creating the <Claude add Disable-ChronosUser script link here> in order to disable a user and move it into a leavers OU, taking in a SamAccountName and TicketNumber as parameters, with both parameters returning outputs specifying an error message if either parameter could not be verified or non-subject to duplication, then after the creation of the user disable powershell script, i called it through dot notation and ran the function while passing the mandatory parameters into the function, then verified the account status of the user as disabled on entra, and that the user had successfully been moved to the leavers OU. 

Then i ran a full joiner-leaver sequence, proving the end to end flow.

The next step involved revoking the user's sessions after they had been disabled through microsoft graph, disabling any ongoing sessions the user may have had access to before being disabled. I made use of an app-only authentication with a certificate for the graph, giving it permissions for only the revocation of sessions, with the application proving its identity with a private key whose credentials never leave DC01. The certificate was initially created on DC01 through $cert = New-SelfSignedCertificate -Subject "CN=Chronos-JML" -CertStoreLocation Cert:\LocalMachine\My -KeyExportPolicy NonExportable -KeySpec Signature -NotAfter (Get-Date).AddYears(1)
Export-Certificate -Cert$cert -FilePath C:\Install\chronos-jml.cer
$cert.Thumbprint cmdlet.

Then on the host laptop on an admin powershell instance, the public .cer was pulled out through $s = New-PSSession -VMName DC01 -Credential CHRONOS\Administrator
Copy-Item -FromSession $s C:\Install\chronos-jml.cer -Destination $env:USERPROFILE\Downloads\ cmdlet

Then in Entra, under app registrations, i created a new registration and named it Chronos-JML-Automation, under certificates & Secrets, i navigated to certifications and uploaded the public .cer

I then navigated to API permissions -> Add -> Microsoft Graph -> Application permissions -> User.RevokeSessions.All, removed all other permissions and granted admin consent, i then compared the thumbprint under certificates in Entra with the thumbprint displayed by DC01, verifying matching values.

Then on DC01, i ran the Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users.Actions -Scope AllUsers to install the relevant authenticantion and user modules under microsoft graph. I then added the client ID, tenant ID, and thumbprint to a powershell data file, importing them into the disable-chronosuser powershell script, then i added  the Connect-MgGraph -ClientId $($Config.ClientId) -TenantId $($Config.TenantId) -CertificateThumbprint $($Config.Thumbprint) -NoWelcome  
$ADUser = Get-ADUSer -Identity $SamAccountName -Properties UserPrincipalName  
$UserUPN = $ADUser.UserPrincipalName  
$RevokeResult = Revoke-MgUserSignInSession -UserId $UserUPN  
$isRevoked = $RevokeResult.Value  
Disconnect-MgGraph | Out-Null cmdlet to connect to the graph, revoke the specified user through its UPN and disconnect from the graph, outputting the contents of the graph displayed by the Disconnect-MgGraph to null to avoid the display of sensitive information to unauthorized personnel.











