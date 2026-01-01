-- src/sql/analysis/03_funnel/03_funnel_bottleneck__worst_segments_top10.sql
-- Output: (window_days=14/30) × (strict 기준) 가장 자주 병목인 step에 대해
--         전환율 최악 세그먼트 TOP 10

DECLARE MIN_DENOM INT64 DEFAULT 50;
DECLARE MIN_SESSIONS INT64 DEFAULT 100;

WITH
-- (중복 방지) frequency 쿼리의 ranked CTE까지 동일하게 재사용
activation AS (
  SELECT
    user_id,
    CASE
      WHEN has_purchase_14d THEN 'A5_purchase'
      WHEN has_checkout_14d THEN 'A4_checkout'
      WHEN has_add_to_cart_14d THEN 'A3_add_to_cart'
      WHEN has_click_14d THEN 'A2_click'
      WHEN has_view_14d THEN 'A1_view'
      ELSE 'A0_no_activity'
    END AS activation_stage_14d,
    anomaly_flag
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`
),
consistency_raw AS (
  SELECT user_id, consistency_score_v1
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`
),
consistency_nonnull AS (
  SELECT user_id, consistency_score_v1
  FROM consistency_raw
  WHERE consistency_score_v1 IS NOT NULL
),
consistency_ntile AS (
  SELECT user_id, NTILE(5) OVER (ORDER BY consistency_score_v1) AS seg5
  FROM consistency_nonnull
),
consistency AS (
  SELECT
    r.user_id,
    CASE
      WHEN n.seg5 IS NULL THEN 'C0_no_consistency_data'
      WHEN n.seg5 = 1 THEN 'C1_low_consistency'
      WHEN n.seg5 = 2 THEN 'C2'
      WHEN n.seg5 = 3 THEN 'C3_mid'
      WHEN n.seg5 = 4 THEN 'C4'
      WHEN n.seg5 = 5 THEN 'C5_high_consistency'
    END AS consistency_segment
  FROM consistency_raw r
  LEFT JOIN consistency_ntile n
    ON r.user_id = n.user_id
),
session_base AS (
  SELECT
    14 AS window_days,
    session_id,
    user_id,
    has_view, has_click, has_add_to_cart, has_checkout, has_purchase,
    strict_view, strict_click, strict_add_to_cart, strict_checkout, strict_purchase
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`
  WHERE is_in_14d
  UNION ALL
  SELECT
    30 AS window_days,
    session_id,
    user_id,
    has_view, has_click, has_add_to_cart, has_checkout, has_purchase,
    strict_view, strict_click, strict_add_to_cart, strict_checkout, strict_purchase
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`
  WHERE is_in_30d
),
base AS (
  SELECT
    s.window_days,
    a.activation_stage_14d,
    c.consistency_segment,
    s.strict_view, s.strict_click, s.strict_add_to_cart, s.strict_checkout, s.strict_purchase
  FROM session_base s
  JOIN activation a ON s.user_id = a.user_id
  LEFT JOIN consistency c ON s.user_id = c.user_id
  WHERE a.anomaly_flag = 0
),
agg AS (
  SELECT
    window_days,
    activation_stage_14d,
    consistency_segment,
    COUNT(*) AS sessions,

    COUNTIF(strict_view) AS s_view,
    COUNTIF(strict_click) AS s_click,
    COUNTIF(strict_add_to_cart) AS s_cart,
    COUNTIF(strict_checkout) AS s_checkout,
    COUNTIF(strict_purchase) AS s_purchase,

    SAFE_DIVIDE(COUNTIF(strict_click), NULLIF(COUNTIF(strict_view),0)) AS s_v2c,
    SAFE_DIVIDE(COUNTIF(strict_add_to_cart), NULLIF(COUNTIF(strict_click),0)) AS s_c2cart,
    SAFE_DIVIDE(COUNTIF(strict_checkout), NULLIF(COUNTIF(strict_add_to_cart),0)) AS s_cart2co,
    SAFE_DIVIDE(COUNTIF(strict_purchase), NULLIF(COUNTIF(strict_checkout),0)) AS s_co2p
  FROM base
  GROUP BY 1,2,3
),
step_long AS (
  SELECT
    window_days, activation_stage_14d, consistency_segment, sessions,
    'strict' AS metric_type,
    step, conv_rate, denom, num
  FROM agg,
  UNNEST([
    STRUCT('view_to_click' AS step, s_v2c AS conv_rate, s_view AS denom, s_click AS num),
    STRUCT('click_to_cart', s_c2cart, s_click, s_cart),
    STRUCT('cart_to_checkout', s_cart2co, s_cart, s_checkout),
    STRUCT('checkout_to_purchase', s_co2p, s_checkout, s_purchase)
  ])
),
ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER(
      PARTITION BY window_days, activation_stage_14d, consistency_segment, metric_type
      ORDER BY conv_rate ASC, denom DESC
    ) AS rn
  FROM step_long
  WHERE denom >= MIN_DENOM
    AND sessions >= MIN_SESSIONS
),

-- window_days별로 "가장 자주 병목 1위"인 step을 하나 고름 (strict 기준)
top_step AS (
  SELECT
    window_days,
    step AS bottleneck_step
  FROM (
    SELECT
      window_days,
      step,
      COUNT(*) AS cnt,
      ROW_NUMBER() OVER(PARTITION BY window_days ORDER BY COUNT(*) DESC) AS rnk
    FROM ranked
    WHERE rn = 1
      AND metric_type = 'strict'
    GROUP BY 1,2
  )
  WHERE rnk = 1
),

worst AS (
  SELECT
    r.window_days,
    t.bottleneck_step,
    r.activation_stage_14d,
    r.consistency_segment,
    r.conv_rate,
    (1.0 - r.conv_rate) AS dropoff_rate,
    r.denom,
    r.num,
    r.sessions,
    ROW_NUMBER() OVER(
      PARTITION BY r.window_days
      ORDER BY r.conv_rate ASC, r.denom DESC
    ) AS worst_rank
  FROM ranked r
  JOIN top_step t
    ON r.window_days = t.window_days
   AND r.step = t.bottleneck_step
  WHERE r.rn = 1
    AND r.metric_type = 'strict'
)

SELECT *
FROM worst
WHERE worst_rank <= 10
ORDER BY window_days, worst_rank;

