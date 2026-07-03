# MX Support Daily Report

Freshdesk MX Support 工单数据拉取 + 钉钉 AI 表格自动同步工具。

## 功能

本项目包含两个核心工具：

### 1. Freshdesk 数据拉取 (`mx_daily_report.py`)

从 Freshdesk API 拉取 MX Support 分组的工单数据，按墨西哥时区 (UTC-6) 日期分组，计算每位 Agent 的：

- **Needs Follow Up** — 客户已回复、等待 Agent 跟进的工单数
- **Tickets Under Name** — Agent 名下所有工单总数
- **Tickets Escalated** — Agent 名下被升级的工单数

输出 JSON 数据文件。

### 2. Excel 报告生成 (`create_daily_excel.py`)

将 JSON 数据转换为格式化的 Excel 报告，包含 "Daily Report" 和 "Ticket IDs" 两个工作表。

### 3. 钉钉 AI 表格同步 (`sync_to_dingtalk_aitable.py`)

将 Excel 报告中的数据同步到钉钉 AI 表格 "Daily Workload" 数据表。核心特性：

- **按当天日期筛选**：只写入与当天日期匹配的行
- **本月每日替换**：每次运行先删除当月已有记录，再写入新数据
- **跨月自动保留**：自动保留之前月份的数据（如 7 月运行时保留 6 月数据）
- **Windows Task Scheduler 兼容**：提供 `.bat` 包装脚本

## 前置条件

- Python 3.10+
- `openpyxl` 库 (`pip install openpyxl`)
- Freshdesk API 密钥（环境变量 `FRESHDESK_API_KEY` 和 `FRESHDESK_DOMAIN`）
- 钉钉 dws CLI 工具（用于 AI 表格同步）

## 快速开始

### 步骤 1：拉取 Freshdesk 数据

```bash
# 拉取指定日期范围的数据
python scripts/mx_daily_report.py --start-date 2026-07-01 --end-date 2026-07-03

# 输出: mx_daily_report_data.json
```

### 步骤 2：生成 Excel 报告

```bash
python scripts/create_daily_excel.py --input mx_daily_report_data.json --output MX_Support_Daily_Report.xlsx
```

### 步骤 3：同步到钉钉 AI 表格

```bash
# 同步当天日期的数据
python scripts/sync_to_dingtalk_aitable.py

# 指定日期（用于测试或补录）
python scripts/sync_to_dingtalk_aitable.py --date 2026-07-02

# 预览模式
python scripts/sync_to_dingtalk_aitable.py --dry-run --verbose
```

## Windows 自动任务

使用 `scripts/sync_to_dingtalk_aitable.bat` 在 Windows Task Scheduler 中配置每日自动同步：

1. 打开"任务计划程序"
2. 创建基本任务 → 每天触发
3. 操作：启动程序 → 选择 `sync_to_dingtalk_aitable.bat`

## 项目结构

```
├── README.md
├── .gitignore
└── scripts/
    ├── mx_daily_report.py          # Freshdesk 数据拉取
    ├── create_daily_excel.py        # Excel 报告生成
    ├── sync_to_dingtalk_aitable.py  # 钉钉 AI 表格同步
    └── sync_to_dingtalk_aitable.bat # Windows Task Scheduler 包装
```

## 时区说明

所有日期按 **墨西哥城时区 (UTC-6)** 处理。墨西哥自 2022 年起取消了夏令时，固定使用 UTC-6。

## 注意事项

- Freshdesk API 调用均为 **只读** GET 请求，不会修改任何工单数据
- 钉钉 AI 表格的"删除记录"操作首次使用需要授权，建议选择"永久授权"
- 脚本内置了 API 限速（0.12 秒间隔）和自动重试机制

## License

MIT
