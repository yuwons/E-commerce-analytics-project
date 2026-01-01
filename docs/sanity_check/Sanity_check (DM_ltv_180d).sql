-- user 수랑 같아야 ok 

SELECT
  (SELECT COUNT(*) FROM `eternal-argon-479503-e8.ecommerce.users`) AS users_rows,
  (SELECT COUNT(*) FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`) AS dm_rows;

-- user_id duplicate 체크 
SELECT
  COUNT(*) AS rows_num,
  COUNT(DISTINCT user_id) AS distinct_users,
  COUNT(*) - COUNT(DISTINCT user_id) AS dup_rows
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`;

-- 만약 order 가 없고 revenue 가없으면 has_purchase = false 그리고 first_order_date NULL
SELECT
  COUNTIF(orders_180d = 0 AND revenue_180d != 0) AS viol_rev,
  COUNTIF(orders_180d = 0 AND has_purchase_180d) AS viol_flag,
  COUNTIF(orders_180d = 0 AND first_order_date_180d IS NOT NULL) AS viol_first_date
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`;

-- 만약 order 가 있다면 first_order_date should have value in it
SELECT
  COUNTIF(orders_180d > 0 AND first_order_date_180d IS NULL) AS viol_missing_first_date
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`;

-- promo_revenue ≤ revenue / promo_orders ≤ orders 
SELECT
  COUNTIF(promo_revenue_180d > revenue_180d) AS viol_promo_rev,
  COUNTIF(promo_orders_180d > orders_180d) AS viol_promo_orders
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`;

-- AOV 정의 체크 (orders=0 이면 aov NULL, orders>0이면 revenue/orders)
SELECT
  COUNTIF(orders_180d = 0 AND aov_180d IS NOT NULL) AS viol_aov_when_zero_orders,
  COUNTIF(orders_180d > 0 AND ABS(aov_180d - (revenue_180d / orders_180d)) > 0.01) AS viol_aov_mismatch
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`;


-- 분포 체크
SELECT
  MIN(revenue_180d) AS min_rev,
  MAX(revenue_180d) AS max_rev,
  APPROX_QUANTILES(revenue_180d, 11) AS rev_deciles,
  AVG(revenue_180d) AS avg_rev
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`;




