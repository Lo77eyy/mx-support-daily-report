@echo off
chcp 65001 >nul
REM ============================================================
REM  MX Support Daily Report — 环境初始化脚本
REM
REM  功能：
REM    1. 下载 dws CLI（钉钉工作区命令行工具）
REM    2. 安装 Python 依赖（openpyxl, requests）
REM    3. 验证环境配置
REM
REM  用法：
REM    setup.bat              — 完整安装
REM    setup.bat --check      — 仅检查环境（不安装）
REM ============================================================

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR%..
set BIN_DIR=%PROJECT_DIR%\bin

echo ============================================================
echo  MX Support Daily Report — 环境初始化
echo ============================================================
echo.

REM ── 参数检查 ──
set CHECK_ONLY=0
if "%~1"=="--check" set CHECK_ONLY=1

REM ============================================================
REM  Step 1: 检查/安装 Python
REM ============================================================
echo [Step 1/3] 检查 Python 环境...

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

if %CHECK_ONLY%==1 (
    echo [WARN] 未找到 Python 3.10+
    goto :check_dws
)

echo [INFO] 未找到 Python，请安装 Python 3.10+
echo        下载地址: https://www.python.org/downloads/
echo        安装时请勾选 "Add Python to PATH"
exit /b 1

:found_python
echo [OK] Python: %PYTHON_EXE%

REM ============================================================
REM  Step 2: 安装 Python 依赖
REM ============================================================
if %CHECK_ONLY%==1 goto :check_dws

echo.
echo [Step 2/3] 安装 Python 依赖...
%PYTHON_EXE% -m pip install openpyxl requests --quiet 2>nul
if %ERRORLEVEL% neq 0 (
    echo [WARN] pip 安装失败，尝试使用 --user 模式...
    %PYTHON_EXE% -m pip install openpyxl requests --user --quiet
)
echo [OK] Python 依赖已安装 (openpyxl, requests)

REM ============================================================
REM  Step 3: 检查/下载 dws CLI
REM ============================================================
:check_dws
echo.
echo [Step 3/3] 检查 dws CLI...

REM 检查项目自带的 dws
if exist "%BIN_DIR%\dws.exe" (
    echo [OK] dws CLI 已存在: %BIN_DIR%\dws.exe
    goto :verify_dws
)

if %CHECK_ONLY%==1 (
    echo [WARN] dws CLI 未找到（%BIN_DIR%\dws.exe）
    goto :verify_env
)

REM 下载 dws
echo [INFO] 正在下载 dws CLI...

if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"

REM 使用 PowerShell 下载
set DWS_URL=https://github.com/DingTalk-Real-AI/dingtalk-workspace-cli/releases/latest/download/dws-windows-amd64.zip
set DWS_ZIP=%TEMP%\dws-windows-amd64.zip

echo [INFO] 从 %DWS_URL% 下载...
powershell -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%DWS_URL%' -OutFile '%DWS_ZIP%' -UseBasicParsing }"

if not exist "%DWS_ZIP%" (
    echo [ERROR] 下载失败，请手动下载:
    echo         https://github.com/DingTalk-Real-AI/dingtalk-workspace-cli/releases
    echo         将 dws.exe 放入: %BIN_DIR%\
    exit /b 1
)

REM 解压
echo [INFO] 解压 dws.exe...
powershell -Command "& { Expand-Archive -Path '%DWS_ZIP%' -DestinationPath '%BIN_DIR%' -Force }"

if exist "%BIN_DIR%\dws.exe" (
    echo [OK] dws CLI 已安装到: %BIN_DIR%\dws.exe
) else (
    echo [ERROR] 解压失败，请手动下载并放入: %BIN_DIR%\
)

REM 清理临时文件
del "%DWS_ZIP%" 2>nul

REM ============================================================
REM  验证环境
REM ============================================================
:verify_dws
:verify_env
echo.
echo ============================================================
echo  环境检查
echo ============================================================

REM 检查 Python
if defined PYTHON_EXE (
    echo [OK] Python: %PYTHON_EXE%
) else (
    echo [!!] Python: 未找到
)

REM 检查 dws
if exist "%BIN_DIR%\dws.exe" (
    echo [OK] dws CLI: %BIN_DIR%\dws.exe
    "%BIN_DIR%\dws.exe" --version 2>nul
) else (
    echo [!!] dws CLI: 未找到
)

REM 检查环境变量
echo.
if defined FRESHDESK_API_KEY (
    echo [OK] FRESHDESK_API_KEY: 已设置
) else (
    echo [!!] FRESHDESK_API_KEY: 未设置（拉取 Freshdesk 数据需要）
)

if defined FRESHDESK_DOMAIN (
    echo [OK] FRESHDESK_DOMAIN: %FRESHDESK_DOMAIN%
) else (
    echo [!!] FRESHDESK_DOMAIN: 未设置（拉取 Freshdesk 数据需要）
)

echo.
echo ============================================================
echo  设置说明
echo ============================================================
echo.
echo  环境变量（系统或用户级别）:
echo    setx FRESHDESK_API_KEY "你的API密钥"
echo    setx FRESHDESK_DOMAIN "glinetservice.freshdesk.com"
echo.
echo  钉钉授权（首次运行同步时需要在浏览器中授权）
echo.
echo ============================================================

endlocal
exit /b 0
