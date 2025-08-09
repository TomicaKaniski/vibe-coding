<#
.SYNOPSIS
  Organizes picture and video files by date into folders named by yyyyMMdd.

.DESCRIPTION
  Moves .jpg, .jpeg, .png, and .mp4 files from a specified source folder into subfolders based on their metadata or creationdates.

.PARAMETER SourceFolder
  Path to the folder containing media files to organize.

.EXAMPLE
  .\Organize-PicsAndVids.ps1 -SourceFolder "C:\Users\Me\Pictures"
  
.AUTHOR
  Tomica Kaniski, ChatGPT (OpenAI)

.LICENSE
  WTFPL - http://www.wtfpl.net
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$SourceFolder
)

# Timestamped log file in source folder
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $SourceFolder "log-$timestamp.txt"
"" | Out-File -FilePath $logFile

Add-Type -AssemblyName System.Drawing

function Log {
    param (
        [string]$message,
        [string]$level = "INFO"
    )
    $logTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$logTime] [$level] $message"
    
    switch ($level.ToUpper()) {
        "ERRR" { $color = "Red" }
        "WARN"  { $color = "DarkYellow" }
        default { $color = "White" }
    }
    
    Write-Host $logEntry -ForegroundColor $color
    Add-Content -Path $logFile -Value $logEntry
}

function Get-ShellDateCreated {
    param ($filePath)

    $shell = New-Object -ComObject Shell.Application
    $folder = $shell.Namespace((Split-Path $filePath))
    $file = $folder.ParseName((Split-Path $filePath -Leaf))

    $dateCreatedRaw = $null
    for ($i = 0; $i -lt 50; $i++) {
        $header = $folder.GetDetailsOf($null, $i)
        if ($header -match "Date created|Date Created") {
            $dateCreatedRaw = $folder.GetDetailsOf($file, $i)
            if ($dateCreatedRaw) { break }
        }
    }

    if ($dateCreatedRaw) {
        try {
            return [datetime]::Parse($dateCreatedRaw)
        } catch {}
    }

    return $null
}

function Get-BestAvailableDate {
    param (
        [System.IO.FileInfo]$file,
        $metadataDate = $null
    )

    $dates = @()

    if ($metadataDate -is [datetime]) {
        $dates += $metadataDate
    }

    if ($file.CreationTime -is [datetime]) {
        $dates += $file.CreationTime
    }

    if ($file.LastWriteTime -is [datetime]) {
        $dates += $file.LastWriteTime
    }

    if ($dates.Count -eq 0) {
        return $null
    }

    $bestDate = ($dates | Sort-Object)[0]

    if ($bestDate -eq $file.LastWriteTime) {
        Log "Using LastWriteTime for '$($file.Name)' (it's the earliest)." "WARN"
    } elseif ($bestDate -eq $file.CreationTime) {
        Log "Using CreationTime for '$($file.Name)' (earliest available)." "WARN"
    } elseif ($bestDate -eq $metadataDate) {
        Log "Using metadata date for '$($file.Name)' (earliest)." "INFO"
    }

    return $bestDate
}

# Process files in the source folder
Get-ChildItem -Path $SourceFolder -File | Where-Object {
    $_.Extension -match '\.(jpg|jpeg|png|mp4)$'
} | ForEach-Object {
    $fileName = $_.Name
    $file = $_
    $metadataDate = $null
    $extension = $_.Extension.ToLower()

    try {
        if ($extension -in @(".jpg", ".jpeg", ".png")) {
            $image = $null
            try {
                $image = [System.Drawing.Image]::FromFile($_.FullName)
                $propItem = $null
                try {
                    $propItem = $image.GetPropertyItem(36867)  # EXIF DateTaken
                } catch {}
                if ($propItem) {
                    $dateTakenRaw = [System.Text.Encoding]::ASCII.GetString($propItem.Value).Trim([char]0)
                    if (![string]::IsNullOrWhiteSpace($dateTakenRaw)) {
                        try {
                            $metadataDate = [datetime]::ParseExact($dateTakenRaw, "yyyy:MM:dd HH:mm:ss", $null)
                            Log "EXIF Date Taken found for '$fileName': $metadataDate"
                        } catch {
                            Log "Failed to parse EXIF Date Taken for '$fileName'" "WARN"
                        }
                    }
                }
            } catch {
                Log "Failed reading EXIF from '$fileName'" "WARN"
            } finally {
                if ($image) { $image.Dispose() }
            }
        }
        elseif ($extension -eq ".mp4") {
            $metadataDate = Get-ShellDateCreated $_.FullName
            if ($metadataDate) {
                Log "Shell Date Created found for '$fileName': $metadataDate"
            } else {
                Log "No Shell Date Created for '$fileName'" "WARN"
            }
        }

        $dateUsed = Get-BestAvailableDate -file $file -metadataDate $metadataDate

        if (-not $dateUsed) {
            Log "No valid date found for '$fileName', skipping." "ERRR"
            return
        }

        $folderName = $dateUsed.ToString("yyyyMMdd")
        $targetFolder = Join-Path -Path $SourceFolder -ChildPath $folderName

        if (-not (Test-Path $targetFolder)) {
            New-Item -Path $targetFolder -ItemType Directory | Out-Null
            Log "Created folder '$folderName'" "INFO"
        }

        $destPath = Join-Path -Path $targetFolder -ChildPath $fileName

        if (Test-Path $destPath) {
            Log "File already exists at destination: '$destPath'. Skipping." "ERRR"
            return
        }

        Move-Item -Path $_.FullName -Destination $destPath
        Log "Moved '$fileName' to folder '$folderName'" "INFO"

    } catch {
        Log "Failed to process '$fileName': $_" "ERRR"
    }
}
