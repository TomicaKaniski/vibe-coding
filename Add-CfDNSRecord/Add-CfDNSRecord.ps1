<#
.SYNOPSIS
Cloudflare DNS Auto-Check & Update Tool 
- Auto Zone ID
- Smart Record Handling (Add / Update / Delete)
- Backup before & after (JSON + CSV)
- Diff of changes
- Looped mode for multiple records

.DESCRIPTION
This script manages Cloudflare DNS records:
- Checks if a record exists, lets you add/update/delete as needed
- Fetches Zone ID automatically from root domain
- Backs up DNS state before and after (JSON + CSV)
- Displays a diff of what changed
- Can run interactively (prompts) or with parameters
- Supports A, CNAME, TXT

.EXAMPLE
Interactive:
    .\Add-CfDNSRecord.ps1

With parameters:
    .\Add-CfDNSRecord.ps1 -ApiToken "xxxxx" -RootDomain "example.com" -SubDomain "test" -RecordType "A" -RecordValue "203.0.113.10" -TTL 120 -Proxied -BackupPath "C:\Backups\CF"
#>

param(
    [string]$ApiToken,
    [string]$RootDomain,
    [string]$SubDomain,
    [string]$RecordType,
    [string]$RecordValue,
    [int]$TTL = 120,
    [switch]$Proxied,
    [string]$BackupPath = "."
)

# ======== PROMPT IF MISSING (global settings) ========
if (-not $ApiToken)    { $ApiToken    = Read-Host "Enter your Cloudflare API Token" }
if (-not $RootDomain)  { $RootDomain  = Read-Host "Enter your root domain (e.g., example.com)" }

# ======== FUNCTIONS ========

function Get-CFZoneId {
    param($rootDomain, $apiToken)
    $url = "https://api.cloudflare.com/client/v4/zones?name=$rootDomain"
    $headers = @{ "Authorization" = "Bearer $apiToken"; "Content-Type" = "application/json" }
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method GET
    if ($response.result.Count -gt 0) {
        return $response.result[0].id
    } else {
        throw "No zone found for $rootDomain"
    }
}

function Get-CFRecords {
    param($zoneId, $apiToken)
    $url = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?per_page=1000"
    $headers = @{ "Authorization" = "Bearer $apiToken"; "Content-Type" = "application/json" }
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method GET
    return $response.result
}

function Backup-CFRecords {
    param($records, $backupFileJson, $backupFileCsv)

    # JSON backup
    $records | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 $backupFileJson
    # CSV backup
    $records | Select-Object name,type,content,ttl,proxied | Export-Csv -Path $backupFileCsv -NoTypeInformation -Encoding UTF8

    Write-Host "💾 Backups saved: $backupFileJson , $backupFileCsv" -ForegroundColor Cyan
}

function Get-CFRecord {
    param($zoneId, $recordName, $recordType, $apiToken)
    $url = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?type=$recordType&name=$recordName"
    $headers = @{ "Authorization" = "Bearer $apiToken"; "Content-Type" = "application/json" }
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method GET
    return $response.result
}

function Remove-CFRecord {
    param($zoneId, $recordId, $apiToken)
    $url = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$recordId"
    $headers = @{ "Authorization" = "Bearer $apiToken"; "Content-Type" = "application/json" }
    Invoke-RestMethod -Uri $url -Headers $headers -Method DELETE
    Write-Host "🗑️ Record deleted successfully." -ForegroundColor Red
}

function AddOrUpdate-CFRecord {
    param($zoneId, $recordName, $recordType, $recordValue, $ttl, $proxied, $apiToken)

    $existing = Get-CFRecord -zoneId $zoneId -recordName $recordName -recordType $recordType -apiToken $apiToken
    $headers = @{ "Authorization" = "Bearer $apiToken"; "Content-Type" = "application/json" }

    if ($existing) {
        Write-Host "`nRecord already exists: $recordName [$recordType] → $($existing.content)" -ForegroundColor Yellow
        $choice = Read-Host "Do you want to (U)pdate, (D)elete, or (S)kip?"
        switch -Regex ($choice) {
            "^[Dd]" {
                Remove-CFRecord -zoneId $zoneId -recordId $existing.id -apiToken $apiToken
                return
            }
            "^[Ss]" {
                Write-Host "⏭️ Skipped." -ForegroundColor Cyan
                return
            }
        }
    }

    # Build request body depending on type
    switch ($recordType) {
        "A" {
            $body = @{
                type    = $recordType
                name    = $recordName
                content = $recordValue
                ttl     = $ttl
                proxied = [bool]$proxied
            }
        }
        "CNAME" {
            $body = @{
                type    = $recordType
                name    = $recordName
                content = $recordValue
                ttl     = $ttl
                proxied = [bool]$proxied
            }
        }
        "TXT" {
            $body = @{
                type    = $recordType
                name    = $recordName
                content = $recordValue
                ttl     = $ttl
            }
        }
    }

    $bodyJson = $body | ConvertTo-Json -Depth 5

    if ($existing) {
        Write-Host "`nUpdating record: $recordName" -ForegroundColor Yellow
        $url = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$($existing.id)"
        Invoke-RestMethod -Uri $url -Headers $headers -Method PUT -Body $bodyJson
        Write-Host "✅ Record updated." -ForegroundColor Green
    } else {
        Write-Host "`nAdding new record: $recordName" -ForegroundColor Yellow
        $url = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records"
        Invoke-RestMethod -Uri $url -Headers $headers -Method POST -Body $bodyJson
        Write-Host "✅ Record added." -ForegroundColor Green
    }
}

