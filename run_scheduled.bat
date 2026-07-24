@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

REM ============================================================
REM  MX Support Daily Report - Scheduled Task Script
REM  Runs pipeline + sends DingTalk notification to Amiee
REM ============================================================

REM Configuration
set "PYTHON=C:\Users\GL\AppData\Local\Programs\Python\Python314\python.exe"
set "SCRIPT_DIR=C:\Users\GL\.qoderworkcn\workspace\mr2y9wr285i946sj\repo\mx-support-daily-report"
set "DWS=%SCRIPT_DIR%\bin\dws.exe"
set "LOG_DIR=%SCRIPT_DIR%\logs"
set "AMIEE_USER_ID=1778031662885144"

REM Create logs directory if not exists
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM Get current date for log filename
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set "DT=%%I"
set "LOGDATE=%DT:~0,4%-%DT:~4,2%-%DT:~6,2%"
set "LOGFILE=%LOG_DIR%\scheduled_%LOGDATE%.log"

echo ============================================================ >> "%LOGFILE%"
echo [%date% %time%] Scheduled task started >> "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"

REM Step 1: Run the daily pipeline
echo [%date% %time%] Running daily pipeline... >> "%LOGFILE%"
cd /d "%SCRIPT_DIR%"
"%PYTHON%" scripts/run_daily_pipeline.py >> "%LOGFILE%" 2>&1
set "PIPELINE_EXIT=%ERRORLEVEL%"

if %PIPELINE_EXIT% equ 0 (
    echo [%date% %time%] Pipeline completed successfully >> "%LOGFILE%"
    set "STATUS=SUCCESS"
) else (
    echo [%date% %time%] Pipeline failed with exit code %PIPELINE_EXIT% >> "%LOGFILE%"
    set "STATUS=FAILED"
)

REM Step 2: Read summary from JSON for the notification
set "TOTAL_TICKETS=0"
set "TOTAL_FOLLOWUP=0"
set "DATE_RANGE=N/A"
for /f "usebackq delims=" %%I in (`"%PYTHON%" -c "import json,sys; d=json.load(open('scripts/mx_daily_report_data.json','r',encoding='utf-8')); s=d.get('summary',{}); print(f\"{s.get('total_tickets',0)}|{s.get('total_follow_up',0)}|{s.get('date_range','N/A')}\")" 2^>nul`) do set "SUMMARY=%%I"
for /f "tokens=1,2,3 delims=|" %%a in ("!SUMMARY!") do (
    set "TOTAL_TICKETS=%%a"
    set "TOTAL_FOLLOWUP=%%b"
    set "DATE_RANGE=%%c"
)

REM Step 3: Send DingTalk notification to Amiee
echo [%date% %time%] Sending DingTalk notification to Amiee... >> "%LOGFILE%"

if "!STATUS!"=="SUCCESS" (
    set "MSG_TITLE=MX Support Daily Report - !DATE_RANGE!"
    set "MSG_TEXT=## MX Support Daily Report\n\n- Date: !DATE_RANGE!\n- Total Tickets: !TOTAL_TICKETS!\n- Needs Follow Up: !TOTAL_FOLLOWUP!\n- Status: !STATUS!\n\nLog: %LOGFILE%"
) else (
    set "MSG_TITLE=MX Support Daily Report - FAILED"
    set "MSG_TEXT=## MX Support Daily Report Failed\n\n- Date: !DATE_RANGE!\n- Status: FAILED (exit code: !PIPELINE_EXIT!)\n\nPlease check log: %LOGFILE%"
)

"%DWS%" chat message send --user "%AMIEE_USER_ID%" --title "!MSG_TITLE!" --text "!MSG_TEXT!" --format json --yes >> "%LOGFILE%" 2>&1

if %ERRORLEVEL% equ 0 (
    echo [%date% %time%] DingTalk notification sent to Amiee >> "%LOGFILE%"
) else (
    echo [%date% %time%] Failed to send DingTalk notification >> "%LOGFILE%"
)

echo [%date% %time%] Scheduled task completed >> "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"

exit /b 0
