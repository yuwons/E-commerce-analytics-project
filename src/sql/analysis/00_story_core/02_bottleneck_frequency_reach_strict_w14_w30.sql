-- src/sql/analysis/03_funnel/03_funnel_bottleneck__frequency.sql
-- Output: window_days × metric_type(strict/reach) × bottleneck_step 별 빈도/평균 전환율

DECLARE MIN_DENOM INT64 DEFAULT 50;     -- step 분모 세션 최소치(너무 작으면 노이즈)
DECLARE MIN_SESSIONS INT64 DEFAULT 100; -- 세그먼트 전체 세션 최소치

WITH
activation AS 
(
  SELECT user_id,
         CASE WHEN has_purchase_14d THEN 'A5_purchase'
              WHEN has_checkout_14d THEN 'A4_checkout'
              WHEN has_add_to_cart_14d THEN 'A3_add_to_cart'
              WHEN has_click_14d THEN 'A2_click'
              WHEN has_view_14d THEN 'A1_view'
         ELSE 'A0_no_activity'
         END AS activation_stage_14d,
    
    anomaly_flag
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`
),
consistency_raw AS 
(
  SELECT user_id,
         consistency_score_v1

  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`
),
consistency_nonnull AS 
(
  SELECT user_id,
         consistency_score_v1
  
  FROM consistency_raw
  
  WHERE consistency_score_v1 IS NOT NULL
),
consistency_ntile AS 
(
  SELECT user_id,
         NTILE(5) OVER (ORDER BY consistency_score_v1) AS seg5
  
  FROM consistency_nonnull
),
consistency AS 
(
  SELECT r.user_id,
         CASE WHEN n.seg5 IS NULL THEN 'C0_no_consistency_data'
              WHEN n.seg5 = 1 THEN 'C1_low_consistency'
              WHEN n.seg5 = 2 THEN 'C2'
              WHEN n.seg5 = 3 THEN 'C3_mid'
              WHEN n.seg5 = 4 THEN 'C4'
              WHEN n.seg5 = 5 THEN 'C5_high_consistency'
         END AS consistency_segment
  
  FROM consistency_raw r LEFT JOIN consistency_ntile n
    ON r.user_id = n.user_id
),
session_base AS 
(
  SELECT 14 AS window_days,
         session_id,
         user_id,
         -- reach check
         has_view,
         has_click,
         has_add_to_cart,
         has_checkout,
         has_purchase,
         --strict check
         strict_view,
         strict_click,
         strict_add_to_cart,
         strict_checkout,
         strict_purchase

  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`

  WHERE is_in_14d

  UNION ALL
  SELECT 30 AS window_days,
         session_id,
         user_id,
         -- reach check
         has_view,
         has_click,
         has_add_to_cart,
         has_checkout,
         has_purchase,
         -- strict check
         strict_view,
         strict_click,
         strict_add_to_cart,
         strict_checkout,
         strict_purchase
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`
  
  WHERE is_in_30d
),
base AS 
(
  SELECT s.window_days,
         a.activation_stage_14d,
         c.consistency_segment,

         s.has_view,
         s.has_click,
         s.has_add_to_cart,
         s.has_checkout,
         s.has_purchase,
         
         s.strict_view,
         s.strict_click,
         s.strict_add_to_cart,
         s.strict_checkout,
         s.strict_purchase

  FROM session_base s JOIN activation a 
    ON s.user_id = a.user_id LEFT JOIN consistency c 
      ON s.user_id = c.user_id
  
  WHERE a.anomaly_flag = 0

),
agg AS 
(
  SELECT window_days,
         activation_stage_14d,
         consistency_segment,
         COUNT(*) AS sessions,

         --reach count
         COUNTIF(has_view) AS r_view,
         COUNTIF(has_click) AS r_click,
         COUNTIF(has_add_to_cart) AS r_cart,
         COUNTIF(has_checkout) AS r_checkout,
         COUNTIF(has_purchase) AS r_purchase,
         
         -- reach conversion rate 
         SAFE_DIVIDE(COUNTIF(has_click), NULLIF(COUNTIF(has_view),0)) AS r_v2c,
         SAFE_DIVIDE(COUNTIF(has_add_to_cart), NULLIF(COUNTIF(has_click),0)) AS r_c2cart,
         SAFE_DIVIDE(COUNTIF(has_checkout), NULLIF(COUNTIF(has_add_to_cart),0)) AS r_cart2co,
         SAFE_DIVIDE(COUNTIF(has_purchase), NULLIF(COUNTIF(has_checkout),0)) AS r_co2p,

         -- strict count
         COUNTIF(strict_view) AS s_view,
         COUNTIF(strict_click) AS s_click,
         COUNTIF(strict_add_to_cart) AS s_cart,
         COUNTIF(strict_checkout) AS s_checkout,
         COUNTIF(strict_purchase) AS s_purchase,
         
         -- strict conversion rate
         SAFE_DIVIDE(COUNTIF(strict_click), NULLIF(COUNTIF(strict_view),0)) AS s_v2c,
         SAFE_DIVIDE(COUNTIF(strict_add_to_cart), NULLIF(COUNTIF(strict_click),0)) AS s_c2cart,
         SAFE_DIVIDE(COUNTIF(strict_checkout), NULLIF(COUNTIF(strict_add_to_cart),0)) AS s_cart2co,
         SAFE_DIVIDE(COUNTIF(strict_purchase), NULLIF(COUNTIF(strict_checkout),0)) AS s_co2p

  FROM base

  GROUP BY 1,2,3
),
step_long AS 
(
  -- reach
  SELECT window_days,
         activation_stage_14d,
         consistency_segment,
         sessions,
         'reach' AS metric_type,
         step,
         conv_rate,
         denom,
         num

  FROM agg,
  UNNEST([
    STRUCT('view_to_click' AS step, r_v2c AS conv_rate, r_view AS denom, r_click AS num),
    STRUCT('click_to_cart', r_c2cart, r_click, r_cart),
    STRUCT('cart_to_checkout', r_cart2co, r_cart, r_checkout),
    STRUCT('checkout_to_purchase', r_co2p, r_checkout, r_purchase)
  ])
  UNION ALL
  -- strict
  SELECT window_days,
         activation_stage_14d,
         consistency_segment,
         sessions,
         'strict' AS metric_type,
         step,
         conv_rate,
         denom,
         num
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
)

SELECT window_days,
       metric_type,
       step AS bottleneck_step,
       COUNT(*) AS segment_cells,                          -- (activation×consistency) 셀 개수
       AVG(conv_rate) AS avg_bottleneck_conv_rate,
       APPROX_QUANTILES(conv_rate, 100)[OFFSET(50)] AS median_bottleneck_conv_rate

FROM ranked

WHERE rn = 1

GROUP BY 1,2,3

ORDER BY window_days, metric_type, segment_cells DESC;

