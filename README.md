# iis-log-autozipper

PowerShell script that archives the previous month's IIS log files into a zip per site folder, then removes the originals.

## How it works

1. Scans each `W3SVC*` subfolder under the IIS log root directory.
2. Matches `.log` files whose filename-embedded date (`u_exYYMMDD.log` / `u_exYYMMDDHH.log`) falls in the previous calendar month.
3. Compresses them into a single zip named `<SiteFolder>_<YYYY-MM>.zip` (e.g. `W3SVC1_2026-03.zip`).
4. Removes the original log files after verifying the archive was created successfully.

## Usage

```powershell
# Archive last month's logs (default path C:\inetpub\logs\LogFiles)
.\Archive-IISLogs.ps1

# Custom log root
.\Archive-IISLogs.ps1 -LogRoot "D:\IISLogs\LogFiles"

# Dry run — preview what would be archived without making changes
.\Archive-IISLogs.ps1 -WhatIf
```

## Parameters

| Parameter  | Default                        | Description                                      |
|------------|--------------------------------|--------------------------------------------------|
| `-LogRoot` | `C:\inetpub\logs\LogFiles`     | Root path containing `W3SVC*` site folders.       |
| `-WhatIf`  | —                              | Show what would be done without making changes.   |

## Scheduling

To run automatically on the 1st of each month, create a Windows Task Scheduler task:

```
Action:   PowerShell.exe
Arguments: -ExecutionPolicy Bypass -File "C:\path\to\Archive-IISLogs.ps1"
Trigger:  Monthly, day 1, at a low-traffic time (e.g. 03:00)
Run as:   An account with read/write access to the IIS log folders
```

## Safety

- Skips a site folder if the archive zip already exists for that month.
- Verifies the zip is non-empty before deleting originals.
- Cleans up partial zip files on failure.
- Use `-WhatIf` to preview before committing.
