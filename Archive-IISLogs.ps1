<#
.SYNOPSIS
    Archives the previous month's IIS log files into a zip per W3SVC site folder.

.DESCRIPTION
    Scans each W3SVCxx subfolder under the IIS LogFiles directory, finds .log files
    whose filename-embedded date falls in the previous calendar month, compresses them
    into a single zip, and removes the originals after successful archival.

    IIS log filenames follow the pattern: u_exYYMMDD.log (or u_exYYMMDDHH.log for hourly).

.PARAMETER LogRoot
    Root path containing W3SVCxx folders. Defaults to C:\inetpub\logs\LogFiles.

.PARAMETER WhatIf
    Show what would be done without making changes.

.EXAMPLE
    .\Archive-IISLogs.ps1
    Archives last month's logs using default path.

.EXAMPLE
    .\Archive-IISLogs.ps1 -LogRoot "D:\IISLogs\LogFiles"
    Archives last month's logs from a custom path.

.EXAMPLE
    .\Archive-IISLogs.ps1 -WhatIf
    Preview what would be archived without making changes.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$LogRoot = "C:\inetpub\logs\LogFiles"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Calculate previous month's year and month
$previousMonth = (Get-Date).AddMonths(-1)
$year  = $previousMonth.ToString("yy")   # 2-digit for filename matching
$month = $previousMonth.ToString("MM")
$archiveLabel = $previousMonth.ToString("yyyy-MM")  # e.g. 2026-03

Write-Host "Archiving IIS logs for: $archiveLabel"
Write-Host "Log root: $LogRoot"
Write-Host ""

if (-not (Test-Path $LogRoot)) {
    Write-Error "Log root path does not exist: $LogRoot"
    return
}

# Find all W3SVCxx site folders
$siteFolders = Get-ChildItem -Path $LogRoot -Directory -Filter "W3SVC*"

if ($siteFolders.Count -eq 0) {
    Write-Host "No W3SVC* folders found under $LogRoot"
    return
}

foreach ($siteFolder in $siteFolders) {
    Write-Host "--- $($siteFolder.Name) ---"

    # Match IIS log files for the previous month.
    # Standard naming: u_exYYMMDD.log  (daily rotation)
    # Hourly naming:   u_exYYMMDDHH.log
    # The key part is YYMM after "u_ex".
    $pattern = "u_ex${year}${month}*.log"
    $logFiles = Get-ChildItem -Path $siteFolder.FullName -Filter $pattern -File

    if ($logFiles.Count -eq 0) {
        Write-Host "  No log files matching $pattern"
        continue
    }

    $totalSize = ($logFiles | Measure-Object -Property Length -Sum).Sum
    $totalSizeMB = [math]::Round($totalSize / 1MB, 2)
    Write-Host "  Found $($logFiles.Count) log file(s) ($totalSizeMB MB)"

    $zipName = "$($siteFolder.Name)_${archiveLabel}.zip"
    $zipPath = Join-Path $siteFolder.FullName $zipName

    if (Test-Path $zipPath) {
        Write-Warning "  Archive already exists: $zipPath — skipping"
        continue
    }

    if ($PSCmdlet.ShouldProcess("$($logFiles.Count) files in $($siteFolder.Name)", "Compress to $zipName")) {
        try {
            Compress-Archive -Path $logFiles.FullName -DestinationPath $zipPath -CompressionLevel Optimal

            # Verify the zip was created and is non-empty
            $zipInfo = Get-Item $zipPath
            if ($zipInfo.Length -eq 0) {
                Write-Error "  Created zip is empty — not deleting originals"
                continue
            }

            $zipSizeMB = [math]::Round($zipInfo.Length / 1MB, 2)
            Write-Host "  Created: $zipName ($zipSizeMB MB)"

            # Remove the original log files
            $logFiles | Remove-Item -Force
            Write-Host "  Removed $($logFiles.Count) original log file(s)"
        }
        catch {
            Write-Error "  Failed to archive $($siteFolder.Name): $_"
            # Clean up partial zip if it exists
            if (Test-Path $zipPath) {
                Remove-Item $zipPath -Force
            }
        }
    }
}

Write-Host ""
Write-Host "Done."
