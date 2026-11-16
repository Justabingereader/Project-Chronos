function Disable-ChronosUser {
	param (
	    [Parameter(Mandatory=$true)]
	    [string]$SamAccountName,

	    [Parameter(Mandatory=$true)]
	    [int]$TicketNumber
	)

	Add-Type -AssemblyName System.Web
        $PlainPassword  = [System.Web.Security.Membership]::GeneratePassword(14, 3)
        $SecurePassword = ConvertTo-SecureString -String $PlainPassword -AsPlainText -Force

	$LogFolder = "C:\Logs"
	if (-not (Test-Path $LogFolder)) { New-Item -ItemType Directory -Path $LogFolder | Out-Null }

	$LogPath = "$LogFolder\OffboardingTickets.csv"
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
	

	[PSCustomObject]@{
   		Date         = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    		TicketNumber = $TicketNumber
		Username = $SamAccountName
		RunBy = $env:USERNAME
	} | Export-Csv -Path $LogPath -Append -NoTypeInformation
	}
	