-- cohort_retention.sql
-- Weekly retention by signup cohort: of users who signed up in week W,
-- what % were still active in week W, W+1, W+2, ... after signup?
-- This is one of the most commonly asked SQL analytics questions in DS interviews
-- (Google, Meta, Amazon all ask a version of "compute N-week retention by cohort").

WITH user_cohort AS (
    SELECT
        user_id,
        -- bucket each user into their signup week (cohort)
        DATE(signup_date, 'weekday 0', '-6 days') AS cohort_week
    FROM users
),
activity AS (
    -- any 'session' event counts as "active" that week (excludes funnel/onboarding events,
    -- which are one-time by definition and would inflate retention artificially)
    SELECT
        user_id,
        DATE(event_time, 'weekday 0', '-6 days') AS activity_week
    FROM events
    WHERE event_name = 'session'
    GROUP BY user_id, activity_week
),
cohort_activity AS (
    SELECT
        uc.cohort_week,
        uc.user_id,
        a.activity_week,
        -- week number relative to cohort start: 0 = signup week, 1 = one week later, etc.
        CAST((JULIANDAY(a.activity_week) - JULIANDAY(uc.cohort_week)) / 7 AS INTEGER) AS week_number
    FROM user_cohort uc
    JOIN activity a ON a.user_id = uc.user_id
    WHERE a.activity_week >= uc.cohort_week
),
cohort_size AS (
    SELECT cohort_week, COUNT(DISTINCT user_id) AS cohort_users
    FROM user_cohort
    GROUP BY cohort_week
)
SELECT
    ca.cohort_week,
    cs.cohort_users,
    ca.week_number,
    COUNT(DISTINCT ca.user_id) AS active_users,
    ROUND(100.0 * COUNT(DISTINCT ca.user_id) / cs.cohort_users, 1) AS retention_pct
FROM cohort_activity ca
JOIN cohort_size cs ON cs.cohort_week = ca.cohort_week
WHERE ca.week_number BETWEEN 0 AND 6   -- first 6 weeks post-signup
GROUP BY ca.cohort_week, ca.week_number
ORDER BY ca.cohort_week, ca.week_number;
