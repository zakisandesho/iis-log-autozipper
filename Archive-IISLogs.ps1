<#
.SYNOPSIS
    Archives old IIS log files into a zip per site folder per month.

.DESCRIPTION
    Scans each W3SVCxx subfolder under the IIS LogFiles directory, finds .log files
    whose filename-embedded date is older than the current month, compresses each
    month into a separate zip, and removes the originals after successful archival.

    IIS log filenames follow the pattern: u_exYYMMDD.log (or u_exYYMMDDHH.log for hourly).

.PARAMETER LogRoot
    Root path containing W3SVCxx folders. Defaults to C:\inetpub\logs\LogFiles.

.PARAMETER WhatIf
    Show what would be done without making changes.

.EXAMPLE
    .\Archive-IISLogs.ps1
    Archives all old logs using default path.

.EXAMPLE
    .\Archive-IISLogs.ps1 -LogRoot "D:\IISLogs\LogFiles"
    Archives all old logs from a custom path.

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

# Start transcript log next to the script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$logFile = Join-Path $scriptDir "Archive-IISLogs_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').log"
if (-not $WhatIfPreference) {
    Start-Transcript -Path $logFile
}

# Current year-month threshold — only archive months before this
$currentYYMM = (Get-Date).ToString("yyMM")

Write-Host "Archiving IIS logs older than current month ($((Get-Date).ToString('yyyy-MM')))"
Write-Host "Log root: $LogRoot"
Write-Host ""

if (-not (Test-Path $LogRoot)) {
    Write-Error "Log root path does not exist: $LogRoot"
    return
}

# Find all W3SVCxx site folders
$siteFolders = @(Get-ChildItem -Path $LogRoot -Directory -Filter "W3SVC*")

if ($siteFolders.Count -eq 0) {
    Write-Host "No W3SVC* folders found under $LogRoot"
    return
}

$totalOriginalSize = [long]0
$totalZipSize = [long]0
$totalFilesArchived = 0

foreach ($siteFolder in $siteFolders) {
    Write-Host "--- $($siteFolder.Name) ---"

    # Find all IIS log files (u_exYYMMDD.log or u_exYYMMDDHH.log)
    $allLogFiles = @(Get-ChildItem -Path $siteFolder.FullName -Filter "u_ex*.log" -File)

    if ($allLogFiles.Count -eq 0) {
        Write-Host "  No log files found"
        continue
    }

    # Extract YYMM from filenames, keep only months older than current
    $months = @($allLogFiles |
        Where-Object { $_.Name -match '^u_ex(\d{4})' } |
        ForEach-Object { $Matches[1] } |
        Where-Object { $_ -lt $currentYYMM } |
        Sort-Object -Unique)

    if ($months.Count -eq 0) {
        Write-Host "  No old log files to archive"
        continue
    }

    foreach ($yymm in $months) {
        $yy = $yymm.Substring(0, 2)
        $mm = $yymm.Substring(2, 2)
        $archiveLabel = "20${yy}-${mm}"

        $pattern = "u_ex${yymm}*.log"
        $logFiles = @(Get-ChildItem -Path $siteFolder.FullName -Filter $pattern -File)

        $totalSize = ($logFiles | Measure-Object -Property Length -Sum).Sum
        $totalSizeMB = [math]::Round($totalSize / 1MB, 2)
        Write-Host "  [$archiveLabel] Found $($logFiles.Count) log file(s) ($totalSizeMB MB)"

        $zipName = "$($siteFolder.Name)_${archiveLabel}.zip"
        $zipPath = Join-Path $siteFolder.FullName $zipName

        if (Test-Path $zipPath) {
            Write-Warning "  [$archiveLabel] Archive already exists - skipping"
            continue
        }

        if ($PSCmdlet.ShouldProcess("$($logFiles.Count) files in $($siteFolder.Name) for $archiveLabel", "Compress to $zipName")) {
            try {
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                $zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
                foreach ($f in $logFiles) {
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                        $zip, $f.FullName, $f.Name,
                        [System.IO.Compression.CompressionLevel]::Optimal
                    ) | Out-Null
                }
                $zip.Dispose()

                # Verify the zip was created and is non-empty
                $zipInfo = Get-Item $zipPath
                if ($zipInfo.Length -eq 0) {
                    Write-Error "  [$archiveLabel] Created zip is empty - not deleting originals"
                    continue
                }

                $zipSizeMB = [math]::Round($zipInfo.Length / 1MB, 2)
                Write-Host "  [$archiveLabel] Created: $zipName ($zipSizeMB MB)"

                $totalOriginalSize += $totalSize
                $totalZipSize += $zipInfo.Length
                $totalFilesArchived += $logFiles.Count

                # Remove the original log files
                $logFiles | Remove-Item -Force
                Write-Host "  [$archiveLabel] Removed $($logFiles.Count) original log file(s)"
            }
            catch {
                Write-Error "  [$archiveLabel] Failed to archive $($siteFolder.Name): $_"
                # Clean up partial zip if it exists
                if ($zip) { $zip.Dispose() }
                if (Test-Path $zipPath) {
                    Remove-Item $zipPath -Force
                }
            }
        }
    }
}

Write-Host ""
if ($totalFilesArchived -gt 0) {
    $origMB = [math]::Round($totalOriginalSize / 1MB, 2)
    $zipMB  = [math]::Round($totalZipSize / 1MB, 2)
    $savedMB = [math]::Round(($totalOriginalSize - $totalZipSize) / 1MB, 2)
    $ratio = [math]::Round(($totalOriginalSize - $totalZipSize) / $totalOriginalSize * 100, 1)
    Write-Host "=== Summary ==="
    Write-Host "  Files archived: $totalFilesArchived"
    Write-Host "  Original size:  $origMB MB"
    Write-Host "  Zip size:       $zipMB MB"
    Write-Host "  Space saved:    $savedMB MB ($ratio%)"
}
Write-Host "Done."

if (-not $WhatIfPreference) {
    Stop-Transcript
}
