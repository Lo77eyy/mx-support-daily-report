@echo off
chcp 65001 >nul
REM ============================================================
REM  MX Support Daily Report → 钉钉 AI 表格同步（单独运行）
REM  用于 Windows Task Scheduler 定时执行
REM
REM  配置说明：
REM    1. 打开 "任务计划程序" (Task Scheduler)
REM    2. 创建基本任务 → 设置触发器（每天定时）
REM    3. 操作选 "启动程序" → 本文件的完整路径
REM ============================================================

REM ── 智能查找 Python ──
set PYTHON_EXE=

where py >nul 2>&1
if %ERRORLEVEL%==0 (
    set PYTHON_EXE=py -3
    goto :found_python
)

where python >nul 2>&1
if %ERRORLEVEL%==0 (
    set PYTHON_EXE=python
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
        set PYTHON_EXE=%%P
        goto :found_python
    )
)

echo [ERROR] 未找到 Python，请安装 Python 3.10+ 或将其加入 PATH
exit /b 1

:found_python

REM 工作目录（脚本所在文件夹）
cd /d "%~dp0"

echo [%date% %time%] 开始同步...
%PYTHON_EXE% "%~dp0sync_to_dingtalk_aitable.py" %*

echo [%date% %time%] 同步结束，退出码: %ERRORLEVEL%
exit /b %ERRORLEVEL%
