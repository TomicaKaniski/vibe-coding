# Path to the Edge Managed Favorites policy
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
$regValueName = "ManagedFavorites"

# Output file
$workingFolder = "."
$outputFile = Join-Path $workingFolder "edge_managed_favorites_export.html"

# --- Load favorites JSON from registry ---
try {
    $rawJson = (Get-ItemProperty -Path $regPath -Name $regValueName -ErrorAction Stop).$regValueName
    Write-Host "[PASS] Loaded favorites JSON from registry." -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Could not read $regValueName from $regPath!" -ForegroundColor Red
    exit 1
}

# Parse JSON
$favorites = $rawJson | ConvertFrom-Json

# --- Helper: HTML escape ---
function ConvertTo-HtmlSafe {
    param([string]$text)
    if (-not $text) { return "" }
    return ($text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;')
}

# --- Base timestamp ---
$baseTimestamp = [int][double]::Parse((Get-Date -UFormat %s))
$itemCounter = 0  # global counter for deterministic timestamps

# --- Recursive converter ---
function Convert-FavoritesToHtml {
    param(
        $items,
        [int]$indentLevel = 0
    )

    $html = ""
    $indent = " " * ($indentLevel * 4)

    foreach ($item in $items) {
        $itemCounter++
        $timestamp = $baseTimestamp + $itemCounter

        # Top-level folder
        if ($item.toplevel_name) {
            $name = ConvertTo-HtmlSafe $item.toplevel_name
            $html += "$indent<DT><H3 ADD_DATE=`"$timestamp`" LAST_MODIFIED=`"$timestamp`">$name</H3>`n"
            $html += "$indent<DL><p>`n"

            # Render remaining items (links/folders)
            $remaining = $items | Where-Object { -not $_.toplevel_name }
            $html += Convert-FavoritesToHtml $remaining ($indentLevel + 1)

            $html += "$indent</DL><p>`n"
            break
        }

        # Subfolder with children
        elseif ($item.children) {
            $name = ConvertTo-HtmlSafe $item.name
            $html += "$indent<DT><H3 ADD_DATE=`"$timestamp`" LAST_MODIFIED=`"$timestamp`">$name</H3>`n"
            $html += "$indent<DL><p>`n"
            $html += Convert-FavoritesToHtml $item.children ($indentLevel + 1)
            $html += "$indent</DL><p>`n"
        }

        # Individual bookmark
        elseif ($item.url) {
            $url = $item.url  # <-- leave URL as-is, no escaping
            $name = ConvertTo-HtmlSafe $item.name  # <-- still escape the link text
            $html += "$indent<DT><A HREF=`"$url`" ADD_DATE=`"$timestamp`">$name</A>`n"
        }
    }

    return $html
}

# --- Generate inner HTML starting from indent level 2 ---
$innerHtml = (Convert-FavoritesToHtml $favorites 2).TrimEnd("`r", "`n")

# --- Build full HTML output ---
$htmlOutput = @"
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<!-- This is an automatically generated file.
     It will be read and overwritten.
     DO NOT EDIT! -->
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks</H1>
<DL><p>
    <DT><H3 ADD_DATE="$($baseTimestamp)" LAST_MODIFIED="$($baseTimestamp)" PERSONAL_TOOLBAR_FOLDER="true">Bookmarks bar</H3>
    <DL><p>
$innerHtml
    </DL><p>
</DL><p>
"@

# --- Write HTML to file ---
$htmlOutput | Set-Content -Path $outputFile -Encoding UTF8

Write-Host "[DONE] HTML bookmarks file created at: $outputFile." -ForegroundColor Cyan
