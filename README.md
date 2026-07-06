# MX Support Daily Report

Freshdesk MX Support 工单数据拉取 + Excel 报告生成 + 钉钉 AI 表格自动同步工具。

## 功能

本项目包含三个核心脚本，可单独运行也可通过 pipeline 一键串联：

### 1. Freshdesk 数据拉取 (`mx_daily_report.py`)

从 Freshdesk API 拉取 MX Support 分组的工单数据，按墨西哥时区 (UTC-6) 日期分组，计算每位 Agent 的：

- **Needs Follow Up** — 客户已回复、等待 Agent 跟进的工单数
- **Tickets Under Name** — Agent 名下所有工单总数
- **Tickets Escalated** — Agent 名下被升级的工单数

默认拉取墨西哥时区"今天"的数据，输出 JSON 文件。

### 2. Excel 报告生成 (`create_daily_excel.py`)

将 JSON 数据转换为格式化的 Excel 报告 (`MX_Support_Daily_Report.xlsx`)，包含 "Daily Report" 和 "Ticket IDs" 两个工作表。每次运行覆盖同名文件，保持"当前版本"始终是最新的。

### 3. 钉钉 AI 表格同步 (`sync_to_dingtalk_aitable.py`)

将 Excel 报告中的数据同步到钉钉 AI 表格 "Daily Workload" 数据表。核心特性：

- **按当天日期筛选**：只写入与当天日期匹配的行
- **本月每日替换**（默认模式）：每次运行先删除当月已有记录，再写入新数据
- **补录模式**（`--date`）：只替换指定日期的记录，不影响同月其他日期
- **跨月自动保留**：自动保留之前月份的数据

## 前置条件

### Python 环境

- Python 3.10+（推荐 3.12+）
- `openpyxl` 库

```bash
pip install openpyxl
```

### Freshdesk API（数据拉取需要）

设置环境变量：

```bash
set FRESHDESK_API_KEY=你的API密钥
set FRESHDESK_DOMAIN=glinetservice.freshdesk.com
```

API Key 需要有以下权限（仅读取）：`GET /api/v2/search/tickets`、`GET /api/v2/tickets/{id}`、`GET /api/v2/tickets/{id}/conversations`、`GET /api/v2/agents/{id}`

### dws CLI（钉钉同步需要）

`dws` 是钉钉工作台 CLI 工具，用于操作 AI 表格。安装步骤：

