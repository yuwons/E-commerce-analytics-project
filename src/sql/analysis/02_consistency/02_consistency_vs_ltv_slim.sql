-- 02_consistency/02_consistency_vs_ltv__SLIM.sql
-- Same segmentation logic as FULL, output reduced

WITH ltv AS 
(
  SELECT user_id,
         anomaly_flag,
         orders_180d,
         revenue_180d,
         has_purchase_180d,
         promo_orders_180d,
         promo_revenue_180d

  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`
),
cons AS
(
  SELECT user_id,
         consistency_score_v1

  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`
),
base AS 
(
  SELECT l.user_id,
         l.orders_180d,
         l.revenue_180d,
         l.has_purchase_180d,
         l.promo_orders_180d,
         l.promo_revenue_180d,
         c.consistency_score_v1

  FROM ltv l LEFT JOIN cons c
    ON l.user_id = c.user_id

  WHERE l.anomaly_flag = 0
),
cons_non_null AS 
(
  SELECT user_id,
         NTILE(5) OVER (ORDER BY consistency_score_v1) AS q5

  FROM base

  WHERE consistency_score_v1 IS NOT NULL
),
segmented AS 
(
  SELECT b.*,
         CASE WHEN b.consistency_score_v1 IS NULL THEN 'C0_no_consistency_data'
              WHEN n.q5 = 1 THEN 'C1_low_consistency'
              WHEN n.q5 = 2 THEN 'C2'
              WHEN n.q5 = 3 THEN 'C3_mid'
              WHEN n.q5 = 4 THEN 'C4'
              WHEN n.q5 = 5 THEN 'C5_high_consistency'
         ELSE 'C0_no_consistency_data'
         END AS consistency_segment
  
  FROM base b LEFT JOIN cons_non_null n 
    ON b.user_id = n.user_id
)

SELECT consistency_segment,
       COUNT(*) AS users,
       AVG(CAST(has_purchase_180d AS INT64)) AS purchase_rate_180d,
       AVG(revenue_180d) AS avg_revenue_180d,
       APPROX_QUANTILES(revenue_180d, 100)[OFFSET(50)] AS median_revenue_180d,
       AVG(orders_180d) AS avg_orders_180d,
       SAFE_DIVIDE(SUM(promo_revenue_180d), NULLIF(SUM(revenue_180d), 0)) AS promo_revenue_share_180d

FROM segmented

GROUP BY 1

ORDER BY CASE consistency_segment
              WHEN 'C0_no_consistency_data' THEN 0
              WHEN 'C1_low_consistency' THEN 1
              WHEN 'C2' THEN 2
              WHEN 'C3_mid' THEN 3
              WHEN 'C4' THEN 4
              WHEN 'C5_high_consistency' THEN 5
         ELSE 99
         END;


  SELECT
  plan,
  status,
  COUNT(*) AS users,
  COUNTIF(monthly_fee > 0) AS paid_users,
  MIN(start_date) AS min_start,
  MAX(start_date) AS max_start
FROM `eternal-argon-479503-e8.ecommerce.subscriptions`
GROUP BY 1,2
ORDER BY users DESC;

