@echo off
chcp 65001 >nul
REM ============================================================
REM  MX Support Daily Report → 钉钉 AI 表格同步
REM  用于 Windows Task Scheduler 定时执行
REM
REM  配置说明：
REM    1. 打开 "任务计划程序" (Task Scheduler)
REM    2. 创建基本任务 → 设置触发器（每天定时）
REM    3. 操作选 "启动程序"
REM    4. 程序或脚本: 本文件的完整路径
REM    5. 或手动设置:
REM       程序: C:\Users\GL\AppData\Local\Programs\Python\Python314\python.exe
REM       参数: "C:\Users\GL\.qoderworkcn\workspace\mr2y9wr285i946sj\outputs\sync_to_dingtalk_aitable.py"
REM       起始于: C:\Users\GL\.qoderworkcn\workspace\mr2y9wr285i946sj\outputs
REM ============================================================

REM Python 路径（根据实际安装位置修改）
set PYTHON_EXE=C:\Users\GL\AppData\Local\Programs\Python\Python314\python.exe

REM 脚本路径
set SCRIPT_PATH=%~dp0sync_to_dingtalk_aitable.py

REM 工作目录（脚本所在文件夹）
cd /d "%~dp0"

REM 执行同步
echo [%date% %time%] 开始同步...
"%PYTHON_EXE%" "%SCRIPT_PATH%" %*

echo [%date% %time%] 同步结束，退出码: %ERRORLEVEL%
exit /b %ERRORLEVEL%
