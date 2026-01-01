-- day index 범위 체크
SELECT
COUNTIF(day_index < 0 OR day_index > 180) AS out_of_range
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_retention_cohort`;

-- cohort_month 별 row 체크 
SELECT
  cohort_month,
  COUNT(*) AS rows_per_cohort
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_retention_cohort`
GROUP BY cohort_month
ORDER BY cohort_month;

-- retention_rate 범위 
SELECT
  COUNTIF(retention_rate < 0 OR retention_rate > 1) AS out_of_range,
  MIN(retention_rate) AS min_val,
  MAX(retention_rate) AS max_val
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_retention_cohort`;


-- active_users <= cohort_size 
SELECT
  COUNTIF(active_users > cohort_size) AS viol
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_retention_cohort`;

-- day_index = 0 에서 active_users <= cohort_size 
SELECT
  cohort_month,
  cohort_size,
  active_users,
  retention_rate
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_retention_cohort`
WHERE day_index = 0
ORDER BY cohort_month;

-- missing grid check
SELECT
  COUNTIF(cohort_month IS NULL OR day_index IS NULL OR cohort_size IS NULL OR active_users IS NULL OR retention_rate IS NULL) AS null_rows
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_retention_cohort`;
