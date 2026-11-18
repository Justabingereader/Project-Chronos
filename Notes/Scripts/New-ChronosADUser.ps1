function New-ChronosADUser {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FirstName,

        [Parameter(Mandatory=$true)]
        [string]$LastName,

        [Parameter(Mandatory=$true)]
        [string]$Department
    )
    $roles = Import-PowerShellDataFile C:\Scripts\chronos-roles.psd1
    if ($Department -notin $roles.Departments.Keys) {
        Write-Warning "Unknown department $Department. Valid: $($roles.Departments.Keys -join ', ')"
        return
    }

    $GeneratedSam = "$FirstName.$LastName".ToLower()
    if ($GeneratedSam.Length -gt 20) {
        $GeneratedSam = $GeneratedSam.Substring(0, 20)
    }
    $GeneratedUPN = "$FirstName.$LastName@chronos.saintshubs.com".ToLower()
    $TargetOU     = $roles.Departments[$Department].OU

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
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        return
    }

    try {
        foreach ($Group in $roles.Departments[$Department].Groups) {
            Add-ADGroupMember -Identity $Group -Members $GeneratedSam -ErrorAction Stop
        }

        Write-Host "Created $GeneratedSam successfully!" -ForegroundColor Green
        Write-Host "Temporary Password: $PlainPassword | UPN: $GeneratedUPN | Path: $TargetOU" -ForegroundColor Yellow
        Start-Process powershell -ArgumentList '-NoProfile -Command "Import-Module ADSync; Start-ADSyncSyncCycle -PolicyType Delta"' -Wait -NoNewWindow
    }
    catch {
        Write-Host "Created $GeneratedSam, but not added to $Group; fix manually." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
}