1. **安装 QoderWork**：从 [https://qoder.com](https://qoder.com) 下载并安装 QoderWork 桌面应用
2. **连接钉钉账号**：在 QoderWork 中打开"连接器"设置，完成钉钉账号授权
3. **dws 自动安装**：授权完成后，`dws-core` 二进制文件会自动下载到 `~/.qoderworkcn/bin/ext/` 目录
4. **验证安装**：同步脚本会自动在该路径查找 dws-core，无需手动配置 PATH

> **注意**：dws 的"删除记录"权限属于中等风险，首次运行时需要在浏览器中完成一次授权。建议选择"永久授权"以避免每次运行都需要手动确认。在 Windows Task Scheduler 无人值守环境下，如果未选择永久授权，删除操作会因无法弹出浏览器而失败。

## 快速开始

### 一键运行全流程（推荐）

```bash
# 方式 1: 使用 Python 编排脚本
python scripts/run_daily_pipeline.py

# 方式 2: 使用 Windows bat 脚本
scripts\run_daily_pipeline.bat
```

自动完成：拉取 Freshdesk 数据 → 生成 Excel → 同步到钉钉 AI 表格。

### 分步运行

```bash
# Step 1: 拉取 Freshdesk 数据（默认拉取墨西哥时区"今天"）
python scripts/mx_daily_report.py

# 指定日期范围
python scripts/mx_daily_report.py --start-date 2026-07-01 --end-date 2026-07-05

# Step 2: 生成 Excel 报告（默认读写脚本同目录下的文件）
python scripts/create_daily_excel.py

# Step 3: 同步到钉钉 AI 表格
python scripts/sync_to_dingtalk_aitable.py

# 指定日期补录（只替换该日期，不影响其他日期）
python scripts/sync_to_dingtalk_aitable.py --date 2026-07-02

# 预览模式（不写入）
python scripts/sync_to_dingtalk_aitable.py --dry-run --verbose
```

## Windows 定时任务

### 方式 1：全流程 pipeline（推荐）

使用 `scripts/run_daily_pipeline.bat`，一键完成拉取 + 生成 + 同步：

1. 打开"任务计划程序" (Task Scheduler)
2. 创建基本任务 → 每天触发（建议墨西哥时间 20:00 后，确保当天工单数据完整）
3. 操作：启动程序 → 选择 `run_daily_pipeline.bat` 的完整路径
4. 确保运行该任务的用户环境中已设置 `FRESHDESK_API_KEY` 和 `FRESHDESK_DOMAIN`

### 方式 2：仅同步（Excel 已由其他方式生成）

使用 `scripts/sync_to_dingtalk_aitable.bat`，仅执行钉钉同步步骤。

### Python 路径自动检测

`.bat` 脚本会按以下顺序自动查找 Python：

1. `py -3`（Python Launcher for Windows）
2. `python`（PATH 中查找）
3. `%LOCALAPPDATA%\Programs\Python\` 下的各版本（3.14 → 3.10）

如果以上都找不到，请手动编辑 `.bat` 文件添加 Python 路径。

## 项目结构

```
├── README.md
├── .gitignore
└── scripts/
    ├── mx_daily_report.py           # Freshdesk 数据拉取
    ├── create_daily_excel.py         # Excel 报告生成
    ├── sync_to_dingtalk_aitable.py   # 钉钉 AI 表格同步
    ├── run_daily_pipeline.py         # Python 全流程编排
    ├── run_daily_pipeline.bat        # Windows 全流程 bat
    └── sync_to_dingtalk_aitable.bat  # Windows 仅同步 bat
```

## 数据流

```
Freshdesk API
    ↓ (mx_daily_report.py)
mx_daily_report_data.json
    ↓ (create_daily_excel.py)
MX_Support_Daily_Report.xlsx  ← 每日覆盖，固定文件名
    ↓ (sync_to_dingtalk_aitable.py)
钉钉 AI 表格 "Daily Workload"
```

## 同步逻辑详解

### 默认模式（每日同步）

1. 读取 Excel，筛选当天日期的行
2. 查询钉钉 AI 表格现有记录
3. 删除**当月**所有记录（保留历史月份）
4. 写入当天数据

适用于每天定时运行：当天重复执行会覆盖之前的数据，跨月时自动保留上月。

### 补录模式（`--date YYYY-MM-DD`）

1. 读取 Excel，筛选指定日期的行
2. 查询钉钉 AI 表格现有记录
3. **只删除该日期的记录**（不影响同月其他日期）
4. 写入该日期的新数据

适用于补录历史数据或修正某天的错误数据。

## 时区说明

所有日期按 **墨西哥城时区 (UTC-6)** 处理。墨西哥自 2022 年起取消了夏令时，固定使用 UTC-6。

## 环境变量参考

| 变量 | 用途 | 必需 |
|------|------|------|
| `FRESHDESK_API_KEY` | Freshdesk API 密钥 | 数据拉取 |
| `FRESHDESK_DOMAIN` | Freshdesk 域名 | 数据拉取 |
| `DWS_PATH` | dws 可执行文件路径（可选，默认自动检测） | 钉钉同步 |

## 注意事项

- Freshdesk API 调用均为 **只读** GET 请求，不会修改任何工单数据
- Excel 每次运行覆盖同名文件 `MX_Support_Daily_Report.xlsx`，如需归档请手动复制
- 钉钉 AI 表格的"删除记录"操作首次使用需要浏览器授权，Task Scheduler 环境下建议选"永久授权"
- 脚本内置了 API 限速（0.12 秒间隔）和自动重试机制
- 同步日志写入脚本同目录下的 `sync_log.txt`

## License

MIT