function Compare-Records {
    param($before, $after)

    Write-Host "`n===== DNS Changes Detected =====" -ForegroundColor Magenta

    # Index records by name+type
    $beforeMap = @{}
    foreach ($rec in $before) { $beforeMap["$($rec.name)|$($rec.type)"] = $rec }

    $afterMap = @{}
    foreach ($rec in $after) { $afterMap["$($rec.name)|$($rec.type)"] = $rec }

    # Added
    $addedKeys = $afterMap.Keys | Where-Object { -not $beforeMap.ContainsKey($_) }
    foreach ($key in $addedKeys) {
        $rec = $afterMap[$key]
        Write-Host "➕ Added: $($rec.name) [$($rec.type)] → $($rec.content)" -ForegroundColor Green
    }

    # Removed
    $removedKeys = $beforeMap.Keys | Where-Object { -not $afterMap.ContainsKey($_) }
    foreach ($key in $removedKeys) {
        $rec = $beforeMap[$key]
        Write-Host "➖ Removed: $($rec.name) [$($rec.type)] → $($rec.content)" -ForegroundColor Red
    }

    # Modified
    foreach ($key in $afterMap.Keys) {
        if ($beforeMap.ContainsKey($key)) {
            $beforeRec = $beforeMap[$key]
            $afterRec = $afterMap[$key]
            if ($beforeRec.content -ne $afterRec.content -or $beforeRec.proxied -ne $afterRec.proxied) {
                Write-Host "✏️ Updated: $($afterRec.name) [$($afterRec.type)]" -ForegroundColor Yellow
                Write-Host "    Old → $($beforeRec.content) (Proxied: $($beforeRec.proxied))" -ForegroundColor DarkGray
                Write-Host "    New → $($afterRec.content) (Proxied: $($afterRec.proxied))" -ForegroundColor DarkGray
            }
        }
    }
}

# ======== EXECUTION ========
try {
    $zoneId = Get-CFZoneId -rootDomain $RootDomain -apiToken $ApiToken
    Write-Host "Found Zone ID: $zoneId" -ForegroundColor Magenta

    do {
        # Prompt per-record
        $SubDomain   = Read-Host "Enter subdomain (leave blank for root)"
        $RecordName  = if ([string]::IsNullOrWhiteSpace($SubDomain)) { $RootDomain } else { "$SubDomain.$RootDomain" }

        Write-Host "Select DNS Record Type:" -ForegroundColor Cyan
        $choices = @("A","CNAME","TXT")
        for ($i=0; $i -lt $choices.Count; $i++) {
            Write-Host "[$($i+1)] $($choices[$i])"
        }
        $sel = Read-Host "Enter choice number"
        if ($sel -match '^[1-3]$') {
            $RecordType = $choices[$sel-1]
        } else {
            throw "Invalid selection."
        }

        $RecordValue = Read-Host "Enter the desired record value (IP, hostname, or TXT string)"
        $TTL         = [int](Read-Host "Enter TTL in seconds (e.g., 120)")
        if ($RecordType -in @("A","CNAME")) {
            $proxAns = Read-Host "Should Cloudflare proxy this record? (yes/no)"
            $Proxied = $proxAns -match '^(y|yes)$'
        } else {
            $Proxied = $false
        }

        # 1. Backup current state
        $beforeRecords = Get-CFRecords -zoneId $zoneId -apiToken $ApiToken
        $timestamp = (Get-Date -Format "yyyyMMdd-HHmmss")
        $beforeFileJson = Join-Path $BackupPath "$RootDomain-before-$timestamp.json"
        $beforeFileCsv  = Join-Path $BackupPath "$RootDomain-before-$timestamp.csv"
        Backup-CFRecords -records $beforeRecords -backupFileJson $beforeFileJson -backupFileCsv $beforeFileCsv

        # 2. Perform add/update/delete
        AddOrUpdate-CFRecord -zoneId $zoneId -recordName $RecordName -recordType $RecordType -recordValue $RecordValue -ttl $TTL -proxied $Proxied -apiToken $ApiToken

        # 3. Backup after state
        $afterRecords = Get-CFRecords -zoneId $zoneId -apiToken $ApiToken
        $afterFileJson = Join-Path $BackupPath "$RootDomain-after-$timestamp.json"
        $afterFileCsv  = Join-Path $BackupPath "$RootDomain-after-$timestamp.csv"
        Backup-CFRecords -records $afterRecords -backupFileJson $afterFileJson -backupFileCsv $afterFileCsv

        # 4. Show differences
        Compare-Records -before $beforeRecords -after $afterRecords

        $again = Read-Host "`nDo you want to manage another record? (yes/no)"
    } while ($again -match '^(y|yes)$')

    Write-Host "`n✅ Completed. Backups + diff saved to $BackupPath" -ForegroundColor Green

} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}
