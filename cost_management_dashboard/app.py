import os
import json
import subprocess
import datetime as dt
from dataclasses import dataclass

import requests
import pandas as pd
import streamlit as st

# Cost Management Query API (REST) - 2025-03-01 is documented
COST_API_VERSION = "2025-03-01"  # :contentReference[oaicite:1]{index=1}
ARM_RESOURCE = "https://management.azure.com/"

st.set_page_config(page_title="Azure Cost Dashboard (Mini)", layout="wide")


@dataclass
class Period:
    name: str
    start: dt.date
    end: dt.date  # inclusive for our logic, but API uses endDate exclusive-ish? We'll send endDate as end (same day) and it works for month boundaries.


def first_day_of_month(d: dt.date) -> dt.date:
    return d.replace(day=1)


def last_day_of_month(d: dt.date) -> dt.date:
    # next month first day - 1 day
    if d.month == 12:
        nxt = d.replace(year=d.year + 1, month=1, day=1)
    else:
        nxt = d.replace(month=d.month + 1, day=1)
    return nxt - dt.timedelta(days=1)


def get_month_periods(today: dt.date):
    cur_start = first_day_of_month(today)
    cur_end = last_day_of_month(today)

    prev_month_ref = cur_start - dt.timedelta(days=1)
    prev_start = first_day_of_month(prev_month_ref)
    prev_end = last_day_of_month(prev_month_ref)

    return (
        Period("Current Month", cur_start, cur_end),
        Period("Previous Month", prev_start, prev_end),
    )


def run(cmd: list[str]) -> str:
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}\nSTDERR:\n{p.stderr.strip()}")
    return p.stdout.strip()


@st.cache_data(ttl=300)
def get_access_token_via_az() -> str:
    """
    Uses Azure CLI to get an ARM token.
    Works locally (az login) and in ACA if you do az login --identity (managed identity) before calling.
    """
    # If running in ACA with managed identity, you typically want: az login --identity
    # We'll try it, but ignore failures (local dev may not have MSI).
    try:
        run(["az", "login", "--identity"])
    except Exception:
        pass

    token = run([
        "az", "account", "get-access-token",
        "--resource", ARM_RESOURCE,
        "--query", "accessToken",
        "-o", "tsv"
    ])
    if not token:
        raise RuntimeError("Empty token from Azure CLI. Ensure you're logged in (az login) or MSI is enabled.")
    return token


def cost_query(scope: str, token: str, from_date: dt.date, to_date: dt.date, group_by_rg: bool):
    """
    Calls Cost Management Query API:
    POST https://management.azure.com/{scope}/providers/Microsoft.CostManagement/query?api-version=...
    :contentReference[oaicite:2]{index=2}
    """
    url = f"https://management.azure.com{scope}/providers/Microsoft.CostManagement/query?api-version={COST_API_VERSION}"

    dataset = {
        "granularity": "None",
        "aggregation": {
            "totalCost": {"name": "Cost", "function": "Sum"}
        }
    }

    if group_by_rg:
        dataset["grouping"] = [
            {"type": "Dimension", "name": "ResourceGroupName"}
        ]

    body = {
        "type": "ActualCost",
        "timeframe": "Custom",
        "timePeriod": {
            "from": from_date.isoformat(),
            "to": to_date.isoformat()
        },
        "dataset": dataset
    }

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    r = requests.post(url, headers=headers, data=json.dumps(body), timeout=60)
    if r.status_code >= 400:
        raise RuntimeError(
            f"Cost query failed ({r.status_code}).\n"
            f"URL: {url}\n"
            f"Response: {r.text[:2000]}"
        )
    return r.json()


def parse_total_cost(resp: dict) -> float:
    # For non-grouped, usually returns a single row with aggregated cost.
    props = resp.get("properties", {})
    rows = props.get("rows", [])
    if not rows:
        return 0.0
    # Expect first column is cost when only one aggregation
    return float(rows[0][0])


