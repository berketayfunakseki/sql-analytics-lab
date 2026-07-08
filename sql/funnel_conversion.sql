-- funnel_conversion.sql
-- Step-by-step conversion rate through the signup → subscribed funnel.
-- Uses window functions (LAG) to compute step-over-step drop-off, not just
-- raw counts — the drop-off percentage is what actually drives product decisions.

WITH funnel_counts AS (
    SELECT
        event_name,
        COUNT(DISTINCT user_id) AS users_reached
    FROM events
    WHERE event_name IN ('signup', 'onboarding_complete', 'first_action', 'activated', 'subscribed')
    GROUP BY event_name
),
ordered AS (
    -- explicit ordering since funnel steps have a defined sequence, not alphabetical
    SELECT
        fc.*,
        CASE event_name
            WHEN 'signup' THEN 1
            WHEN 'onboarding_complete' THEN 2
            WHEN 'first_action' THEN 3
            WHEN 'activated' THEN 4
            WHEN 'subscribed' THEN 5
        END AS step_order
    FROM funnel_counts fc
)
SELECT
    step_order,
    event_name AS funnel_step,
    users_reached,
    -- LAG window function: compare each step to the one before it
    LAG(users_reached) OVER (ORDER BY step_order) AS prev_step_users,
    ROUND(
        100.0 * users_reached / NULLIF(LAG(users_reached) OVER (ORDER BY step_order), 0),
        1
    ) AS step_over_step_conversion_pct,
    -- also compute conversion relative to the very first step (top of funnel)
    ROUND(
        100.0 * users_reached / FIRST_VALUE(users_reached) OVER (ORDER BY step_order),
        1
    ) AS overall_conversion_from_signup_pct
FROM ordered
ORDER BY step_order;
