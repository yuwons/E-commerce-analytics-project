-- 04_segment_deepdive/01_activation_x_consistency_x_ltv__SLIM.sql
-- (FULL과 동일 로직) + Output만 슬림

WITH ltv AS 
(
  SELECT user_id,
         signup_date,
         anomaly_flag,
         orders_180d,
         revenue_180d,
         has_purchase_180d,
         promo_revenue_180d

  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`
),
activation AS 
(
  SELECT user_id,
         CASE WHEN has_purchase_14d THEN 'A5_purchase'
              WHEN has_checkout_14d THEN 'A4_checkout'
              WHEN has_add_to_cart_14d THEN 'A3_add_to_cart'
              WHEN has_click_14d THEN 'A2_click'
              WHEN has_view_14d THEN 'A1_view'
         ELSE 'A0_no_activity'
         END AS activation_stage_14d
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`
),
consistency_raw AS 
(
  SELECT user_id,
         consistency_score_v1
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`
),
consistency_scored_nonnull AS 
(
  SELECT user_id,
         consistency_score_v1
  
  FROM consistency_raw
  
  WHERE consistency_score_v1 IS NOT NULL
),
consistency_segment_nonnull AS 
(
  SELECT user_id,
         NTILE(5) OVER (ORDER BY consistency_score_v1) AS seg5
  
  FROM consistency_scored_nonnull
),
consistency AS 
(
  SELECT r.user_id,
         CASE WHEN s.seg5 IS NULL THEN 'C0_no_consistency_data'
              WHEN s.seg5 = 1 THEN 'C1_low_consistency'
              WHEN s.seg5 = 2 THEN 'C2'
              WHEN s.seg5 = 3 THEN 'C3_mid'
              WHEN s.seg5 = 4 THEN 'C4'
              WHEN s.seg5 = 5 THEN 'C5_high_consistency'
         END AS consistency_segment
  
  FROM consistency_raw r LEFT JOIN consistency_segment_nonnull s 
        ON r.user_id = s.user_id
),
base AS 
(
  SELECT l.user_id,
         l.anomaly_flag,
         l.orders_180d,
         l.revenue_180d,
         l.has_purchase_180d,
         l.promo_revenue_180d,
         a.activation_stage_14d,
         c.consistency_segment
  
  FROM ltv l LEFT JOIN activation a 
        ON l.user_id = a.user_id LEFT JOIN consistency c 
            ON l.user_id = c.user_id 
)

SELECT activation_stage_14d,
       consistency_segment,
       COUNT(*) AS users,
       AVG(CAST(has_purchase_180d AS INT64)) AS purchase_rate_180d,
       AVG(orders_180d) AS avg_orders_180d,
       AVG(revenue_180d) AS avg_revenue_180d,
       APPROX_QUANTILES(revenue_180d, 100)[OFFSET(50)] AS median_revenue_180d,
       SAFE_DIVIDE(SUM(promo_revenue_180d), NULLIF(SUM(revenue_180d), 0)) AS promo_revenue_share

FROM base

WHERE anomaly_flag = 0

GROUP BY 1,2

ORDER BY activation_stage_14d,
         consistency_segment
