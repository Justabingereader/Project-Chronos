function New-ChronosADUser {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FirstName,

        [Parameter(Mandatory=$true)]
        [string]$LastName,

        [Parameter(Mandatory=$true)]
        [ValidateSet("IT", "Finance", "Sales")]
        [string]$Department
    )

    $GeneratedSam = "$FirstName.$LastName".ToLower()
    if ($GeneratedSam.Length -gt 20) {
        $GeneratedSam = $GeneratedSam.Substring(0, 20)
    }
    $GeneratedUPN = "$FirstName.$LastName@chronos.saintshubs.com".ToLower()
    $TargetOU     = "OU=$Department,OU=Users,OU=Chronos,DC=chronos,DC=lab"

    $Existing = Get-ADUser -Filter "SamAccountName -eq '$GeneratedSam' -or UserPrincipalName -eq '$GeneratedUPN'"
    if ($Existing) {
    Write-Host "Account already exists: $($Existing.SamAccountName) in $($Existing.DistinguishedName). Nothing created." -ForegroundColor Red
    return
    }

    Add-Type -AssemblyName System.Web
    $PlainPassword  = [System.Web.Security.Membership]::GeneratePassword(14, 3)
    $SecurePassword = ConvertTo-SecureString -String $PlainPassword -AsPlainText -Force

    try {
        New-ADUser -Name "$FirstName $LastName" `
                   -GivenName $FirstName `
                   -Surname $LastName `
                   -DisplayName "$FirstName $LastName" `
                   -Department $Department `
                   -SamAccountName $GeneratedSam `
                   -UserPrincipalName $GeneratedUPN `
                   -Path $TargetOU `
                   -AccountPassword $SecurePassword `
                   -ChangePasswordAtLogon $true `
                   -Enabled $true `
                   -ErrorAction Stop

        Add-ADGroupMember -Identity "GG-$Department" `
                          -Members $GeneratedSam `
                          -ErrorAction Stop

        Write-Host "Created $GeneratedSam successfully!" -ForegroundColor Green
        Write-Host "Temporary Password: $PlainPassword | UPN: $GeneratedUPN | Path: $TargetOU" -ForegroundColor Yellow
    }
    catch {
        Write-Host "Failed to create $GeneratedSam, please try again." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
	Start-Process powershell -ArgumentList '-NoProfile -Command "Import-Module ADSync; Start-ADSyncSyncCycle -PolicyType Delta"' -Wait -NoNewWindow
}
