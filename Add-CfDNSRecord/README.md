# Cloudflare Records Adder (PowerShell)

A PowerShell tool to automatically **check, update, and back up Cloudflare (A, CNAME and TXT) DNS records**.  

Vibe-coded with the help of ChatGPT (OpenAI), during a stormy, inspirational summer evening of 2025.

## ✨ Features

- 🔑 Auto-fetch Zone ID from root domain (no manual lookup needed)
- ⚡ Add or update DNS records (A, AAAA, CNAME, TXT)
- 💾 Backup DNS records **before and after** changes (JSON + CSV)
- 🔍 Diff report showing added, updated, or removed records
- 🎛️ Interactive mode (prompts) or fully automated with parameters

## 🛠 Requirements

- PowerShell 7+  
- Cloudflare API Token with **Zone:Read** and **DNS:Edit** permissions  

## 🚀 Usage

```powershell
.\Add-CfDNSRecord.ps1

# or

.\Add-CfDNSRecord.ps1 `
  -ApiToken "your-api-token" `
  -RootDomain "example.com" `
  -SubDomain "test" `
  -RecordType "A" `
  -RecordValue "203.0.113.10" `
  -TTL 120 `
  -Proxied `
  -BackupPath "C:\Backups\Cloudflare"

# Found Zone ID: abc123xyz
# 💾 Backup saved: C:\Backups\Cloudflare\example.com-before-20250817-143355.json, .csv

# Current DNS records:
# example.com             A      192.0.2.10
# www.example.com         CNAME  example.com
# api.example.com         A      198.51.100.5

# Updating record: test.example.com
# ✅ Record updated.
# 💾 Backup saved: C:\Backups\Cloudflare\example.com-after-20250817-143355.json, .csv

# ===== DNS Changes Detected =====
# ✏️ Updated: test.example.com [A]
#     Old → 192.0.2.20 (Proxied: False)
#     New → 203.0.113.10 (Proxied: True)

# ✅ Completed. Backups + diff saved to C:\Backups\Cloudflare
```

## ✍️ Authors
🧑‍💻 Tomica Kaniski  
🤖 ChatGPT (OpenAI)

## 📜 License
This project is licensed under the [WTFPL License](http://www.wtfpl.net) – feel free to use, modify, and share.  
<center><a href="http://www.wtfpl.net/"><img src="http://www.wtfpl.net/wp-content/uploads/2012/12/wtfpl-badge-4.png" width="80" height="15" alt="WTFPL" /></a></center>