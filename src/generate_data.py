"""
generate_data.py — builds a realistic synthetic app-usage dataset and
loads it into a local SQLite database, so the SQL files in sql/ have
something real to run against.

Schema mirrors a typical product-analytics setup: users, signup cohort,
and an event log (funnel steps + repeat usage).
"""
from __future__ import annotations
import sqlite3
import numpy as np
import pandas as pd
from pathlib import Path
from datetime import datetime, timedelta

DB_PATH = Path(__file__).parent.parent / "data" / "analytics.db"
FUNNEL_STEPS = ["signup", "onboarding_complete", "first_action", "activated", "subscribed"]


def generate(n_users: int = 3000, seed: int = 11) -> None:
    rng = np.random.default_rng(seed)
    start_date = datetime(2026, 1, 1)

    # ── USERS + SIGNUP COHORT ──────────────────────────────────────────
    signup_days = rng.integers(0, 180, n_users)
    countries = rng.choice(
        ["CH", "DE", "IT", "FR", "US", "GB"], n_users, p=[0.25, 0.2, 0.2, 0.15, 0.1, 0.1]
    )
    plans = rng.choice(["free", "pro"], n_users, p=[0.75, 0.25])

    users = pd.DataFrame({
        "user_id": range(1, n_users + 1),
        "signup_date": [(start_date + timedelta(days=int(d))).date().isoformat() for d in signup_days],
        "country": countries,
        "plan": plans,
    })

    # ── FUNNEL EVENTS ───────────────────────────────────────────────────
    # each user progresses through the funnel with decreasing probability
    # at each step — a classic drop-off shape — plus some users churn and
    # never come back, while others become repeat/retained users.
    events = []
    step_conversion_probs = [1.0, 0.72, 0.55, 0.30, 0.12]  # P(reach this step | reached previous)
    # retention probability tiered by funnel depth: even users who only
    # completed onboarding come back sometimes, not just fully "activated" users —
    # this matches real product usage better than an all-or-nothing session flag.
    retention_prob_by_depth = {
        "onboarding_complete": 0.18,
        "first_action": 0.35,
        "activated": 0.65,
        "subscribed": 0.85,
    }

    for _, u in users.iterrows():
        signup_dt = datetime.fromisoformat(u["signup_date"])
        reached = True
        deepest_step = None
        for i, step in enumerate(FUNNEL_STEPS):
            if i > 0:
                reached = reached and (rng.random() < step_conversion_probs[i])
            if not reached:
                break
            deepest_step = step
            event_time = signup_dt + timedelta(hours=int(rng.integers(0, 72 * (i + 1))))
            events.append({"user_id": u["user_id"], "event_name": step, "event_time": event_time.isoformat()})

        # retention: probability of coming back scales with how deep the user
        # got in the funnel — matches real product behaviour much better than
        # gating retention entirely behind full activation.
        retention_p = retention_prob_by_depth.get(deepest_step, 0.0)
        if retention_p and rng.random() < retention_p:
            n_sessions = 1 + rng.poisson(3)
            for _ in range(n_sessions):
                offset = int(rng.integers(1, 60))
                session_time = signup_dt + timedelta(days=offset)
                events.append({
                    "user_id": u["user_id"], "event_name": "session",
                    "event_time": session_time.isoformat(),
                })

    events_df = pd.DataFrame(events)

    # ── WRITE TO SQLITE ─────────────────────────────────────────────────
    DB_PATH.parent.mkdir(exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    users.to_sql("users", conn, if_exists="replace", index=False)
    events_df.to_sql("events", conn, if_exists="replace", index=False)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_events_user ON events(user_id)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_events_name ON events(event_name)")
    conn.commit()
    conn.close()
    print(f"Wrote {len(users)} users and {len(events_df)} events to {DB_PATH}")


if __name__ == "__main__":
    generate()
