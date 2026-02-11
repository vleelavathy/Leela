import datetime as dt
import requests
import pandas as pd
import streamlit as st

API = "https://api.frankfurter.dev/v1"

st.set_page_config(page_title="Global Currency Rates Dashboard", layout="wide")

@st.cache_data(ttl=3600)
def get_currencies():
    r = requests.get(f"{API}/currencies", timeout=20)
    r.raise_for_status()
    data = r.json()
    # sort by code
    return dict(sorted(data.items(), key=lambda x: x[0]))

@st.cache_data(ttl=300)
def get_latest(base: str):
    r = requests.get(f"{API}/latest", params={"base": base}, timeout=20)
    r.raise_for_status()
    return r.json()

@st.cache_data(ttl=3600)
def get_timeseries(base: str, symbols: list[str], start: dt.date, end: dt.date):
    # Frankfurter time series range format: /v1/YYYY-MM-DD..YYYY-MM-DD
    url = f"{API}/{start.isoformat()}..{end.isoformat()}"
    r = requests.get(url, params={"base": base, "symbols": ",".join(symbols)}, timeout=30)
    r.raise_for_status()
    return r.json()

currencies = get_currencies()
currency_codes = list(currencies.keys())

st.title("🌍 Global Currency Rates Dashboard")

with st.sidebar:
    st.header("Controls")
    base = st.selectbox("Base currency", currency_codes, index=currency_codes.index("USD") if "USD" in currency_codes else 0)
    amount = st.number_input("Amount", min_value=0.0, value=1.0, step=1.0)
    search = st.text_input("Search currency (code or name)", value="")
    show_top = st.slider("Show top N rows", min_value=10, max_value=200, value=50, step=10)

latest = get_latest(base)
rates = latest.get("rates", {})
as_of = latest.get("date", "unknown")

df = pd.DataFrame(
    [{"Code": k, "Currency": currencies.get(k, ""), f"Rate (1 {base})": v, f"Value ({amount} {base})": v * amount}
     for k, v in rates.items()]
)

# Filter by search
if search.strip():
    s = search.strip().lower()
    df = df[df["Code"].str.lower().str.contains(s) | df["Currency"].str.lower().str.contains(s)]

df = df.sort_values(by=f"Value ({amount} {base})", ascending=False)

# KPIs
c1, c2, c3 = st.columns(3)
c1.metric("Base", base)
c2.metric("As of", as_of)
c3.metric("Currencies shown", len(df))

# Layout
left, right = st.columns([1.4, 1])

with left:
    st.subheader("📋 Latest rates")
    st.dataframe(df.head(show_top), use_container_width=True, height=520)

with right:
    st.subheader("📈 Trend (last N business days)")
    # pick a few currencies to chart
    default_symbols = ["EUR", "GBP", "INR", "JPY"]
    default_symbols = [s for s in default_symbols if s in currency_codes and s != base]
    symbols = st.multiselect(
        "Currencies to chart",
        options=[c for c in currency_codes if c != base],
        default=default_symbols[:4] if default_symbols else []
    )
    days = st.slider("Days", min_value=5, max_value=90, value=30, step=5)

    if symbols:
        end = dt.date.today()
        start = end - dt.timedelta(days=days * 2)  # cushion for weekends/holidays
        ts = get_timeseries(base, symbols, start=start, end=end)

        # Normalize into a dataframe: rows=date, cols=symbol
        rates_by_date = ts.get("rates", {})
        if rates_by_date:
            tdf = pd.DataFrame.from_dict(rates_by_date, orient="index").sort_index()
            tdf.index = pd.to_datetime(tdf.index)
            # keep last N actual data points
            tdf = tdf.tail(days)
            st.line_chart(tdf, height=420)
        else:
            st.info("No time-series data returned for the selected range.")
    else:
        st.info("Pick at least one currency to display the trend.")
