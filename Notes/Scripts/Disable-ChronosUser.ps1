function Disable-ChronosUser {
	param (
	    [Parameter(Mandatory=$true)]
	    [string]$SamAccountName,

	    [Parameter(Mandatory=$true)]
	    [int]$TicketNumber
	)
	
	$Config = Import-PowerShellDataFile -Path "C:\Scripts\chronos-config.psd1"

	Add-Type -AssemblyName System.Web
        $PlainPassword  = [System.Web.Security.Membership]::GeneratePassword(14, 3)
        $SecurePassword = ConvertTo-SecureString -String $PlainPassword -AsPlainText -Force

	$LogFolder = "C:\Logs"
	if (-not (Test-Path $LogFolder)) { New-Item -ItemType Directory -Path $LogFolder | Out-Null }

	$LogPath = "$LogFolder\OffboardingTicketsv1.csv"
	if(Test-Path $LogPath) {
		$PastRecords = Import-Csv -Path $Logpath
		if($PastRecords.TicketNumber -contains $TicketNumber) {
			Write-Warning "Ticket $TicketNumber has already been processed. Stopping script."
			return
			}
		}
	try {
	Disable-ADAccount -Identity $SamAccountName -ErrorAction Stop
	Write-Host "$SamAccountName Successfully Disabled" -ForegroundColor Green
	}
	catch {
	Write-Host "$SamAccountName either doesn't exist or has already been deleted" -ForegroundColor Red
	Write-Host $_.Exception.Message -ForegroundColor Yellow
	return
	}
	try {
	Set-ADAccountPassword -Identity $SamAccountName -Reset -NewPassword $SecurePassword -ErrorAction Stop
	}
	catch {
	Write-Host "Account Password could not be verified as successfully deleted, kindly check Set-ADAccountPassword cmdlet in script" -ForegroundColor Red
	Write-Host $_.Exception.Message -ForegroundColor Yellow
	}
	$Groups = Get-ADPrincipalGroupMembership -Identity $SamAccountName | Where-Object { $_.Name -ne "Domain Users"}
	
	try {
	$GroupNote = ""
	if ($Groups) {
    	$GroupNote = "Removed groups: $(($Groups.Name) -join ', '). "
    	foreach ($Group in $Groups) { Remove-ADGroupMember -Identity $Group -Members $SamAccountName -Confirm:$false }
	}
	Set-ADUser -Identity $SamAccountName -Description "$GroupNote Disabled $(Get-Date -Format 'yyyy-MM-dd'), ticket $TicketNumber" -ErrorAction Stop
	Get-ADUser $SamAccountName | Move-ADObject -TargetPath "OU=Leavers,OU=Chronos,DC=chronos,DC=lab" -ErrorAction Stop
	}
	catch {
		Write-Host $_.Exception.Message -ForegroundColor Yellow
	}
	Start-Process powershell -ArgumentList '-NoProfile -Command "Import-Module ADSync; Start-ADSyncSyncCycle -PolicyType Delta | Out-Null; Start-Sleep 5; while ((Get-ADSyncScheduler).SyncCycleInProgress) { Start-Sleep 5 }"' -Wait -NoNewWindow
	try {
	Connect-MgGraph -ClientId $($Config.ClientId) -TenantId $($Config.TenantId) -CertificateThumbprint $($Config.Thumbprint) -NoWelcome
	$ADUser = Get-ADUSer -Identity $SamAccountName -Properties UserPrincipalName
	$UserUPN = $ADUser.UserPrincipalName
	$RevokeResult = Revoke-MgUserSignInSession -UserId $UserUPN
	$isRevoked = $RevokeResult.Value
	} catch {
	$isRevoked = "FAILED: $($_.Exception.Message)"
	}
	finally {
	Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
	}
	if($isRevoked -eq $true){
		Write-Output "User Session was successfully revoked"
	}
	else {
		Write-Warning "User session was not able to be successfully revoked, please try again."
	}
	[PSCustomObject]@{
   		Date         = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    		TicketNumber = $TicketNumber
		Username = $SamAccountName
		RunBy = $env:USERNAME
		Revoked = $isRevoked
	} | Export-Csv -Path $LogPath -Append -NoTypeInformation
	}
	