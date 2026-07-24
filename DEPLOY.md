# New Machine Deployment Guide

This guide walks you through setting up the MX Support Daily Report tool on a completely new Windows machine. No hardcoded paths or secrets are stored in the repository — everything is configured locally after cloning.

## Prerequisites

Before starting, ensure the following are installed on the new machine:

- **Python 3.10 or later** (3.12+ recommended). Download from [python.org](https://www.python.org/downloads/). During installation, check "Add Python to PATH".
- **Git** (optional, for cloning the repo). Download from [git-scm.com](https://git-scm.com/download/win).
- **PowerShell 5.1+** (pre-installed on all modern Windows versions).

## Step 1: Get the Repository

Clone from GitHub or copy the folder manually:

```bash
# Option A: Clone from GitHub
git clone https://github.com/Lo77eyy/mx-support-daily-report.git
cd mx-support-daily-report

# Option B: Copy the folder
# Simply copy the entire project folder to the desired location, e.g. C:\Tools\mx-support-daily-report
```

The tool uses relative paths internally (`$PSScriptRoot` in PowerShell, `%~dp0` in CMD, `Path(__file__)` in Python), so it works from any directory.

## Step 2: Run the Setup Script

The setup script will check your Python installation, install required Python packages (`requests`, `openpyxl`), and download the `dws` CLI tool into the `bin/` folder.

```bash
# Windows
setup.bat

# Or from Git Bash / WSL
bash setup.sh
```

To verify everything is installed correctly without making changes:

```bash
setup.bat --check
```

## Step 3: Create Your Configuration File

The repository includes a template file `config.example.json`. Copy it to `config.json` and fill in your environment-specific values:

```bash
copy config.example.json config.json
```

Then edit `config.json` with a text editor. Below is what each field means:

```json
{
    "freshdesk": {
        "domain": "your-company.freshdesk.com",
        "group_id": 1234567890
    },
    "dingtalk": {
        "aitable_base_id": "your-ai-table-base-id",
        "aitable_table_id": "your-data-table-id",
        "notify_user_id": "dingtalk-user-id-to-notify",
        "notify_open_dingtalk_id": "open-dingtalk-id-for-file-messages",
        "field_map": {
            "Agent Name": "field-id-for-agent-name",
            "Data Retrieval Date": "field-id-for-date",
            "Needs Follow Up": "field-id-for-follow-up",
            "Tickets Under Name": "field-id-for-tickets",
            "Tickets Escalated": "field-id-for-escalated"
        },
        "formula_field_ids": []
    }
}
```

**Where to find these values:**

- `freshdesk.domain` — Your Freshdesk subdomain (e.g., `glinetservice.freshdesk.com`).
- `freshdesk.group_id` — The numeric ID of the Freshdesk group to monitor. Find it in Freshdesk Admin > Groups.
- `dingtalk.aitable_base_id` and `aitable_table_id` — Open your AI table in DingTalk; the IDs are in the URL: `https://alidocs.dingtalk.com/i/nodes/<base_id>?iframeQuery=...&tableId=<table_id>`.
- `dingtalk.notify_user_id` — The DingTalk userId of the person to receive notifications.
- `dingtalk.notify_open_dingtalk_id` — The openDingTalkId for sending file messages (needed for Excel delivery).
- `dingtalk.field_map` — Maps report column names to AI table field IDs. Get these from the AI table's field settings.

**Note:** `config.json` is listed in `.gitignore` and will never be committed to the repository. Your configuration stays local.

## Step 4: Set the Freshdesk API Key

The Freshdesk API key is a secret and must be set as an environment variable — it is never stored in any file.

```bash
# Temporary (current session only)
set FRESHDESK_API_KEY=your_api_key_here

# Permanent (user-level environment variable)
setx FRESHDESK_API_KEY your_api_key_here
```

The domain can also be set as an environment variable to override `config.json`:

```bash
setx FRESHDESK_DOMAIN your-company.freshdesk.com
```

> **Important:** If you use `setx`, restart your terminal or PowerShell for the change to take effect.

## Step 5: Test the Pipeline

Run the full pipeline manually to verify everything works:

```bash
# Using Python (recommended)
python scripts/run_daily_pipeline.py

# Or using the batch file
scripts\run_daily_pipeline.bat
```

This will:
1. Fetch ticket data from Freshdesk
2. Generate an Excel report (`MX_Support_Daily_Report.xlsx`)
3. Sync the data to your DingTalk AI table

If any step fails, check the error message. Common issues:

- `Config file not found` — You forgot to copy `config.example.json` to `config.json`.
- `FRESHDESK_API_KEY not set` — Set the environment variable as described in Step 4.
- `dws: command not found` — Run `setup.bat` again to download the dws CLI.

## Step 6: Register the Scheduled Task (Optional)

To run the report automatically every day, register a Windows scheduled task:

```powershell
# Morning report at 08:00 local time
powershell -ExecutionPolicy Bypass -File register_morning_task.ps1

# Or evening report at 23:00 local time
powershell -ExecutionPolicy Bypass -File register_task.ps1
```

The scheduled task will:
1. Check DingTalk authentication status
2. Run the full pipeline (Freshdesk → Excel → AI table)
3. Send a summary notification to the configured DingTalk user
4. Upload and send the Excel file via DingTalk

To manage the task later, open Windows Task Scheduler and look for "MX Support Morning Report" or "MX Support Evening Report".

## Step 7: DingTalk Authentication

The `dws` CLI needs to be authenticated with DingTalk. On first run, you'll be prompted to log in via a browser:

```bash
bin\dws.exe auth login
```

After logging in, the auth token is stored locally. Note that this token expires periodically. If scheduled tasks start failing with authentication errors, re-run `dws auth login` to refresh.

> **Note on delete permissions:** The AI table sync uses "delete records" which is a medium-risk DingTalk permission. The first time you run it, a browser window will open asking you to authorize. Choose "permanent" (永久) authorization to avoid being prompted every time — this is important for unattended scheduled tasks.

## Summary of Files You Need to Create

| File | Purpose | Created By |
|------|---------|-----------|
| `config.json` | Your environment-specific configuration | You (copy from `config.example.json`) |
| `FRESHDESK_API_KEY` env var | Freshdesk API secret | You (via `setx`) |
| `bin/dws.exe` | DingTalk workspace CLI | `setup.bat` |

## What's NOT in the Repository

The following are intentionally excluded (via `.gitignore` or by design):

- `config.json` — Contains your environment-specific IDs and settings
- `FRESHDESK_API_KEY` — Secret, set as environment variable only
- `bin/` — Downloaded by setup script
- `logs/` — Generated at runtime
- `*.xlsx`, `*.json` data files — Generated by the pipeline

## Troubleshooting

**Python not found:** The scripts auto-detect Python via `py -3`, then `python` in PATH, then known installation directories. If none work, ensure Python is installed and optionally add it to your PATH.

**Scheduled task runs but doesn't send notifications:** Check that `notify_user_id` and `notify_open_dingtalk_id` are set in `config.json`. Also verify DingTalk auth with `bin\dws.exe auth status --format json`.

**Pipeline succeeds but AI table is empty:** Verify `aitable_base_id` and `aitable_table_id` in `config.json` are correct. Run with `--verbose` for detailed logs: `python scripts/sync_to_dingtalk_aitable.py --verbose`.

**dws auth token expired:** Run `bin\dws.exe auth login` again. If running as a scheduled task, you may need to run it once interactively in a visible window to complete the browser authorization.
