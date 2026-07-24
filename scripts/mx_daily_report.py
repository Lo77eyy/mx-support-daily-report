#!/usr/bin/env python3
"""
MX Support Daily Report — 按日分组拉取 MX Support 工单数据

字段：
  - Agent Name
  - Data Retrieval Date (墨西哥时区)
  - Needs Follow Up (客户已回复，等待 agent 跟进)
  - Tickets Under Name (该 agent 名下所有工单)
  - Tickets Escalated (该 agent 名下已升级的工单)

仅使用 GET 请求，不修改任何数据。

用法：
  set FRESHDESK_API_KEY=你的API密钥
  python mx_daily_report.py

域名在 config.json 中配置（freshdesk.domain），也可通过 FRESHDESK_DOMAIN 环境变量覆盖。

默认拉取墨西哥时区今天的数据。
可通过 --start-date 和 --end-date 指定日期范围。
"""

import urllib.request
import urllib.error
import urllib.parse
import base64
import json
import os
import sys
import time
import argparse
from datetime import datetime, timezone, timedelta
from pathlib import Path
from collections import defaultdict

sys.stdout.reconfigure(encoding="utf-8")

# ── 配置 ──
READ_TIMEOUT = 30
REQUEST_DELAY = 0.12
MAX_RETRIES = 5

# 墨西哥时区: UTC-6 (CST) / UTC-5 (CDT, 夏令时)
# 2026年7月墨西哥不使用夏令时(2022年起取消)，所以固定 UTC-6
MEXICO_TZ = timezone(timedelta(hours=-6))

STATUS_MAP = {2: "Open", 3: "Pending", 4: "Resolved", 5: "Closed"}
PRIORITY_MAP = {1: "Low", 2: "Medium", 3: "High", 4: "Urgent"}


def get_auth_header(api_key):
    return f"Basic {base64.b64encode(f'{api_key}:X'.encode()).decode()}"


def get_json(domain, api_key, path, params=None):
    query = urllib.parse.urlencode(params or {})
    url = f"https://{domain}{path}"
    if query:
        url = f"{url}?{query}"
    req = urllib.request.Request(url, headers={
        "Authorization": get_auth_header(api_key),
        "Accept": "application/json",
        "User-Agent": "mx-daily-report/1.0",
    }, method="GET")
    for attempt in range(MAX_RETRIES):
        try:
            time.sleep(REQUEST_DELAY)
            with urllib.request.urlopen(req, timeout=READ_TIMEOUT) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < MAX_RETRIES - 1:
                time.sleep(int(e.headers.get("Retry-After", 5)))
                continue
            detail = e.read().decode("utf-8", errors="replace")[:200]
            raise RuntimeError(f"GET {path} => HTTP {e.code}: {detail}")
        except Exception as e:
            if attempt < MAX_RETRIES - 1:
                time.sleep(2 ** (attempt + 1))
                continue
            raise RuntimeError(f"GET {path} => {e}")


def search_tickets(domain, api_key, query, max_pages=10):
    all_results = []
    for page in range(1, max_pages + 1):
        payload = get_json(domain, api_key, "/api/v2/search/tickets", {
            "query": f'"{query}"',
            "page": page,
        })
        batch = payload.get("results", [])
        all_results.extend(batch)
        if len(batch) < 30 or len(all_results) >= payload.get("total", 0):
            break
    return all_results


def fetch_ticket_detail(domain, api_key, ticket_id):
    return get_json(domain, api_key, f"/api/v2/tickets/{ticket_id}", {"include": "stats"})


def fetch_conversations(domain, api_key, ticket_id):
    """获取工单对话列表"""
    try:
        convs = get_json(domain, api_key, f"/api/v2/tickets/{ticket_id}/conversations")
        return convs if isinstance(convs, list) else []
    except Exception:
        return []


def fetch_agent_name(domain, api_key, agent_id, cache):
    if agent_id in cache:
        return cache[agent_id]
    try:
        agent = get_json(domain, api_key, f"/api/v2/agents/{agent_id}")
        name = agent.get("contact", {}).get("name", f"Agent {agent_id}")
        cache[agent_id] = name
        return name
    except Exception:
        cache[agent_id] = f"Agent {agent_id}"
        return cache[agent_id]


def is_needs_follow_up(conversations):
    """
    判断工单是否需要跟进：
    有 agent 公开回复，且客户最新回复在 agent 最新回复之后。
    """
    if not conversations:
        return False
    last_agent_reply = None
    last_customer_reply = None
    for c in conversations:
        if c.get("private"):
            continue
        incoming = c.get("incoming", False)
        created = c.get("created_at", "")
        if incoming:
            if last_customer_reply is None or created > last_customer_reply:
                last_customer_reply = created
        else:
            if last_agent_reply is None or created > last_agent_reply:
                last_agent_reply = created
    if last_agent_reply and last_customer_reply:
        return last_customer_reply > last_agent_reply
    return False


