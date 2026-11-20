param(
    [string]$SearchBase = "OU=Transition,OU=Groups,OU=Chronos,DC=chronos,DC=lab",
    [string]$EventSource = "ChronosStaleCheck"
)


try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $Groups = @(Get-ADGroup -Filter "Name -like 'TEMP_Expire_*'" -SearchBase $SearchBase -Properties Description -ErrorAction Stop)
}
catch {
    $ErrMsg = "Shadow group staleness check failed querying '$SearchBase': $($_.Exception.Message)"
    Write-EventLog -LogName "Application" -Source $EventSource -EventId 1003 -EntryType "Error" -Message $ErrMsg
    Write-Error $ErrMsg
    exit 1
}

$Today = (Get-Date).Date
$IssueFound = $false

foreach ($Group in $Groups) {
    $GroupName = $Group.Name
    $Ticket    = if ($Group.Description) { $Group.Description.Trim() } else { "None" }
    $AlertMsg  = $null
    $EventId   = 1001

    if ($GroupName -match '^TEMP_Expire_(\d{4}-\d{2}-\d{2})(?:_|$)') {
        $RawDate = $Matches[1]
        $ParsedDate = [datetime]::MinValue

        if ([datetime]::TryParseExact($RawDate, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$ParsedDate)) {
            if ($ParsedDate.Date -le $Today) {
                $EventId  = 1002
                $AlertMsg = "Expired shadow group found: '$GroupName' expired on $($ParsedDate.ToString('yyyy-MM-dd')). Ticket/Description: $Ticket"
            }
        }
        else {
            $AlertMsg = "Invalid date in shadow group name: '$GroupName' contains unparseable date '$RawDate'. Ticket/Description: $Ticket"
        }
    }
    else {
        $AlertMsg = "Malformed shadow group name: '$GroupName' does not match 'TEMP_Expire_YYYY-MM-DD'. Ticket/Description: $Ticket"
    }

    if ($AlertMsg) {
        $IssueFound = $true
        Write-EventLog -LogName "Application" -Source $EventSource -EventId $EventId -EntryType "Warning" -Message $AlertMsg
    }
}

if (-not $IssueFound) {
    $ClearMsg = "All clear: $($Groups.Count) shadow group(s) checked in '$SearchBase'."
    Write-EventLog -LogName "Application" -Source $EventSource -EventId 1000 -EntryType "Information" -Message $ClearMsg
    Write-Host $ClearMsg -ForegroundColor Green
}
