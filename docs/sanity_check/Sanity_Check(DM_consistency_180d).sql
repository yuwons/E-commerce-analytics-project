--# 테이블 행 체크 users 랑 같은 수가 나와야 통과
SELECT COUNT(*) AS dm_rows
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`;


--# rowcount = users rowcount
SELECT
  (SELECT COUNT(*) FROM `eternal-argon-479503-e8.ecommerce.users`) AS users_rows,
  (SELECT COUNT(*) FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`) AS dm_rows;

--# user_id 유일성 중복 0 
SELECT
  COUNT(*) AS rows_num,
  COUNT(DISTINCT user_id) AS distinct_users,
  COUNT(*) - COUNT(DISTINCT user_id) AS dup_rows
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`;

--# Active_days_180d 범위체크 (0~180)
SELECT
  COUNTIF(active_days_180d < 0 OR active_days_180d > 180) AS out_of_range,
  MIN(active_days_180d) AS min_val,
  MAX(active_days_180d) AS max_val
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`;


--# intervisit 지표는 active_days < 2 면 Null 
SELECT
  COUNTIF(active_days_180d < 2 AND intervisit_mean_180d IS NOT NULL) AS viol_mean,
  COUNTIF(active_days_180d < 2 AND intervisit_std_180d IS NOT NULL)  AS viol_std,
  COUNTIF(active_days_180d < 2 AND intervisit_cv_180d IS NOT NULL)   AS viol_cv
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`;

--# repurtchase 단조성 : 30 -> 60 -> 90 위배 0
SELECT
  COUNTIF(repurchase_30d AND NOT repurchase_60d) AS viol_30_60,
  COUNTIF(repurchase_60d AND NOT repurchase_90d) AS viol_60_90
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`;


--# repeat_interval_*는 orders<2면 NULL
SELECT
  COUNTIF(orders_180d < 2 AND repeat_interval_mean_180d IS NOT NULL) AS viol_mean,
  COUNTIF(orders_180d < 2 AND repeat_interval_std_180d IS NOT NULL)  AS viol_std,
  COUNTIF(orders_180d < 2 AND repeat_interval_cv_180d IS NOT NULL)   AS viol_cv
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`;

--# first_order_date_180d 정합성 
SELECT
  COUNTIF(orders_180d = 0 AND first_order_date_180d IS NOT NULL) AS viol_no_orders,
  COUNTIF(orders_180d > 0 AND first_order_date_180d IS NULL)     AS viol_has_orders
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`;


--# weekly_active_ratio_180d 
SELECT
  COUNTIF(weekly_active_ratio_180d < 0 OR weekly_active_ratio_180d > 1) AS out_of_range,
  MIN(weekly_active_ratio_180d) AS min_val,
  MAX(weekly_active_ratio_180d) AS max_val
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`;



