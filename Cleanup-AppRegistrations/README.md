# Entra ID (Azure AD) App Registrations Cleanup (PowerShell)

A PowerShell tool to identify, report, and optionally delete **outdated or unused Entra ID/Azure AD application registrations**.  
It produces **JSON backups**, **HTML reports**, and supports **dry-run** and **forced deletion** modes.  
The tool also includes credential expiration checks and sign-in activity analysis.

---

## Features

- Scans all Entra ID/Azure AD applications.
- Identifies candidates for cleanup based on:
  - Age of the application (`CreatedBefore`)
  - Credential usage (`UnusedFor`) including:
    - Certificates
    - Client Secrets
    - Federated Identities
- Excludes applications from selected publishers (e.g., Microsoft).
- Reports credential status:
  - **Expiring soon**
  - **Expired**
  - **Valid**
- Tracks **last sign-in** activity (if Azure AD Premium logs are available).
- Produces:
  - **JSON backup** for safe pre-deletion storage (although, there is **soft-delete in Entra ID** as well).
  - **HTML report** with detailed tables and color-coded credential summaries.
- Console summary with counts:
  - Total apps scanned
  - Candidates for deletion
  - Sign-in logs availability
- Dry-run mode by default. Use `-Force` to perform deletion.

---

## Requirements

- **PowerShell 7+**
- **Microsoft Graph PowerShell SDK** modules:
  - `Microsoft.Graph.Applications`
  - `Microsoft.Graph.Identity.SignIns`
- Permissions:
  - `Application.Read.All`
  - `Application.ReadWrite.All`
  - `AuditLog.Read.All` (optional)
- Optional: Azure AD Premium to fetch historical sign-in logs.

---

## Usage

```powershell
# Dry-run (default)
.\Cleanup-AppRegistrations.ps1

# Dry-run with custom thresholds
.\Cleanup-AppRegistrations.ps1 -UnusedFor 90 -CreatedBefore 365

# Include excluded publishers
.\Cleanup-AppRegistrations.ps1 -ExcludePublisher "Contoso","ExampleCorp"

# Force deletion
.\Cleanup-AppRegistrations.ps1 -Force

# Specify output folder and open HTML report automatically
.\Cleanup-AppRegistrations.ps1 -OutputPath "reports" -OpenReport
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-UnusedFor` | int | 90 | Number of days an app must be unused to be considered for deletion. |
| `-CreatedBefore` | int | 365 | Minimum age of the app in days to be considered. |
| `-ExcludePublisher` | string[] | Microsoft, Microsoft Corporation | List of publishers to exclude from deletion. |
| `-Force` | switch | (none) | Perform deletion. Default is dry-run. |
| `-OutputPath` | string | output | Folder to store JSON backup and HTML report. |
| `-OpenReport` | switch | (none) | Opens HTML report automatically after generation. |

## Output

**JSON Backup:** Pre-deletion copy of applications, credentials, and federated identities.

**HTML Report:** Detailed table including:
- Application name, AppId, ObjectId, Publisher
- Creation date, age
- Last sign-in date & status
- Credential summaries:
  - Certificates
  - Client Secrets
  - Federated Identities
- Color-coded credential statistics

**Console Summary Example:**
```
=== Cleanup Summary ===
Total apps scanned       : 109
Candidates for deletion  : 5
Sign-in logs unavailable : 20
========================
```

**Credential Summary Example in HTML Report:**
```
Certs: 1 expired, 0 expiring soon, 2 valid
Secrets: 0 expired, 1 expiring soon, 3 valid
Federated identities: 2
```

## Notes

- If sign-in logs are unavailable (due to missing premium license or retention window), the tool falls back to credential-only checks.
- The tool is safe by default; always review the HTML/JSON report before using `-Force`.

## Authors
🧑‍💻 Tomica Kaniski  
🤖 ChatGPT (OpenAI)


## License
This project is licensed under the [WTFPL License](http://www.wtfpl.net) – feel free to use, modify, and share.  


<p align="center">
  <a href="https://www.wtfpl.net/">
    <img src="https://www.wtfpl.net/wp-content/uploads/2012/12/wtfpl-badge-4.png" width="80" height="15" alt="WTFPL" />
  </a>
</p>
