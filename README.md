# iis-log-autozipper

PowerShell script that archives old IIS log files into a zip per site folder per month, then removes the originals. Targets all months older than the current one, so it catches any backlog automatically.

## How it works

1. Scans each `W3SVC*` subfolder under the IIS log root directory.
2. Finds all `.log` files matching the IIS naming pattern (`u_exYYMMDD.log` / `u_exYYMMDDHH.log`).
3. Groups them by month and filters out the current month (leaves active logs untouched).
4. Compresses each old month into its own zip named `<SiteFolder>_<YYYY-MM>.zip` (e.g. `W3SVC1_2026-01.zip`, `W3SVC1_2026-03.zip`).
5. Removes the original log files after verifying the archive was created successfully.
6. Writes a transcript log next to the script for each run.

## Usage

```powershell
# Archive all old logs (default path C:\inetpub\logs\LogFiles)
.\Archive-IISLogs.ps1

# Custom log root
.\Archive-IISLogs.ps1 -LogRoot "D:\IISLogs\LogFiles"

# Dry run - preview what would be archived without making changes
.\Archive-IISLogs.ps1 -WhatIf
```

## Parameters

| Parameter  | Default                        | Description                                      |
|------------|--------------------------------|--------------------------------------------------|
| `-LogRoot` | `C:\inetpub\logs\LogFiles`     | Root path containing `W3SVC*` site folders.       |
| `-WhatIf`  | -                              | Show what would be done without making changes.   |

## Scheduling

To run automatically on the 1st of each month, create a Windows Task Scheduler task:

```
Action:   PowerShell.exe
Arguments: -ExecutionPolicy Bypass -File "C:\path\to\Archive-IISLogs.ps1"
Trigger:  Monthly, day 1, at a low-traffic time (e.g. 03:00)
Run as:   An account with read/write access to the IIS log folders
```

## Safety

- Only archives months older than the current month - active logs are never touched.
- Skips if the archive zip already exists for that month.
- Verifies the zip is non-empty before deleting originals.
- Cleans up partial zip files on failure.
- Use `-WhatIf` to preview before committing.

## Logging

Each real run (non-WhatIf) writes a transcript log file next to the script: `Archive-IISLogs_<datetime>.log`. Includes a summary of total files archived, original vs. compressed size, and space saved.
