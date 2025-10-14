# Git Checker (PowerShell)

A PowerShell utility script to quickly audit multiple local Git
repositories, verify commit/push status, and optionally auto-fix
uncommitted or unpushed changes.

## 🚀 Features

-   Scans a base directory for Git repositories (default: first-level
    only)
-   Optionally **recursive** (`-Recurse`) for deep scanning
-   Pulls latest changes (`git pull`) before checking
-   Detects:
    -   Uncommitted changes
    -   Unpushed commits
    -   Non-Git folders
-   Interactive mode by default (asks before committing/pushing)
-   Optional **AutoFix mode** (`-AutoFix`) to commit and push
    automatically
-   Clear summary table of all results

## ⚙️ Usage

### Basic Scan (first-level only)

``` powershell
.\Check-GitRepos.ps1
```

### Include All Subfolders (recursive)

``` powershell
.\Check-GitRepos.ps1 -Recurse
```

### Auto-Fix Mode (no prompts)

``` powershell
.\Check-GitRepos.ps1 -AutoFix
```

### Full Recursive + Auto-Fix

``` powershell
.\Check-GitRepos.ps1 -Recurse -AutoFix
```

## 📋 Example Output

| Repository | Status |
| -------- | ------- |
| `C:\Projects\App1` | Clean |
| `C:\Projects\App2` | Had uncommitted changes (auto-fixed) |
| `C:\Projects\Docs` | Not a Git repository |
| `C:\Projects\Temp` | Pull failed |

## 🧠 Notes

-   Always pulls (`git pull`) before checking.
-   If a pull fails (e.g., conflicts), the script continues safely.
-   Summary at the end shows every folder scanned and its state.
-   Automatically returns to your original directory when finished.

## 🧩 Parameters

  Parameter    Description
  ------------ --------------------------------------------------------
  `BasePath`   The root directory to scan (default: current path `.`)
  `AutoFix`    Automatically stage, commit, and push changes
  `Recurse`    Recursively scan all subfolders

## 🧰 Requirements

-   PowerShell 5+ (or PowerShell Core)
-   Git must be installed and available in the system PATH.

## ✍️ Authors

🧑‍💻 Tomica Kaniski  
🤖 ChatGPT (OpenAI)

## 📜 License

This project is licensed under the [WTFPL License](http://www.wtfpl.net) – feel free to use, modify, and share.

<p align="center">
  <a href="https://www.wtfpl.net/">
    <img src="https://www.wtfpl.net/wp-content/uploads/2012/12/wtfpl-badge-4.png" width="80" height="15" alt="WTFPL" />
  </a>
</p>
