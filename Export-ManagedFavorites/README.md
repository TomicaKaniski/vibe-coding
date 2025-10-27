# Export Managed Favorites for Microsoft Edge

This PowerShell script exports the **Managed Favorites** configured via Group Policy in Microsoft Edge (from the registry) into a **standard HTML bookmarks file** compatible with browsers like Edge, Chrome, and Firefox.

The script preserves:

- Folder hierarchy
- Timestamps (`ADD_DATE` / `LAST_MODIFIED`)
- Bookmark names
- Bookmark URLs (unmodified)

## Script

**Filename:** `Export-ManagedFavorites.ps1`

## Features

- Reads managed favorites from the Windows registry (`HKLM:\SOFTWARE\Policies\Microsoft\Edge\ManagedFavorites`)
- Generates a properly formatted **Netscape Bookmark File** (`.html`)
- Adds timestamps to folders and links based on script run time
- Preserves link URLs exactly as in the registry (no unwanted HTML escaping)
- Indentation and line breaks compatible with browsers’ import functions
- Supports nested folders

## Requirements

- Windows PowerShell (tested on 5.1+)
- Microsoft Edge with Managed Favorites configured via Group Policy
- Read access to the registry path: `HKLM:\SOFTWARE\Policies\Microsoft\Edge`
- **No administrative privileges are required** to read the Managed Favorites registry key

## Usage

1. Download the script and save as `Export-ManagedFavorites.ps1`.
2. Open PowerShell.
3. Navigate to the folder where the script is saved:

```powershell
Set-Location "C:\Path\To\Script"
```

Run the script:
```powershell
.\Export-ManagedFavorites.ps1
```

The bookmarks HTML file will be generated in the same folder as the script:

```powershell
edge_managed_favorites_export.html
```

You can now import this file into Edge, Chrome, Firefox, or other browsers.

## Output Example
```html
<!-- edge_managed_favorites_export.html -->
<DL><p>
    <DT><H3 ADD_DATE="1761119308" LAST_MODIFIED="1761119364" PERSONAL_TOOLBAR_FOLDER="true">Bookmarks bar</H3>
    <DL><p>
        <DT><H3 ADD_DATE="1761119364" LAST_MODIFIED="1761119695">Sample Folder</H3>
        <DL><p>
            <DT><A HREF="https://example.com" ADD_DATE="1761119700">Example Link</A>
        </DL><p>
    </DL><p>
</DL><p>
```

## Notes

- Timestamps are generated based on the current time plus an incremental counter to ensure uniqueness.
- Bookmark URLs are not HTML-escaped, so special characters like & remain intact.
- Only the Managed Favorites from Edge Group Policy are exported.
- The script handles nested folders correctly.

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