def to_mexico_date(iso_str):
    """将 ISO 时间戳转换为墨西哥时区日期字符串"""
    if not iso_str:
        return None
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        mx_dt = dt.astimezone(MEXICO_TZ)
        return mx_dt.strftime("%Y-%m-%d")
    except Exception:
        return None


def main():
    from config_loader import load_config
    config = load_config()

    parser = argparse.ArgumentParser(description="MX Support Daily Report")
    parser.add_argument("--start-date", default=None,
                        help="Start date YYYY-MM-DD (Mexico time). Default: today")
    parser.add_argument("--end-date", default=None,
                        help="End date YYYY-MM-DD (Mexico time). Default: today")
    parser.add_argument("--output", default=None,
                        help="Output JSON path")
    args = parser.parse_args()

    # Freshdesk domain: env var overrides config
    domain = os.environ.get("FRESHDESK_DOMAIN", "").strip().removeprefix("https://").rstrip("/")
    if not domain:
        domain = config.get("freshdesk", {}).get("domain", "").strip().removeprefix("https://").rstrip("/")
    api_key = os.environ.get("FRESHDESK_API_KEY", "")
    if not domain or not api_key:
        print("请设置环境变量 FRESHDESK_API_KEY，并在 config.json 中配置 freshdesk.domain", file=sys.stderr)
        sys.exit(1)

    mx_group_id = config.get("freshdesk", {}).get("group_id", 0)
    if not mx_group_id:
        print("请在 config.json 中配置 freshdesk.group_id", file=sys.stderr)
        sys.exit(1)

    # 确定日期范围
    now_utc = datetime.now(timezone.utc)
    now_mx = now_utc.astimezone(MEXICO_TZ)

    if args.start_date:
        start_date = datetime.strptime(args.start_date, "%Y-%m-%d").date()
    else:
        start_date = now_mx.date()

    if args.end_date:
        end_date = datetime.strptime(args.end_date, "%Y-%m-%d").date()
    else:
        end_date = now_mx.date()

    print(f"域名: {domain}", file=sys.stderr)
    print(f"MX Support Group ID: {mx_group_id}", file=sys.stderr)
    print(f"日期范围 (墨西哥时区): {start_date} ~ {end_date}", file=sys.stderr)
    print(f"当前墨西哥时间: {now_mx.strftime('%Y-%m-%d %H:%M:%S')}", file=sys.stderr)

    # ── Step 1: 搜索所有 MX Support 工单 (所有状态) ──
    print("\n[1/4] 搜索所有 MX Support 工单...", file=sys.stderr)
    all_tickets = []
    for status_name, status_code in [("Open", 2), ("Pending", 3), ("Resolved", 4), ("Closed", 5)]:
        query = f"group_id:{mx_group_id} AND status:{status_code}"
        tickets = search_tickets(domain, api_key, query)
        print(f"  {status_name}: {len(tickets)} 条", file=sys.stderr)
        all_tickets.extend(tickets)

    # 去重
    seen = set()
    unique = []
    for t in all_tickets:
        if t["id"] not in seen:
            seen.add(t["id"])
            unique.append(t)
    all_tickets = unique
    print(f"  合计（去重后）: {len(all_tickets)} 条", file=sys.stderr)

    # ── Step 2: 逐个获取详情 + 判断 follow-up ──
    print(f"\n[2/4] 获取工单详情...", file=sys.stderr)
    agent_cache = {}
    ticket_data = []

    for i, t in enumerate(all_tickets):
        tid = t["id"]
        if (i + 1) % 20 == 0 or i == 0:
            print(f"  进度: {i+1}/{len(all_tickets)}", file=sys.stderr)

        # 用搜索结果中的 created_at 做初步日期过滤（宽松：多取一天避免时区边界问题）
        created_date = to_mexico_date(t.get("created_at"))
        if created_date:
            cd = datetime.strptime(created_date, "%Y-%m-%d").date()
            if cd < start_date - timedelta(days=1) or cd > end_date + timedelta(days=1):
                continue

        try:
            detail = fetch_ticket_detail(domain, api_key, tid)
        except Exception as e:
            print(f"  警告: Ticket {tid} 获取失败: {e}", file=sys.stderr)
            continue

        created_at = detail.get("created_at")
        mx_date = to_mexico_date(created_at)
        if not mx_date:
            continue
        cd = datetime.strptime(mx_date, "%Y-%m-%d").date()
        if cd < start_date or cd > end_date:
            continue

        responder_id = detail.get("responder_id")
        agent_name = ""
        if responder_id:
            agent_name = fetch_agent_name(domain, api_key, responder_id, agent_cache)

        ticket_data.append({
            "id": tid,
            "subject": detail.get("subject", ""),
            "status": STATUS_MAP.get(detail.get("status"), str(detail.get("status"))),
            "status_code": detail.get("status"),
            "priority": PRIORITY_MAP.get(detail.get("priority"), str(detail.get("priority"))),
            "created_at": created_at,
            "mexico_date": mx_date,
            "agent_id": responder_id,
            "agent_name": agent_name or "Unassigned",
            "is_escalated": detail.get("is_escalated", False),
            "fr_escalated": detail.get("fr_escalated", False),
            "needs_follow_up": False,  # 下一步确定
        })

    print(f"  日期范围内工单: {len(ticket_data)} 条", file=sys.stderr)

    # ── Step 3: 对 Open/Pending 工单检查 follow-up ──
    print(f"\n[3/4] 检查 Open/Pending 工单的跟进状态...", file=sys.stderr)
    open_pending = [t for t in ticket_data if t["status_code"] in (2, 3)]
    print(f"  需要检查对话的工单: {len(open_pending)} 条", file=sys.stderr)

    for i, t in enumerate(open_pending):
        if (i + 1) % 10 == 0 or i == 0:
            print(f"  对话检查进度: {i+1}/{len(open_pending)}", file=sys.stderr)
        convs = fetch_conversations(domain, api_key, t["id"])
        t["needs_follow_up"] = is_needs_follow_up(convs)

    # 对 Resolved/Closed 工单，如果客户在解决后回复了，也算需要跟进
    resolved_closed = [t for t in ticket_data if t["status_code"] in (4, 5)]
    # 这里简化处理：不逐个检查已解决工单的对话（量大），仅标记 Open/Pending 的

    # ── Step 4: 按日期 + Agent 分组 ──
    print(f"\n[4/4] 按日期分组...", file=sys.stderr)

    # 生成所有日期
    all_dates = []
    d = start_date
    while d <= end_date:
        all_dates.append(d.strftime("%Y-%m-%d"))
        d += timedelta(days=1)

    # 收集所有 agent
    all_agents = sorted(set(t["agent_name"] for t in ticket_data))

    # 分组统计
    daily_data = []
    for date_str in all_dates:
        day_tickets = [t for t in ticket_data if t["mexico_date"] == date_str]
        for agent in all_agents:
            agent_tickets = [t for t in day_tickets if t["agent_name"] == agent]
            if not agent_tickets:
                continue
            daily_data.append({
                "date": date_str,
                "agent_name": agent,
                "needs_follow_up": sum(1 for t in agent_tickets if t["needs_follow_up"]),
                "tickets_under_name": len(agent_tickets),
                "tickets_escalated": sum(1 for t in agent_tickets if t["is_escalated"]),
                "ticket_ids": [t["id"] for t in agent_tickets],
                "follow_up_ids": [t["id"] for t in agent_tickets if t["needs_follow_up"]],
                "escalated_ids": [t["id"] for t in agent_tickets if t["is_escalated"]],
            })

    # 汇总
    summary = {
        "total_tickets": len(ticket_data),
        "total_follow_up": sum(1 for t in ticket_data if t["needs_follow_up"]),
        "total_escalated": sum(1 for t in ticket_data if t["is_escalated"]),
        "date_range": f"{start_date} ~ {end_date}",
        "agents": all_agents,
        "dates": all_dates,
    }

    output = {
        "domain": domain,
        "group": "MX Support",
        "group_id": mx_group_id,
        "summary": summary,
        "daily_data": daily_data,
        "all_tickets": ticket_data,
    }

    output_path = args.output or str(Path(__file__).resolve().parent / "mx_daily_report_data.json")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    print(f"\nJSON 已保存: {output_path}", file=sys.stderr)

    # 打印摘要
    print(f"\n{'='*60}", file=sys.stderr)
    print(f"摘要:", file=sys.stderr)
    print(f"  日期范围: {summary['date_range']}", file=sys.stderr)
    print(f"  总工单数: {summary['total_tickets']}", file=sys.stderr)
    print(f"  需要跟进: {summary['total_follow_up']}", file=sys.stderr)
    print(f"  已升级: {summary['total_escalated']}", file=sys.stderr)
    print(f"  涉及 Agent: {len(all_agents)}", file=sys.stderr)
    print(f"{'='*60}", file=sys.stderr)

    return output


if __name__ == "__main__":
    main()
