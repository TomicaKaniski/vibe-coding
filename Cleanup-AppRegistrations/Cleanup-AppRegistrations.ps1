<#
.SYNOPSIS
    Cleanup outdated/unused Entra ID (Azure AD) app registrations.
.DESCRIPTION
    Produces JSON backup and HTML report of applications, including certificates,
    client secrets, federated credentials, last sign-in info, and credential stats.
    Supports dry-run by default, deletion with -Force, and publisher exclusions.
#>

param(
    [int]$UnusedFor = 90,
    [int]$CreatedBefore = 365,
    [string[]]$ExcludePublisher = @("Microsoft","Microsoft Corporation"),
    [switch]$Force,
    [string]$OutputPath = "output",
    [switch]$OpenReport
)

# -----------------------------
# Helper: get EndDateTime safely
# -----------------------------
function Get-EndDateSafe {
    param([object]$appItem)
    if ($null -ne $appItem.EndDateTime) { return $appItem.EndDateTime }
    if ($appItem.AdditionalProperties -and $appItem.AdditionalProperties.ContainsKey("EndDateTime")) {
        $val = $appItem.AdditionalProperties["EndDateTime"]
        try { return [datetime]::Parse($val) } catch { return $null }
    }
    return $null
}

# -----------------------------
# HTML Encode helper
# -----------------------------
function ConvertTo-HtmlSafe([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { return "" }
    return $s.Replace("&","&amp;").Replace("<","&lt;").Replace(">","&gt;").Replace('"',"&quot;")
}

# -----------------------------
# HTML report function
# -----------------------------
function New-HTMLReport {
    param(
        [array]$Data,
        [string]$Path
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Data = $Data | Sort-Object DisplayName

    $html = @"
<html>
<head>
<meta charset='utf-8'>
<title>Entra App Cleanup Report</title>
<style>
body { font-family: Arial, Helvetica, sans-serif; margin: 20px; }
table { border-collapse: collapse; width: 100%; margin-top: 20px; font-size: 12px; }
th, td { border: 1px solid #ccc; padding: 4px; text-align: left; vertical-align: top; }
th { background-color: #333; color: white; }
tr:nth-child(even) { background-color: #f9f9f9; }
.header { font-size: 22px; font-weight: bold; }
.subheader { font-size: 14px; margin-top: 6px; color: #444; }
.footer { margin-top: 40px; font-size: 12px; color: #666; }
.expired { color: red; font-weight: bold; }
.valid { color: green; }
.na { color: gray; }
.sub-th { font-size: 11px; padding: 2px; background-color: #555; color: white; }
.small { font-size: 11px; color:#555 }
</style>
</head>
<body>
<div class='header'>Microsoft Entra ID - App Cleanup Report</div>
<div class='subheader'>Generated: $timestamp</div>

<table>
<tr>
<th rowspan='2'>App Name</th><th rowspan='2'>AppId</th><th rowspan='2'>ObjectId</th><th rowspan='2'>Publisher</th>
<th rowspan='2'>Created</th><th rowspan='2'>Days Old</th><th rowspan='2'>Excluded Publisher</th>
<th rowspan='2'>Last Sign-In</th><th rowspan='2'>Sign-In Status</th><th rowspan='2'>Credential Summary</th>
<th colspan='4'>Certificates</th><th colspan='4'>Client Secrets</th><th colspan='2'>Federated Credentials</th>
</tr>
<tr>
<th class='sub-th'>Description</th><th class='sub-th'>Thumbprint</th><th class='sub-th'>Expires</th><th class='sub-th'>Status</th>
<th class='sub-th'>Description</th><th class='sub-th'>Secret ID</th><th class='sub-th'>Expires</th><th class='sub-th'>Status</th>
<th class='sub-th'>Name</th><th class='sub-th'>Subject</th>
</tr>
"@

    foreach ($app in $Data) {
        $created = if ($app.CreatedDate) { $app.CreatedDate.ToString("dd/MM/yyyy") } else { "<not set>" }
        $excluded = if ($app.ExcludedPublisher) { "Yes" } else { "No" }
        $lastSignIn = if ($app.LastSignInDate) { $app.LastSignInDate.ToLocalTime().ToString("dd/MM/yyyy") } else { "<no sign-ins>" }
        $lastStatus = if ($app.LastSignInStatus) { ConvertTo-HtmlSafe($app.LastSignInStatus) } else { "<unknown>" }

        # -----------------------------
        # Credential summaries with color coding
        # -----------------------------
        $certExpiringSoon = ($app.Certificates | Where-Object {
            ($end = Get-EndDateSafe $_) -and ($end -le (Get-Date).AddDays(30)) -and ($end -gt (Get-Date))
        }).Count
        $certExpired = ($app.Certificates | Where-Object {
            ($end = Get-EndDateSafe $_) -and ($end -le (Get-Date))
        }).Count
        $certValid = ($app.Certificates.Count) - $certExpiringSoon - $certExpired

        $secExpiringSoon = ($app.Secrets | Where-Object {
            ($end = Get-EndDateSafe $_) -and ($end -le (Get-Date).AddDays(30)) -and ($end -gt (Get-Date))
        }).Count
        $secExpired = ($app.Secrets | Where-Object {
            ($end = Get-EndDateSafe $_) -and ($end -le (Get-Date))
        }).Count
        $secValid = ($app.Secrets.Count) - $secExpiringSoon - $secExpired

        $fedCount = if ($app.Federated) { $app.Federated.Count } else { 0 }

        $credSummary = @()
        $credSummary += "Certs: <span style='color:red'>$certExpired</span> expired, <span style='color:orange'>$certExpiringSoon</span> expiring soon, <span style='color:green'>$certValid</span> valid"
        $credSummary += "<br>Secrets: <span style='color:red'>$secExpired</span> expired, <span style='color:orange'>$secExpiringSoon</span> expiring soon, <span style='color:green'>$secValid</span> valid"
        $credSummary += "<br>Federated identities: <span style='color:green'>$fedCount</span>"

        # -----------------------------
        # Certificates
        # -----------------------------
        $certDesc = $certThumb = $certExp = $certStatus = "None"
        if ($app.Certificates -and $app.Certificates.Count -gt 0) {
            $certDesc = $certThumb = $certExp = $certStatus = ""
            foreach ($c in $app.Certificates) {
                $desc = ConvertTo-HtmlSafe($c.DisplayName)
                $thumb = ConvertTo-HtmlSafe($c.KeyId)
                $end = Get-EndDateSafe $c
                if ($end) {
                    $expires = $end.ToLocalTime().ToString("dd/MM/yyyy")
                    $status = if ($end -lt (Get-Date)) { "<span class='expired'>Expired</span>" } else { "<span class='valid'>Valid</span>" }
                } else {
                    $expires = "N/A"
                    $status = "<span class='na'>N/A</span>"
                }
                $certDesc += "$desc<br>"
                $certThumb += "$thumb<br>"
                $certExp += "$expires<br>"
                $certStatus += "$status<br>"
            }
        }

        # -----------------------------
        # Client Secrets
        # -----------------------------
        $secDesc = $secId = $secExp = $secStatus = "None"
        if ($app.Secrets -and $app.Secrets.Count -gt 0) {
            $secDesc = $secId = $secExp = $secStatus = ""
            foreach ($s in $app.Secrets) {
                $desc = ConvertTo-HtmlSafe($s.DisplayName)
                $id = ConvertTo-HtmlSafe($s.KeyId)
                $end = Get-EndDateSafe $s
                if ($end) {
                    $expires = $end.ToLocalTime().ToString("dd/MM/yyyy")
                    $status = if ($end -lt (Get-Date)) { "<span class='expired'>Expired</span>" } else { "<span class='valid'>Valid</span>" }
                } else {
                    $expires = "N/A"
                    $status = "<span class='na'>N/A</span>"
                }
                $secDesc += "$desc<br>"
                $secId += "$id<br>"
                $secExp += "$expires<br>"
                $secStatus += "$status<br>"
            }
        }

        # -----------------------------
        # Federated
        # -----------------------------
        $fedName = $fedSubj = "None"
        if ($app.Federated -and $app.Federated.Count -gt 0) {
            $fedName = $fedSubj = ""
            foreach ($f in $app.Federated) {
                $fedName += ConvertTo-HtmlSafe($f.Name) + "<br>"
                $fedSubj += ConvertTo-HtmlSafe($f.Subject) + "<br>"
            }
        }

        # -----------------------------
        # Add row
        # -----------------------------
        $html += "<tr>
<td>$($app.DisplayName)</td><td>$($app.AppId)</td><td>$($app.ObjectId)</td><td>$($app.Publisher)</td>
<td>$created</td><td>$($app.DaysOld)</td><td>$excluded</td>
<td>$lastSignIn</td><td class='small'>$lastStatus</td><td class='small'>$credSummary</td>
<td>$certDesc</td><td>$certThumb</td><td>$certExp</td><td>$certStatus</td>
<td>$secDesc</td><td>$secId</td><td>$secExp</td><td>$secStatus</td>
<td>$fedName</td><td>$fedSubj</td>
</tr>"
    }

    $html += @"
</table>
<div class='footer'>Report generated automatically by Cleanup-AppRegistrations.ps1</div>
</body>
</html>
"@

    $html | Out-File -FilePath $Path -Encoding UTF8
}

# -----------------------------
# Ensure output path exists
# -----------------------------
if (-not (Test-Path $OutputPath)) { New-Item -Path $OutputPath -ItemType Directory | Out-Null }

# -----------------------------
# Connect to Microsoft Graph
# -----------------------------
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "Application.Read.All","Application.ReadWrite.All","AuditLog.Read.All" -NoWelcome

$now = Get-Date
$logWindowStart = $now.AddDays(-$UnusedFor)

Write-Host "Fetching applications..." -ForegroundColor Cyan
$applications = Get-MgApplication -All | Select-Object * ,
    @{Name="Certificates";Expression={$_.KeyCredentials}},
    @{Name="Secrets";Expression={$_.PasswordCredentials}},
    @{Name="Federated";Expression={@(try { Get-MgApplicationFederatedIdentityCredential -ApplicationId $_.Id -ErrorAction SilentlyContinue } catch {@()})}}

# -----------------------------
# Attempt to fetch sign-in logs for the timeframe once
# -----------------------------
$signinsAvailable = $true
$signinsByApp = @{}
try {
    Write-Host "Fetching sign-in logs since $($logWindowStart.ToString('u')) ..." -ForegroundColor Cyan
    $rawSignIns = Get-MgAuditLogSignIn -Filter "createdDateTime ge $($logWindowStart.ToString('o'))" -All -ErrorAction Stop
    $rawSignIns | ForEach-Object {
        $aid = $_.AppId
        if (-not $aid) { return }
        $dt = $_.CreatedDateTime
        if ($signinsByApp.ContainsKey($aid)) {
            if ($dt -gt $signinsByApp[$aid]) { $signinsByApp[$aid] = $dt }
        } else { $signinsByApp[$aid] = $dt }
    }
    Write-Host "Sign-in logs fetched: $($signinsByApp.Count) apps have sign-in entries." -ForegroundColor Cyan
} catch {
    Write-Warning "Unable to fetch sign-in logs. Falling back to credentials-only checks."
    $signinsAvailable = $false
    $signinsByApp = @{}
}

# -----------------------------
# Prepare grouped apps
# -----------------------------
$groupedApps = @()
foreach ($app in $applications) {
    $publisher = $app.PublisherDomain
    $isExcluded = $false
    $excludedReason = $null
    foreach ($p in $ExcludePublisher) {
        if ($publisher -like "*$p*") { $isExcluded = $true; $excludedReason = "Excluded Publisher" }
    }

    $daysOld = ($now - $app.CreatedDateTime).Days
    $matchCreated = ($CreatedBefore -gt 0) -and ($daysOld -ge $CreatedBefore)

    # Last sign-in lookup
    $lastSignInDate = $null
    $lastSignInStatus = "NoSignIns"
    if ($signinsByApp.ContainsKey($app.AppId)) {
        $lastSignInDate = $signinsByApp[$app.AppId]
        $lastSignInStatus = "HasSignIns"
    } elseif (-not $signinsAvailable) {
        $lastSignInStatus = "LogsUnavailable"
    } else { $lastSignInStatus = "NoSignIns" }

    # Check credentials for usage
    $unused = $true
    $allCreds = @()
    if ($app.Certificates) { $allCreds += $app.Certificates }
    if ($app.Secrets) { $allCreds += $app.Secrets }
    foreach ($c in $allCreds) {
        $end = Get-EndDateSafe $c
        if ($end -and $end -gt $logWindowStart) { $unused = $false; break }
    }

    if ($unused -and $signinsAvailable -and $lastSignInDate -and $lastSignInDate -gt $logWindowStart) {
        $unused = $false
        $excludedReason = "Still used"
    }

    $shouldDelete = ($matchCreated -and $unused)
    if ($isExcluded) { $shouldDelete = $false }

    $groupedApps += [PSCustomObject]@{
        DisplayName       = $app.DisplayName
        AppId             = $app.AppId
        ObjectId          = $app.Id
        Publisher         = $publisher
        CreatedDate       = $app.CreatedDateTime
        DaysOld           = $daysOld
        ExcludedPublisher = $isExcluded
        ExcludedReason    = $excludedReason
        ShouldDelete      = $shouldDelete
        Certificates      = $app.Certificates
        Secrets           = $app.Secrets
        Federated         = $app.Federated
        LastSignInDate    = $lastSignInDate
        LastSignInStatus  = $lastSignInStatus
    }
}

# -----------------------------
# Console summary
# -----------------------------
$totalApps = $groupedApps.Count
$candidateCount = ($groupedApps | Where-Object { $_.ShouldDelete }).Count
$logsUnavailable = ($groupedApps | Where-Object { $_.LastSignInStatus -eq "LogsUnavailable" }).Count
$excludedCount = ($groupedApps | Where-Object { $_.ExcludedReason }).Count

Write-Host "`n=== Cleanup Summary ==="
Write-Host "Total apps scanned       : $totalApps"
Write-Host "Candidates for deletion  : $candidateCount"
Write-Host "Sign-in logs unavailable : $logsUnavailable"
Write-Host "Apps excluded (reason)   : $excludedCount"
Write-Host "========================`n"

# -----------------------------
# Filter candidates
# -----------------------------
$candidates = $groupedApps | Where-Object { $_.ShouldDelete } | Sort-Object DisplayName

# -----------------------------
# Save JSON backup
# -----------------------------
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupJson = Join-Path $OutputPath -ChildPath "PreDeletion-AppBackup-$timestamp.json"
$candidates | ConvertTo-Json -Depth 12 -Compress | Out-File -FilePath $backupJson -Encoding UTF8
Write-Host "Backup JSON created: $backupJson" -ForegroundColor Green

# -----------------------------
# Save HTML report
# -----------------------------
$reportHtml = Join-Path $OutputPath -ChildPath "CleanupReport-$timestamp.html"
New-HTMLReport -Data $groupedApps -Path $reportHtml
Write-Host "HTML report created: $reportHtml" -ForegroundColor Cyan
if ($OpenReport) { Start-Process $reportHtml }

# -----------------------------
# Delete if forced
# -----------------------------
if (-not $Force) { Write-Host "Dry-run mode: no deletion performed. Use -Force to delete." -ForegroundColor Magenta; exit 0 }

Write-Host "FORCE enabled: Deleting applications..." -ForegroundColor Red
foreach ($app in $candidates) {
    try {
        Remove-MgApplication -ApplicationId $app.ObjectId -ErrorAction Stop
        Write-Host "Deleted: $($app.DisplayName)" -ForegroundColor Green
    } catch {
        Write-Host "FAILED to delete $($app.DisplayName): $_" -ForegroundColor Red
    }
}

Write-Host "Operation completed." -ForegroundColor Cyan
