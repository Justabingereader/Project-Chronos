function Move-ChronosADUser {
    param(
        [Parameter(Mandatory = $true)] [string]$SamAccountName,
        [Parameter(Mandatory = $true)] [string]$NewDepartment,
        [Parameter(Mandatory = $true)] [int]$TicketNumber,
        [int]$GraceDays = 30
    )

    $Config = Import-PowerShellDataFile -Path "C:\Scripts\chronos-config.psd1"
    $roles  = Import-PowerShellDataFile -Path "C:\Scripts\chronos-roles.psd1"

    $LogFolder = "C:\Logs"
    if (-not (Test-Path $LogFolder)) { New-Item -ItemType Directory -Path $LogFolder | Out-Null }
    $LogPath = "$LogFolder\MoverAuditLog.csv"

    if (Test-Path $LogPath) {
        $PastRecords = Import-Csv -Path $LogPath
        if ($PastRecords.Ticket -contains $TicketNumber) {
            Write-Warning "Ticket $TicketNumber has already been processed. Stopping script."
            return
        }
    }

    if ($NewDepartment -notin $roles.Departments.Keys) {
        Write-Warning "Unknown department '$NewDepartment'. Valid options: $($roles.Departments.Keys -join ', ')"
        return
    }
    $TargetRole = $roles.Departments[$NewDepartment]

    try {
        $PreviousIdentity = Get-ADUser -Identity $SamAccountName -Properties Department, MemberOf, Enabled, UserPrincipalName -ErrorAction Stop
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-Warning "Guard failed: User '$SamAccountName' does not exist in Active Directory. Aborting."
        return
    }
    catch {
        Write-Error "Failed to query Active Directory for '$SamAccountName': $($_.Exception.Message)"
        return
    }

    if (-not $PreviousIdentity.Enabled) {
        Write-Warning "Guard failed: Account '$SamAccountName' is disabled (leaver). Rehiring requires a separate joiner process. Aborting."
        return
    }
    if ($PreviousIdentity.Department -eq $NewDepartment) {
        Write-Warning "Guard failed: User '$SamAccountName' is already in department '$NewDepartment'. No move required. Aborting."
        return
    }

    $PreviousOU     = ($PreviousIdentity.DistinguishedName -split ',', 2)[1]
    $PreviousGroups = @($PreviousIdentity.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' })

    $BeforeSnapshot = [PSCustomObject]@{
        Date           = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Stage          = "BEFORE"
        Ticket         = $TicketNumber
        SamAccountName = $PreviousIdentity.SamAccountName
        OU             = $PreviousOU
        Department     = $PreviousIdentity.Department
        Groups         = ($PreviousGroups -join '; ')
        RunBy          = $env:USERNAME
        SessionRevoked = "N/A"
        Status         = "N/A"
    }

    $AllRoleGroups    = @($roles.Departments.Values | ForEach-Object { $_.Groups })
    $BirthrightGroups = @("Domain Users")

    $OldRoleGroups = $PreviousGroups | Where-Object { $AllRoleGroups -contains $_ }
    $AdHocGroups   = $PreviousGroups | Where-Object { $AllRoleGroups -notcontains $_ -and $BirthrightGroups -notcontains $_ -and $_ -notlike "TEMP_Expire_*" }

    $CurrentStep = "Initialization"
    $Status      = "Complete"

    try {
        if ($AdHocGroups) {
            $CurrentStep     = "Shadow Group Transition"
            $ExpiryDate      = (Get-Date).AddDays($GraceDays).ToString("yyyy-MM-dd")
            $ShadowGroupName = "TEMP_Expire_${ExpiryDate}_$SamAccountName"

            if (-not (Get-ADGroup -Filter "Name -eq '$ShadowGroupName'" -ErrorAction SilentlyContinue)) {
                New-ADGroup -Name $ShadowGroupName -GroupScope Global -GroupCategory Security -Path $roles.TransitionOU -Description "Ticket #$TicketNumber - Expires $ExpiryDate" -ErrorAction Stop
            }
            Add-ADGroupMember -Identity $ShadowGroupName -Members $SamAccountName -ErrorAction Stop
            foreach ($Group in $AdHocGroups) {
                Add-ADGroupMember -Identity $Group -Members $ShadowGroupName -ErrorAction Stop
            }
            Remove-ADPrincipalGroupMembership -Identity $SamAccountName -MemberOf $AdHocGroups -Confirm:$false -ErrorAction Stop
        }

        if ($OldRoleGroups) {
            $CurrentStep = "Remove Old Role Groups"
            Remove-ADPrincipalGroupMembership -Identity $SamAccountName -MemberOf $OldRoleGroups -Confirm:$false -ErrorAction Stop
        }

        $CurrentStep = "Add New Role Groups"
        Add-ADPrincipalGroupMembership -Identity $SamAccountName -MemberOf $TargetRole.Groups -ErrorAction Stop

        $CurrentStep = "Update Department Attribute"
        Set-ADUser -Identity $SamAccountName -Department $NewDepartment -ErrorAction Stop

        $CurrentStep = "Move OU"
        Move-ADObject -Identity $PreviousIdentity.DistinguishedName -TargetPath $TargetRole.OU -ErrorAction Stop

        $CurrentStep = "Entra Connect Delta Sync"
        Start-Process powershell -ArgumentList '-NoProfile -Command "Import-Module ADSync; Start-ADSyncSyncCycle -PolicyType Delta | Out-Null; Start-Sleep 5; while ((Get-ADSyncScheduler).SyncCycleInProgress) { Start-Sleep 5 }"' -Wait -NoNewWindow
    }
    catch {
        $Status = "Partial: $CurrentStep"
        Write-Warning "FAILED during [$CurrentStep]: $($_.Exception.Message)"
    }

    if ($Status -eq "Complete") {
        try {
            Connect-MgGraph -ClientId $Config.ClientId -TenantId $Config.TenantId -CertificateThumbprint $Config.Thumbprint -NoWelcome -ErrorAction Stop
            $RevokeResult = Revoke-MgUserSignInSession -UserId $PreviousIdentity.UserPrincipalName -ErrorAction Stop
            $isRevoked = $RevokeResult.Value
        }
        catch {
            $isRevoked = "FAILED: $($_.Exception.Message)"
        }
        finally {
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        }

        if ($isRevoked -eq $true) {
            Write-Host "User session was successfully revoked." -ForegroundColor Green
        }
        else {
            Write-Warning "Session revocation status: $isRevoked"
        }
    }
    else {
        $isRevoked = "Skipped ($Status)"
        Write-Warning "Skipping Entra session revocation because move status is '$Status'."
    }

    $UpdatedIdentity = Get-ADUser -Identity $SamAccountName -Properties Department, MemberOf -ErrorAction Stop
    $UpdatedOU       = ($UpdatedIdentity.DistinguishedName -split ',', 2)[1]
    $UpdatedGroups   = @($UpdatedIdentity.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' })

    $AfterSnapshot = [PSCustomObject]@{
        Date           = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Stage          = "AFTER"
        Ticket         = $TicketNumber
        SamAccountName = $UpdatedIdentity.SamAccountName
        OU             = $UpdatedOU
        Department     = $UpdatedIdentity.Department
        Groups         = ($UpdatedGroups -join '; ')
        RunBy          = $env:USERNAME
        SessionRevoked = $isRevoked
        Status         = $Status
    }

    $LogResults = @($BeforeSnapshot, $AfterSnapshot)
    $LogResults | Export-Csv -Path $LogPath -Append -NoTypeInformation
    return $LogResults
}
