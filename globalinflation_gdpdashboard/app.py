import requests
import pandas as pd
import streamlit as st
import plotly.express as px

WB = "https://api.worldbank.org/v2"

INDICATORS = {
    "GDP (current US$) [NY.GDP.MKTP.CD]": "NY.GDP.MKTP.CD",
    "Inflation, consumer prices (annual %) [FP.CPI.TOTL.ZG]": "FP.CPI.TOTL.ZG",
}

st.set_page_config(page_title="Global Inflation & GDP Dashboard", layout="wide")
st.title("🌍 Global Inflation & GDP Dashboard (World Bank)")

@st.cache_data(ttl=24 * 3600)
def fetch_countries():
    # returns: name, iso2 (id), iso3 (iso3Code), region, incomeLevel
    url = f"{WB}/country"
    params = {"format": "json", "per_page": 400, "page": 1}
    all_rows = []

    while True:
        r = requests.get(url, params=params, timeout=60)
        r.raise_for_status()
        meta, data = r.json()
        if not data:
            break

        for c in data:
            # skip aggregates like "World", regions etc. (they often have region "Aggregates")
            if c.get("region", {}).get("value") == "Aggregates":
                continue
            all_rows.append({
                "country": c.get("name"),
                "iso2": c.get("id"),
                "iso3": c.get("iso3Code"),
                "region": c.get("region", {}).get("value"),
                "income": c.get("incomeLevel", {}).get("value"),
            })

        page = int(meta.get("page", 1))
        pages = int(meta.get("pages", 1))
        if page >= pages:
            break
        params["page"] = page + 1

    df = pd.DataFrame(all_rows).dropna(subset=["iso2", "iso3"])
    df = df[df["iso3"].str.len() == 3]
    return df

@st.cache_data(ttl=6 * 3600)
def fetch_indicator_year(indicator: str, year: int) -> pd.DataFrame:
    # Query all countries for a single year
    url = f"{WB}/country/all/indicator/{indicator}"
    params = {
        "format": "json",
        "per_page": 20000,
        "date": f"{year}:{year}"
    }
    r = requests.get(url, params=params, timeout=120)
    r.raise_for_status()
    meta, data = r.json()

    rows = []
    for item in data:
        # item["country"]["id"] is ISO2 code, item["value"] is numeric or None
        c = item.get("country", {})
        rows.append({
            "iso2": c.get("id"),
            "country": c.get("value"),
            "year": int(item.get("date")),
            "value": item.get("value"),
        })

    df = pd.DataFrame(rows)
    df["value"] = pd.to_numeric(df["value"], errors="coerce")
    df = df.dropna(subset=["iso2"])
    return df

@st.cache_data(ttl=6 * 3600)
def fetch_indicator_timeseries(indicator: str, iso2_list: list[str], start_year: int, end_year: int) -> pd.DataFrame:
    # Fetch country-by-country (WB API is easiest this way for time series)
    all_rows = []
    for iso2 in iso2_list:
        url = f"{WB}/country/{iso2}/indicator/{indicator}"
        params = {"format": "json", "per_page": 20000, "date": f"{start_year}:{end_year}"}
        r = requests.get(url, params=params, timeout=120)
        r.raise_for_status()
        meta, data = r.json()
        for item in data:
            all_rows.append({
                "iso2": iso2,
                "country": item.get("country", {}).get("value"),
                "year": int(item.get("date")),
                "value": item.get("value"),
            })

    df = pd.DataFrame(all_rows)
    df["value"] = pd.to_numeric(df["value"], errors="coerce")
    df = df.dropna(subset=["value"])
    return df

countries = fetch_countries()

with st.sidebar:
    st.header("Controls")
    indicator_label = st.selectbox("Indicator", list(INDICATORS.keys()))
    indicator = INDICATORS[indicator_label]

    year = st.slider("Map year", min_value=1960, max_value=2024, value=2022, step=1)

    st.subheader("Country comparison")
    default = ["United States", "India", "China"]
    options = countries["country"].tolist()
    selected_countries = st.multiselect(
        "Select countries",
        options=options,
        default=[c for c in default if c in options]
    )

    start_year, end_year = st.slider(
        "Trend range",
        min_value=1960, max_value=2024, value=(2000, 2024), step=1
    )

# ------- Map data -------
df_year = fetch_indicator_year(indicator, year)
df_map = df_year.merge(countries[["iso2", "iso3", "region", "income"]], on="iso2", how="left")
df_map = df_map.dropna(subset=["iso3"])

# ------- KPI / quick stats -------
valid_vals = df_map["value"].dropna()
c1, c2, c3, c4 = st.columns(4)
c1.metric("Indicator", indicator_label)
c2.metric("Year", str(year))
c3.metric("Countries w/ data", f"{len(valid_vals):,}")
if len(valid_vals) > 0:
    c4.metric("Median", f"{valid_vals.median():,.2f}")
else:
    c4.metric("Median", "N/A")

st.divider()

left, right = st.columns([1.35, 1])

with left:
    st.subheader("🗺️ World Map")
    # Plotly choropleth expects ISO-3 codes
    fig = px.choropleth(
        df_map,
        locations="iso3",
        color="value",
        hover_name="country",
        hover_data={"region": True, "income": True, "iso3": True, "value": ":,.2f"},
        projection="natural earth",
        title=f"{indicator_label} — {year}"
    )
    fig.update_layout(margin=dict(l=0, r=0, t=50, b=0))
    st.plotly_chart(fig, use_container_width=True)

with right:
    st.subheader("📋 Top / Bottom Countries")
    df_rank = df_map.dropna(subset=["value"]).copy()
    df_rank = df_rank.sort_values("value", ascending=False)
    top = df_rank.head(15)[["country", "value", "region", "income"]]
    bottom = df_rank.tail(15)[["country", "value", "region", "income"]]

    st.caption("Top 15")
    st.dataframe(top, use_container_width=True, height=260)

    st.caption("Bottom 15")
    st.dataframe(bottom.sort_values("value", ascending=True), use_container_width=True, height=260)

st.divider()

# ------- Country comparison -------
st.subheader("📈 Country Comparison (Trend)")
if selected_countries:
    sel_df = countries[countries["country"].isin(selected_countries)][["country", "iso2"]]
    iso2_list = sel_df["iso2"].tolist()

    ts = fetch_indicator_timeseries(indicator, iso2_list, start_year, end_year)
    # Ensure ordering for charts
    ts = ts.sort_values(["country", "year"])

    line = px.line(
        ts,
        x="year",
        y="value",
        color="country",
        markers=False,
        title=f"{indicator_label} — {start_year} to {end_year}"
    )
    line.update_layout(margin=dict(l=0, r=0, t=50, b=0))
    st.plotly_chart(line, use_container_width=True)

    st.subheader("📎 Comparison Table (Latest within range)")
    latest = ts.sort_values("year").groupby("country", as_index=False).tail(1)
    latest = latest.sort_values("value", ascending=False)[["country", "year", "value"]]
    st.dataframe(latest, use_container_width=True)
else:
    st.info("Select at least one country in the sidebar to see the trend chart.")