def parse_rg_costs(resp: dict) -> pd.DataFrame:
    props = resp.get("properties", {})
    cols = [c.get("name") for c in props.get("columns", [])]
    rows = props.get("rows", [])
    if not rows:
        return pd.DataFrame(columns=["ResourceGroupName", "Cost"])

    df = pd.DataFrame(rows, columns=cols)
    # Commonly: columns like ["Cost", "ResourceGroupName"] or ["ResourceGroupName","Cost"]
    # Normalize:
    if "ResourceGroupName" not in df.columns:
        # fallback: find any column containing "resourcegroup"
        rg_col = next((c for c in df.columns if "resourcegroup" in c.lower()), None)
        if rg_col:
            df = df.rename(columns={rg_col: "ResourceGroupName"})
    if "Cost" not in df.columns:
        cost_col = next((c for c in df.columns if c.lower() == "cost" or "cost" in c.lower()), None)
        if cost_col:
            df = df.rename(columns={cost_col: "Cost"})

    df["Cost"] = pd.to_numeric(df["Cost"], errors="coerce").fillna(0.0)
    df["ResourceGroupName"] = df["ResourceGroupName"].fillna("(unknown)")
    df = df.groupby("ResourceGroupName", as_index=False)["Cost"].sum()
    df = df.sort_values("Cost", ascending=False)
    return df


def pct_change(cur: float, prev: float) -> float:
    if prev == 0:
        return 0.0 if cur == 0 else 100.0
    return ((cur - prev) / prev) * 100.0


# ---------------- UI ----------------
st.title("💰 Azure Cost Dashboard (Mini)")

with st.sidebar:
    st.header("Scope")
    default_sub = os.getenv("AZURE_SUBSCRIPTION_ID", "").strip()
    subscription_id = st.text_input("Subscription ID", value=default_sub, placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")
    currency = st.text_input("Display currency (label only)", value="USD")
    top_n = st.slider("Top N Resource Groups", min_value=5, max_value=50, value=15, step=1)
    st.caption("Auth uses Azure CLI token. Locally run: az login. In ACA enable Managed Identity + grant Cost Management Reader.")

if not subscription_id:
    st.info("Enter a Subscription ID in the sidebar (or set AZURE_SUBSCRIPTION_ID env var).")
    st.stop()

scope = f"/subscriptions/{subscription_id}"

today = dt.date.today()
cur_period, prev_period = get_month_periods(today)

# Get token
try:
    token = get_access_token_via_az()
except Exception as e:
    st.error(str(e))
    st.stop()

# Query totals
try:
    cur_total_resp = cost_query(scope, token, cur_period.start, cur_period.end, group_by_rg=False)
    prev_total_resp = cost_query(scope, token, prev_period.start, prev_period.end, group_by_rg=False)

    cur_total = parse_total_cost(cur_total_resp)
    prev_total = parse_total_cost(prev_total_resp)

    # Query RG breakdown
    cur_rg_resp = cost_query(scope, token, cur_period.start, cur_period.end, group_by_rg=True)
    prev_rg_resp = cost_query(scope, token, prev_period.start, prev_period.end, group_by_rg=True)

    df_cur = parse_rg_costs(cur_rg_resp)
    df_prev = parse_rg_costs(prev_rg_resp)

except Exception as e:
    st.error(str(e))
    st.stop()

delta = cur_total - prev_total
delta_pct = pct_change(cur_total, prev_total)

k1, k2, k3, k4 = st.columns(4)
k1.metric(f"{cur_period.name} ({cur_period.start} → {cur_period.end})", f"{cur_total:,.2f} {currency}")
k2.metric(f"{prev_period.name} ({prev_period.start} → {prev_period.end})", f"{prev_total:,.2f} {currency}")
k3.metric("Delta", f"{delta:,.2f} {currency}")
k4.metric("Delta %", f"{delta_pct:,.2f}%")

st.divider()

# Merge RG breakdown for comparison
df_compare = df_cur.merge(df_prev, on="ResourceGroupName", how="outer", suffixes=("_Current", "_Previous")).fillna(0.0)
df_compare["Delta"] = df_compare["Cost_Current"] - df_compare["Cost_Previous"]
df_compare["Delta%"] = df_compare.apply(lambda r: pct_change(r["Cost_Current"], r["Cost_Previous"]), axis=1)
df_compare = df_compare.sort_values("Cost_Current", ascending=False)

left, right = st.columns([1.4, 1])

with left:
    st.subheader("🏷️ Resource Group Breakdown (Current Month)")
    st.dataframe(df_cur.head(top_n), use_container_width=True, height=520)

with right:
    st.subheader("📊 Current vs Previous (Top RGs)")
    st.dataframe(
        df_compare[["ResourceGroupName", "Cost_Current", "Cost_Previous", "Delta", "Delta%"]].head(top_n),
        use_container_width=True,
        height=520
    )

st.divider()

st.subheader("📈 Charts (Top Resource Groups)")
chart_df = df_compare.head(top_n).set_index("ResourceGroupName")[["Cost_Current", "Cost_Previous"]]
st.bar_chart(chart_df)
