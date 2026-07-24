@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

REM ============================================================
REM  MX Support Daily Report - Scheduled Task Script (CMD)
REM
REM  All paths are relative to this script's location.
REM  Account-specific IDs are read from config.json.
REM
REM  Note: This CMD version runs the pipeline only (no DingTalk
REM  notification). For full features including notifications,
REM  use run_scheduled.ps1 instead.
REM ============================================================

REM ── Path resolution (portable) ──
set "ROOT_DIR=%~dp0"
set "SCRIPT_DIR=%ROOT_DIR%scripts"
set "CONFIG_FILE=%ROOT_DIR%config.json"
set "LOG_DIR=%ROOT_DIR%logs"

REM Create logs directory
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM ── Auto-detect Python ──
set "PYTHON_EXE="

where py >nul 2>&1
if %ERRORLEVEL%==0 (
    set "PYTHON_EXE=py -3"
    goto :found_python
)

where python >nul 2>&1
if %ERRORLEVEL%==0 (
    set "PYTHON_EXE=python"
    goto :found_python
)

for %%P in (
    "%LOCALAPPDATA%\Programs\Python\Python314\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
) do (
    if exist %%P (
        set "PYTHON_EXE=%%P"
        goto :found_python
    )
)

echo [ERROR] Python not found. Please install Python 3.10+ and add it to PATH.
exit /b 1

:found_python
echo [OK] Python: %PYTHON_EXE%

REM ── Check config.json ──
if not exist "%CONFIG_FILE%" (
    echo [ERROR] config.json not found at %CONFIG_FILE%
    echo         Copy config.example.json to config.json and fill in your values.
    exit /b 1
)

REM ── Log file ──
for /f "tokens=2 delims==" %%I in ('powershell -Command "Get-Date -Format ''yyyy-MM-dd''"') do set "LOGDATE=%%I"
set "LOGFILE=%LOG_DIR%\scheduled_%LOGDATE%.log"

echo ============================================================ >> "%LOGFILE%"
echo [%date% %time%] Scheduled task started >> "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"

REM ── Step 1: Run the daily pipeline ──
echo [%date% %time%] Running daily pipeline... >> "%LOGFILE%"
cd /d "%ROOT_DIR%"
%PYTHON_EXE% "%SCRIPT_DIR%\run_daily_pipeline.py" >> "%LOGFILE%" 2>&1
set "PIPELINE_EXIT=%ERRORLEVEL%"

if %PIPELINE_EXIT% equ 0 (
    echo [%date% %time%] Pipeline completed successfully >> "%LOGFILE%"
    set "STATUS=SUCCESS"
) else (
    echo [%date% %time%] Pipeline failed with exit code %PIPELINE_EXIT% >> "%LOGFILE%"
    set "STATUS=FAILED"
)

echo [%date% %time%] Status: %STATUS% >> "%LOGFILE%"
echo [%date% %time%] Scheduled task completed >> "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"

REM Note: DingTalk notification (text + Excel file) is only supported
REM in run_scheduled.ps1. This CMD version runs the pipeline only.

exit /b 0
