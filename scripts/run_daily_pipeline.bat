@echo off
chcp 65001 >nul
REM ============================================================
REM  MX Support Daily Report — 每日全流程 Pipeline
REM  1. Freshdesk 拉取数据 → 2. 生成 Excel → 3. 同步钉钉 AI 表格
REM
REM  用于 Windows Task Scheduler 定时执行
REM
REM  配置说明：
REM    1. 打开 "任务计划程序" (Task Scheduler)
REM    2. 创建基本任务 → 设置触发器（每天定时，建议墨西哥时间 20:00 后）
REM    3. 操作选 "启动程序"
REM    4. 程序或脚本: 本文件的完整路径
REM    5. 确保环境变量已设置:
REM       FRESHDESK_API_KEY  — Freshdesk API 密钥
REM       FRESHDESK_DOMAIN   — Freshdesk 域名
REM ============================================================

REM ── 智能查找 Python ──
set PYTHON_EXE=

REM 方式 1: Python Launcher for Windows (py)
where py >nul 2>&1
if %ERRORLEVEL%==0 (
    set PYTHON_EXE=py -3
    goto :found_python
)

REM 方式 2: PATH 中的 python
where python >nul 2>&1
if %ERRORLEVEL%==0 (
    set PYTHON_EXE=python
    goto :found_python
)

REM 方式 3: 常见安装路径
for %%P in (
    "%LOCALAPPDATA%\Programs\Python\Python314\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
) do (
    if exist %%P (
        set PYTHON_EXE=%%P
        goto :found_python
    )
)

echo [ERROR] 未找到 Python，请安装 Python 3.10+ 或将其加入 PATH
exit /b 1

:found_python
echo [INFO] 使用 Python: %PYTHON_EXE%

REM ── 工作目录（脚本所在文件夹）──
cd /d "%~dp0"

REM ── 参数透传 ──
REM 支持 --skip-sync (跳过钉钉同步) 和 --date YYYY-MM-DD
set PIPELINE_ARGS=%*

echo.
echo ============================================================
echo  MX Support Daily Report Pipeline
echo  [%date% %time%] 启动
echo ============================================================
echo.

REM ── Step 1: 拉取 Freshdesk 数据 ──
echo [Step 1/3] 拉取 Freshdesk 数据...
%PYTHON_EXE% "%~dp0mx_daily_report.py" %PIPELINE_ARGS%
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Freshdesk 数据拉取失败 (exit code: %ERRORLEVEL%)
    exit /b %ERRORLEVEL%
)
echo.

REM ── Step 2: 生成 Excel ──
echo [Step 2/3] 生成 Excel 报告...
%PYTHON_EXE% "%~dp0create_daily_excel.py"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Excel 生成失败 (exit code: %ERRORLEVEL%)
    exit /b %ERRORLEVEL%
)
echo.

REM ── Step 3: 同步到钉钉 AI 表格 ──
echo [Step 3/3] 同步到钉钉 AI 表格...
%PYTHON_EXE% "%~dp0sync_to_dingtalk_aitable.py" %PIPELINE_ARGS%
if %ERRORLEVEL% neq 0 (
    echo [ERROR] 钉钉同步失败 (exit code: %ERRORLEVEL%)
    exit /b %ERRORLEVEL%
)

echo.
echo ============================================================
echo  Pipeline 完成! [%date% %time%]
echo ============================================================
exit /b 0
