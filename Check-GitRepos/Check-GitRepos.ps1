<#
.SYNOPSIS
    Checks all subfolders/Git repositories (default: first-level) for uncommitted or unpushed changes.

.DESCRIPTION
    Scans the specified base directory for Git repositories. By default, only the base folder
    and its immediate subfolders are checked. Use -Recurse to check all nested subfolders.
    Each repo is pulled, checked for local changes or unpushed commits, and optionally auto-fixed.
    Non-Git folders are also listed in the final summary.

.PARAMETER BasePath
    The base directory to start scanning from. Default: current directory.

.PARAMETER AutoFix
    Automatically commits and pushes changes with a timestamped message.

.PARAMETER Recurse
    Enables recursive scanning of all subfolders for Git repositories.
#>

param(
    [string]$BasePath = ".",
    [switch]$AutoFix,
    [switch]$Recurse
)

# Save current location
$originalLocation = Get-Location
Write-Host "🔍 Scanning repositories in: $BasePath" -ForegroundColor Cyan

# Collect folders based on recursion mode
if ($Recurse) {
    Write-Host "📁 Recursive mode enabled — scanning all subfolders..." -ForegroundColor DarkYellow
    $folders = Get-ChildItem -Path $BasePath -Directory -Recurse -ErrorAction SilentlyContinue
} else {
    Write-Host "📁 Checking only base and first-level subfolders..." -ForegroundColor DarkYellow
    $folders = @(Get-Item $BasePath)
    $folders += Get-ChildItem -Path $BasePath -Directory -ErrorAction SilentlyContinue
}

if (-not $folders) {
    Write-Host "No folders found under $BasePath." -ForegroundColor Yellow
    exit
}

# Identify Git and non-Git folders
$gitRepos = $folders | Where-Object { Test-Path "$($_.FullName)\.git" }
$nonGitFolders = $folders | Where-Object { -not (Test-Path "$($_.FullName)\.git") }

# Initialize summary table
$summary = @()

foreach ($repo in $gitRepos) {
    Write-Host "`n📂 Checking Git repository: $($repo.FullName)" -ForegroundColor Yellow
    Set-Location $repo.FullName

    $repoStatus = [PSCustomObject]@{
        Repository = $repo.FullName
        Status     = ""
    }

    # Step 1: Pull latest changes
    Write-Host "🔄 Pulling latest changes..."
    try {
        git pull | Out-Null
        Write-Host "✅ Pull complete." -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Pull failed — check connectivity or conflicts." -ForegroundColor Red
        $repoStatus.Status = "Pull failed"
        $summary += $repoStatus
        continue
    }

    # Step 2: Check for uncommitted changes
    $status = git status --porcelain
    if ($status) {
        Write-Host "⚠️  Uncommitted changes found!" -ForegroundColor Red
        Write-Host $status

        if ($AutoFix) {
            Write-Host "🧠 AutoFix mode: committing automatically..." -ForegroundColor Cyan
            git add .
            $msg = "auto-commit $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            git commit -m "$msg" | Out-Null
            git push | Out-Null
            Write-Host "✅ Auto-committed and pushed." -ForegroundColor Green
            $repoStatus.Status = "Had uncommitted changes (auto-fixed)"
        } else {
            $fix = Read-Host "Do you want to stage, commit, and push these changes? (y/n)"
            if ($fix -eq "y") {
                git add .
                $msg = Read-Host "Enter commit message"
                git commit -m "$msg"
                git push
                Write-Host "✅ Changes committed and pushed." -ForegroundColor Green
                $repoStatus.Status = "Had uncommitted changes (fixed)"
            } else {
                $repoStatus.Status = "Uncommitted changes (skipped)"
            }
        }
    } else {
        Write-Host "✅ No uncommitted changes." -ForegroundColor Green
    }

    # Step 3: Check for unpushed commits
    $unpushed = git cherry -v 2>$null
    if ($unpushed) {
        Write-Host "⚠️  Unpushed commits detected:" -ForegroundColor Red
        Write-Host $unpushed

        if ($AutoFix) {
            Write-Host "🧠 AutoFix mode: pushing commits..." -ForegroundColor Cyan
            git push | Out-Null
            Write-Host "✅ Commits pushed automatically." -ForegroundColor Green
            if ($repoStatus.Status -eq "") { $repoStatus.Status = "Had unpushed commits (auto-fixed)" }
        } else {
            $push = Read-Host "Do you want to push these commits now? (y/n)"
            if ($push -eq "y") {
                git push
                Write-Host "✅ Commits pushed." -ForegroundColor Green
                if ($repoStatus.Status -eq "") { $repoStatus.Status = "Had unpushed commits (fixed)" }
            } else {
                if ($repoStatus.Status -eq "") { $repoStatus.Status = "Unpushed commits (skipped)" }
            }
        }
    } elseif ($repoStatus.Status -eq "") {
        $repoStatus.Status = "Clean"
        Write-Host "✅ All commits are pushed." -ForegroundColor Green
    }

    $summary += $repoStatus
}

# Add non-Git folders to summary
foreach ($folder in $nonGitFolders) {
    $summary += [PSCustomObject]@{
        Repository = $folder.FullName
        Status     = "Not a Git repository"
    }
}

# Restore original location
Set-Location $originalLocation

# Step 4: Display summary
Write-Host "`n📊 Summary of all folders:" -ForegroundColor Cyan
$summary | Sort-Object Status | Format-Table -AutoSize

Write-Host "`n✅ All repositories checked." -ForegroundColor Green
