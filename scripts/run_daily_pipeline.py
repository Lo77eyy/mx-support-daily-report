#!/usr/bin/env python3
"""
MX Support Daily Report — 全流程编排脚本

一键完成：Freshdesk 拉取 → Excel 生成 → 钉钉 AI 表格同步

用法：
  python run_daily_pipeline.py                    # 全流程（默认今天）
  python run_daily_pipeline.py --date 2026-07-03  # 指定日期
  python run_daily_pipeline.py --skip-sync        # 跳过钉钉同步
  python run_daily_pipeline.py --dry-run          # 预览模式
"""

import subprocess
import sys
import os
import argparse
from pathlib import Path

# Windows 控制台 UTF-8 支持
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

SCRIPT_DIR = Path(__file__).resolve().parent
PYTHON = sys.executable  # 使用当前运行本脚本的 Python 解释器


def run_step(step_num: int, total: int, description: str, script: str,
             extra_args: list = None) -> bool:
    """运行一个步骤"""
    print(f"\n{'='*60}")
    print(f"[Step {step_num}/{total}] {description}")
    print(f"{'='*60}")

    cmd = [PYTHON, str(SCRIPT_DIR / script)]
    if extra_args:
        cmd.extend(extra_args)

    print(f"执行: {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=str(SCRIPT_DIR))

    if result.returncode != 0:
        print(f"\n[ERROR] {description} 失败 (exit code: {result.returncode})")
        return False

    print(f"\n[OK] {description} 完成")
    return True


def main():
    parser = argparse.ArgumentParser(description="MX Support Daily Report 全流程编排")
    parser.add_argument("--date", type=str, default=None,
                        help="指定日期 (YYYY-MM-DD)，默认墨西哥时区今天")
    parser.add_argument("--skip-sync", action="store_true",
                        help="跳过钉钉 AI 表格同步步骤")
    parser.add_argument("--dry-run", action="store_true",
                        help="预览模式（同步步骤不写入）")
    parser.add_argument("--start-date", type=str, default=None,
                        help="Freshdesk 拉取起始日期 (默认: 今天)")
    parser.add_argument("--end-date", type=str, default=None,
                        help="Freshdesk 拉取结束日期 (默认: 今天)")
    args = parser.parse_args()

    print("=" * 60)
    print("MX Support Daily Report — Pipeline")
    print(f"Python: {PYTHON}")
    print(f"脚本目录: {SCRIPT_DIR}")
    if args.date:
        print(f"指定日期: {args.date}")
    print("=" * 60)

    total_steps = 3 if not args.skip_sync else 2

    # ── Step 1: 拉取 Freshdesk 数据 ──
    fetch_args = []
    if args.start_date:
        fetch_args.extend(["--start-date", args.start_date])
    if args.end_date:
        fetch_args.extend(["--end-date", args.end_date])
    if args.date and not args.start_date and not args.end_date:
        fetch_args.extend(["--start-date", args.date, "--end-date", args.date])

    if not run_step(1, total_steps, "拉取 Freshdesk 数据",
                    "mx_daily_report.py", fetch_args):
        sys.exit(1)

    # ── Step 2: 生成 Excel ──
    if not run_step(2, total_steps, "生成 Excel 报告",
                    "create_daily_excel.py"):
        sys.exit(1)

    # ── Step 3: 同步到钉钉 AI 表格 ──
    if not args.skip_sync:
        sync_args = []
        if args.date:
            sync_args.extend(["--date", args.date])
        if args.dry_run:
            sync_args.append("--dry-run")

        if not run_step(3, total_steps, "同步到钉钉 AI 表格",
                        "sync_to_dingtalk_aitable.py", sync_args):
            sys.exit(1)

    # ── 完成 ──
    print(f"\n{'='*60}")
    print("Pipeline 完成!")
    print(f"  JSON 数据: {SCRIPT_DIR / 'mx_daily_report_data.json'}")
    print(f"  Excel 报告: {SCRIPT_DIR / 'MX_Support_Daily_Report.xlsx'}")
    if not args.skip_sync:
        print(f"  钉钉同步: 完成")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
