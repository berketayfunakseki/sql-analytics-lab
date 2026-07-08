-- growth_and_ranking.sql
-- Two more window-function patterns that come up constantly in DS interviews:
-- (1) running/cumulative totals over time, (2) ranking within a partition.

-- ── PART 1: Cumulative signups over time (growth curve) ─────────────────
WITH daily_signups AS (
    SELECT signup_date, COUNT(*) AS new_signups
    FROM users
    GROUP BY signup_date
)
SELECT
    signup_date,
    new_signups,
    -- running total: cumulative signups as of each date
    SUM(new_signups) OVER (ORDER BY signup_date) AS cumulative_signups,
    -- 7-day rolling average to smooth day-to-day noise
    ROUND(AVG(new_signups) OVER (
        ORDER BY signup_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 1) AS rolling_7day_avg
FROM daily_signups
ORDER BY signup_date;


-- ── PART 2: Rank countries by pro-plan conversion rate ───────────────────
WITH country_stats AS (
    SELECT
        country,
        COUNT(*) AS total_users,
        SUM(CASE WHEN plan = 'pro' THEN 1 ELSE 0 END) AS pro_users,
        ROUND(100.0 * SUM(CASE WHEN plan = 'pro' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pro_conversion_pct
    FROM users
    GROUP BY country
)
SELECT
    country,
    total_users,
    pro_users,
    pro_conversion_pct,
    -- RANK (with gaps on ties) vs DENSE_RANK (no gaps) — using both to show the distinction,
    -- a detail that's easy to get wrong and often specifically probed in interviews
    RANK() OVER (ORDER BY pro_conversion_pct DESC) AS rank_with_gaps,
    DENSE_RANK() OVER (ORDER BY pro_conversion_pct DESC) AS dense_rank_no_gaps
FROM country_stats
ORDER BY pro_conversion_pct DESC;


-- ── PART 3: Days between signup and first "activated" event, per user ────
-- Common "time-to-value" metric. Uses a correlated approach via window function
-- instead of a self-join, which is both more idiomatic and faster on large tables.
SELECT
    u.user_id,
    u.signup_date,
    MIN(e.event_time) AS activated_at,
    ROUND(
        JULIANDAY(MIN(e.event_time)) - JULIANDAY(u.signup_date),
        1
    ) AS days_to_activation
FROM users u
JOIN events e ON e.user_id = u.user_id AND e.event_name = 'activated'
GROUP BY u.user_id, u.signup_date
ORDER BY days_to_activation ASC
LIMIT 20;
