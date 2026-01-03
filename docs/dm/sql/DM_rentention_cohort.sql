CREATE OR REPLACE TABLE `eternal-argon-479503-e8.ecommerce_dm.DM_retention_cohort`
PARTITION BY cohort_month
CLUSTER BY day_index, cohort_month AS

--CREATE OR REPLACE TABLE `eternal-argon-479503-e8.ecommerce_dm.DM_retention_cohort`
--PARTITION BY cohort_month
--CLUSTER BY day_index, cohort_month AS

/* =========================================================
  DM_retention_cohort
  - Grain: cohort_month × day_index (0..180)
  - Active definition: at least 1 session on that day
  - Output: cohort_size, active_users, retention_rate
========================================================= */

WITH users_base AS 
(
  SELECT user_id,
         DATE(signup_date) AS signup_date,
         DATE_TRUNC(DATE(signup_date), MONTH) AS cohort_month
  
  FROM `eternal-argon-479503-e8.ecommerce.users`
),

bounds AS 
(
  SELECT MIN(signup_date) AS min_signup,
         MAX(signup_date) AS max_signup
  
  FROM users_base
),

-- bounds 사용해서 session 기간 제한: max_signup + 180d
sessions_filt AS 
(
  SELECT s.user_id,
         DATE(CAST(s.session_start_ts AS TIMESTAMP)) AS session_date
  
  FROM `eternal-argon-479503-e8.ecommerce.sessions` s, bounds
  
  WHERE DATE(CAST(s.session_start_ts AS TIMESTAMP)) >= bounds.min_signup
    AND DATE(CAST(s.session_start_ts AS TIMESTAMP)) < DATE_ADD(bounds.max_signup, INTERVAL 180 DAY)
),

-- user별 180 윈도우 내에서 활성일만 추출
user_active_days AS 
(
  SELECT DISTINCT u.user_id,
         u.cohort_month,
         u.signup_date,
         DATE_DIFF(sf.session_date, u.signup_date, DAY) AS day_index
  
  FROM users_base u INNER JOIN sessions_filt sf
         ON sf.user_id = u.user_id
         AND sf.session_date >= u.signup_date
         AND sf.session_date < DATE_ADD(u.signup_date, INTERVAL 181 DAY) -- day 180 포함
),

-- Cohort size
cohort_size AS 
(
  SELECT cohort_month,
         COUNT(*) AS cohort_size
  
  FROM users_base
  
  GROUP BY cohort_month
),

-- cohort × day_index별 active user 집계
active_by_day AS 
(
  SELECT cohort_month,
         day_index,
         COUNT(DISTINCT user_id) AS active_users
  
  FROM user_active_days
  
  WHERE day_index BETWEEN 0 AND 180
  
  GROUP BY cohort_month, day_index
),

-- 0~180 day spine 생성 (cohort별로 빠진 day도 0으로 채우기)
day_spine AS 
(
  SELECT day_index
  FROM UNNEST(GENERATE_ARRAY(0, 180)) AS day_index
),

cohort_day_grid AS 
(
  SELECT s.cohort_month,
         d.day_index,
         s.cohort_size
  
  FROM cohort_size s
  
  CROSS JOIN day_spine d
)

-- FINAL: retention_rate = active_users / cohort_size
SELECT g.cohort_month,
       g.day_index,
       g.cohort_size,
       IFNULL(a.active_users, 0) AS active_users,
       SAFE_DIVIDE(IFNULL(a.active_users, 0), g.cohort_size) AS retention_rate

FROM cohort_day_grid g LEFT JOIN active_by_day a
      ON g.cohort_month = a.cohort_month
      AND g.day_index = a.day_index;
