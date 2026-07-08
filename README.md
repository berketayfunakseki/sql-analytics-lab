"""
dashboard.py — visualizes the SQL analysis results.
The SQL does the real work; this just renders it so a recruiter can see
the output without running Python themselves.
"""
import streamlit as st
import matplotlib.pyplot as plt
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from src.run_queries import run_all

st.set_page_config(page_title="SQL Analytics Lab", layout="wide")
st.title("📊 SQL Analytics Lab")
st.caption("Cohort retention, funnel conversion, and growth metrics — computed entirely in SQL (window functions, CTEs) against a synthetic app-usage dataset.")

try:
    results = run_all()
except FileNotFoundError:
    st.error("Database not found. Run `python src/generate_data.py` first.")
    st.stop()

tab1, tab2, tab3, tab4 = st.tabs(["🔻 Funnel", "📅 Cohort Retention", "📈 Growth", "🌍 Country Ranking"])

with tab1:
    st.subheader("Signup → Subscribed funnel")
    df = results["funnel_conversion"]
    st.dataframe(df, use_container_width=True)

    fig, ax = plt.subplots(figsize=(9, 4))
    ax.bar(df["funnel_step"], df["users_reached"], color="#00C299")
    for i, row in df.iterrows():
        ax.text(i, row["users_reached"], f"{row['overall_conversion_from_signup_pct']}%", ha="center", va="bottom")
    ax.set_ylabel("Users reached")
    ax.set_title("Funnel drop-off (% = conversion from signup)")
    st.pyplot(fig)

    biggest_drop = df.loc[df["step_over_step_conversion_pct"].idxmin()]
    st.info(f"**Biggest drop-off:** into *{biggest_drop['funnel_step']}* "
            f"({biggest_drop['step_over_step_conversion_pct']}% of the previous step made it through) — "
            f"this is where product investment would have the highest leverage.")

with tab2:
    st.subheader("Weekly retention by signup cohort")
    df = results["cohort_retention"]
    pivot = df.pivot(index="cohort_week", columns="week_number", values="retention_pct")
    st.dataframe(pivot.style.background_gradient(cmap="Greens", axis=None), use_container_width=True)
    st.caption("Rows = signup cohort (week). Columns = weeks since signup. Cell = % of that cohort active in that week.")

with tab3:
    st.subheader("Cumulative signups & rolling average")
    df = results["growth_and_ranking_part1"]
    fig, ax = plt.subplots(figsize=(10, 4))
    ax2 = ax.twinx()
    ax.bar(df["signup_date"], df["new_signups"], alpha=0.3, label="Daily signups", color="#22D3EE")
    ax2.plot(df["signup_date"], df["cumulative_signups"], color="#00C299", label="Cumulative")
    ax.set_xticks(df["signup_date"][::20])
    ax.set_xticklabels(df["signup_date"][::20], rotation=45, ha="right")
    ax.set_ylabel("Daily signups"); ax2.set_ylabel("Cumulative signups")
    fig.legend(loc="upper left", bbox_to_anchor=(0.1, 0.9))
    st.pyplot(fig)

with tab4:
    st.subheader("Pro-plan conversion by country")
    df = results["growth_and_ranking_part2"]
    st.dataframe(df, use_container_width=True)
    st.caption("`rank_with_gaps` (RANK) vs `dense_rank_no_gaps` (DENSE_RANK) — note how tied countries (DE/IT) "
               "cause RANK to skip a position while DENSE_RANK doesn't.")

st.divider()
st.caption("Berke Tayfun Akseki — [berketayfunakseki.com](https://berketayfunakseki.com)")
