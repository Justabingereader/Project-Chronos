[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SearchBase = "OU=Transition,OU=Groups,OU=Chronos,DC=chronos,DC=lab",
    [string]$LogPath = "C:\Logs\ExpiredShadowGroups_$(Get-Date -Format 'yyyyMMdd').csv"
)

Import-Module ActiveDirectory -ErrorAction Stop

$LogDir = Split-Path -Path $LogPath -Parent
if (-not (Test-Path -Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$Today = (Get-Date).Date
$RunAs = $env:USERNAME
$LogEntries = @()

try {
    $Groups = Get-ADGroup -Filter "Name -like 'TEMP_Expire_*'" -SearchBase $SearchBase -Properties Description, Members, MemberOf -ErrorAction Stop
}
catch {
    Write-Error "Failed to query Active Directory in '$SearchBase': $($_.Exception.Message)"
    exit 1
}

foreach ($Group in $Groups) {
    $GroupName   = $Group.Name
    $Ticket      = if ($Group.Description) { $Group.Description.Trim() } else { "None" }
    $ExpiryStr   = "Unparsed"
    $MembersList = ""
    $NestedList  = ""
    $Result      = ""

    if ($GroupName -match '^TEMP_Expire_(\d{4}-\d{2}-\d{2})(?:_|$)') {
        $RawDate = $Matches[1]
        $ParsedDate = [datetime]::MinValue
        $Formats = @('yyyy-MM-dd')

        if ([datetime]::TryParseExact($RawDate, $Formats, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$ParsedDate)) {
            $ExpiryDate = $ParsedDate.Date
            $ExpiryStr  = $ExpiryDate.ToString("yyyy-MM-dd")

            if ($ExpiryDate -le $Today) {
                try {
                    $Members = Get-ADGroupMember -Identity $Group.DistinguishedName -ErrorAction Stop |
                               Select-Object -ExpandProperty SamAccountName
                    $MembersList = if ($Members) { $Members -join "; " } else { "None" }

                    $ParentGroups = foreach ($ParentDN in $Group.MemberOf) {
                        (Get-ADGroup -Identity $ParentDN -ErrorAction SilentlyContinue).Name
                    }
                    $NestedList = if ($ParentGroups) { $ParentGroups -join "; " } else { "None" }

                    if ($PSCmdlet.ShouldProcess($GroupName, "Delete expired shadow group")) {
    			Remove-ADGroup -Identity $Group.DistinguishedName -Confirm:$false -ErrorAction Stop
    			$Result = "Deleted"
			} else {
    			$Result = "WhatIf: would delete"
			}
                }
                catch {
                    $Result = "Failed: $($_.Exception.Message)"
                }
            }
            else {
                $Result = "Skipped: Not expired yet"
            }
        }
        else {
            $Result = "Skipped: Invalid date value ($RawDate)"
        }
    }
    else {
        $Result = "Skipped: Date not found in group name"
    }

    $LogEntries += [PSCustomObject]@{
        'date'               = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        'group'              = $GroupName
        'member(s)'          = $MembersList
        'nested-into groups' = $NestedList
        'ticket'             = $Ticket
        'expiry'             = $ExpiryStr
        'result'             = $Result
        'run-as'             = $RunAs
    }
}

if ($LogEntries.Count -gt 0) {
   $LogEntries | Export-Csv -Path $LogPath -NoTypeInformation -Append -Encoding UTF8 -WhatIf:$false
}
