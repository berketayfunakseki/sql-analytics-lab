# SQL Analytics Lab — Cohort Retention, Funnel, and Growth Metrics

Product-analytics SQL against a synthetic app-usage dataset: funnel conversion,
weekly cohort retention, growth curves, and country-level ranking — the exact
question shapes that come up in DS/analytics SQL interviews ("compute N-week
retention by cohort", "rank X by Y with ties handled correctly").

All analysis is in raw SQL (`sql/*.sql`) using window functions and CTEs —
no ORM, no pandas groupby standing in for what SQL should do.

## What's inside

| File | Technique |
|---|---|
| `sql/funnel_conversion.sql` | `LAG()`, `FIRST_VALUE()` — step-over-step and overall funnel conversion |
| `sql/cohort_retention.sql` | Multi-CTE cohort analysis — weekly retention by signup cohort |
| `sql/growth_and_ranking.sql` | Running totals (`SUM() OVER`), rolling averages, `RANK()` vs `DENSE_RANK()` |
| `src/generate_data.py` | Builds a realistic synthetic `users` + `events` dataset into SQLite |
| `src/run_queries.py` | Executes every `.sql` file and prints results — also acts as a smoke test |
| `dashboard.py` | Streamlit app visualizing all of the above |

## Running locally

```bash
pip install -r requirements.txt

# generate the synthetic database
python src/generate_data.py

# run every SQL file and print results
python src/run_queries.py

# or view it in the dashboard
streamlit run dashboard.py
```

## Running with Docker

```bash
docker build -t sql-analytics-lab .
docker run -p 8501:8501 sql-analytics-lab
```

## Schema

```
users(user_id, signup_date, country, plan)
events(user_id, event_name, event_time)
  event_name ∈ {signup, onboarding_complete, first_action, activated, subscribed, session}
```

`session` events represent repeat usage after the initial funnel — used for retention analysis.

## Sample insight the funnel query surfaces

The steepest drop-off in the simulated funnel is between `first_action` and `activated`
(~55% loss) — steeper than the earlier `signup → onboarding_complete` step. In a real
product this is exactly the kind of finding that redirects a roadmap: it says the
biggest lever isn't onboarding UX, it's whatever happens right after a user's first action.

## Why these choices

- **`LAG()` over a self-join for funnel drop-off** — a self-join to compare each step to
  the previous one works, but scales poorly and reads worse. `LAG()` is the idiomatic tool
  for "compare this row to the previous row" and every modern SQL engine optimises it well.
- **Explicit `CASE`-based step ordering, not alphabetical** — funnel steps have a real
  business sequence that doesn't match alphabetical order; hardcoding the sequence prevents
  a silent, hard-to-notice bug.
- **Retention gated by funnel depth, not just full activation** — early data generation
  attempts tied all retention to fully-activated users only, which produced unrealistically
  low retention numbers. Real users return at every funnel depth, just at different rates.

## Lessons learned

- **My first comment-stripping logic in `run_queries.py` silently dropped every query** —
  it checked whether an entire multi-line SQL statement *started* with `--`, which was always
  true since each statement opens with a comment header. Fixed by stripping comment lines
  before splitting on statement boundaries, not filtering whole statements.
- **Synthetic retention data needs care to look realistic** — gating all repeat-session
  generation behind one narrow user segment (only "activated" users) produced retention
  numbers far below real-world benchmarks. Tiering the retention probability by funnel depth
  fixed it and, as a side effect, made the funnel-vs-retention story more coherent.

## What I'd improve next

- Materialize the cohort/funnel queries as scheduled dbt models instead of ad-hoc scripts
- Add a `LEFT JOIN` version of the funnel query to show step-by-step *drop* (not just conversion)
- Postgres-specific window function variants (e.g. `PERCENT_RANK`) — this project uses SQLite for portability

---
Berke Tayfun Akseki — [berketayfunakseki.com](https://berketayfunakseki.com)
