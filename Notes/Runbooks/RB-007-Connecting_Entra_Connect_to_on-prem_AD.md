# RB-007: Connecting Entra Connect to on-prem AD

Logged in to Entra on Microsoft

Default Directory was used due to the absence of a paid license on the base-tenant which prevented the inclusion of base-tenant add ons.

![Add-on tenant creation blocked: the base tenant has no paid licence](images/rb-007-addon-tenant-blocked.png)

Confirmation of existing users, role, and entra connect sync status

![Default Directory: Entra ID Free, 1 user](images/rb-007-default-directory-overview.png)

![Starting point: Global Administrator, Entra Connect sync has never run](images/rb-007-entra-connect-never-run.png)

In the domain name under Entra ID, a custom domain of chronos.saintshubs.com was created and a TXT record was presented for verification

In cloudflare, under the specified domain name, a new DNS record with a type of TXT was included, with the name as chronos and the content as the TXT content provided on Entra ID. After which verification occured on Entra ID

![chronos.saintshubs.com verified in Entra (TXT value redacted)](images/rb-007-domain-verified.png)

![DC01: chronos.saintshubs.com added as a UPN suffix on the forest](images/rb-007-upn-suffix-added.png)

In the users section under Entra ID, a user with a UPN of  sync-admin@<tenant>.onmicrosoft.com and Display Name of Chronos Sync Admin was created, and an Hybrid Identity Administrator role assignment was added to the user, after which a sign in to a private window occured with the newly created user credentials, the temporary password was changed, MFA was enabled through Microsoft's authenticator application, and the new password was generated and stored in Bitwarden's password manager.

![Least-privilege role: Hybrid Identity Administrator only](images/rb-007-sync-admin-role.png)

![Cloud-only sync-admin account on the onmicrosoft.com domain](images/rb-007-sync-admin-create.png)

I then increased the RAM of the DC01 VM to 4gb in order to install Entra Connect sync.

![Host memory with DC01 at 4 GB: 4.7 GB available](images/rb-007-host-memory.png)

I did not give the Entra connect sync it's own server even though it would have prevented the Connect sync from potentially taking down the DC and brought on the possibility of rebuilding either system without bringing down the other due to structural RAM challenges.

I then installed Entra connect sync through the Entra Connect section in Entra ID, downloading the connect sync application specifically on my host laptop.

After which i moved it from my host laptop to DC01 through the following cmdlet on powershell:

```powershell
Enable-VMIntegrationService -VMName DC01 -Name "Guest Service Interface"
Copy-VMFile -Name DC01 -SourcePath "C:\Users\<redacted>\Downloads\AzureADConnect.msi" -DestinationPath "C:\Install\AzureADConnect.msi" -CreateFullPath -FileSource Host
```

![Installer copied to C:\Install on DC01 and running](images/rb-007-installer-on-dc01.png)

After which i proceeded to install connect sync on DC01, initially running into an error because i used Admin instead of Administrator as the username on the connect directories page.

![Wrong username: the wizard asks for a fully qualified domain account](images/rb-007-connect-directories-error.png)

![Fixed: CHRONOS.LAB\Administrator used to create the AD DS connector account](images/rb-007-forest-account.png)

After which i followed the installation guide, ticking "Continue without matching all UPN suffixes to verified domains" on the Microsoft Entra sign in page, and ticking to select only the selected domains and OU, with only the Chronos OU on the Domains and OU page being selected, to prevent Entra connect from syncing my users and other sensitive directories to Entra.

![Sign-in configuration: chronos.lab cannot be verified, chronos.saintshubs.com is](images/rb-007-signin-config.png)

![OU filter: only the Chronos OU is synced](images/rb-007-ou-filtering.png)

I used the defaults on the identifying users page and synchronised all users and devices on the Filtering page, with password hash sync selected as the only optional feature included.

I then proceeded to install connect sync on DC01, leaving **“Start the synchronization process when configuration completes”** ticked.

![Configuration complete (note the AD Recycle Bin warning; see KB-005)](images/rb-007-configuration-complete.png)

I then verified the sync had taken effect through running the Get-ADSyncScheduler cmdlet on powershell and checking Entra connect to check its last sync date.

![Get-ADSyncScheduler: 30-minute delta cycle, not in staging mode](images/rb-007-sync-scheduler.png)

![Entra: Connect Sync enabled, Password Hash Sync enabled](images/rb-007-connect-sync-status.png)

The on-prem AD connected to Entra as an application rather than an identity.

![The sync engine's app registration (client ID redacted)](images/rb-007-sync-app-registration.png)

![0 devices: CL01 is in scope but skipped until hybrid join writes its device certificate](images/rb-007-devices-zero.png)

I then used [New-ADChronosUser.ps1](../Scripts/New-ADChronosUser.ps1) to set up a user, saving the script as a .ps1 extension and loading it through the dot notation before running the function with the created parameters.

![Joiner script run (temporary password redacted)](images/rb-007-joiner-run.png)

I then removed one out of the two AD Users(John Doe) because it was ran from a previous test script that had no first name, last name, or display name.

![John Doe removed before it synced](images/rb-007-remove-john-doe.png)

I then forced the sync to Entra through the `Start-ADSyncSyncCycle -PolicyType Delta` cmdlet.

![Manual delta sync](images/rb-007-first-sync.png)

![Jane Doe synced: on-premises sync enabled, UPN kept on chronos.saintshubs.com](images/rb-007-users-synced.png)

I confirmed that the properties were greyed out in Entra ID, proving AD as the source of authority

![Synced attributes greyed out in Entra: AD is the source of authority](images/rb-007-source-of-authority.png)
