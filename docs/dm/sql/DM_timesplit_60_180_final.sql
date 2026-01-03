CREATE OR REPLACE TABLE `eternal-argon-479503-e8.ecommerce_dm.DM_timesplit_60_180_final`
PARTITION BY signup_date
CLUSTER BY user_id AS

WITH user_base AS 
(
  SELECT user_id,
         signup_date,
         device,
         region,
         marketing_source,
         anomaly_flag,

         has_view_14d,
         has_click_14d,
         has_add_to_cart_14d,
         has_checkout_14d,
         has_purchase_14d

  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`
),

bounds AS 
(
  SELECT MIN(signup_date) AS min_signup,
         MAX(signup_date) AS max_signup
  
  FROM user_base
),


--# Activation stage (14d)

activation AS 
(
  SELECT u.*,
         CASE WHEN has_purchase_14d THEN 'A5_purchase'
              WHEN has_checkout_14d THEN 'A4_checkout'
              WHEN has_add_to_cart_14d THEN 'A3_add_to_cart'
              WHEN has_click_14d THEN 'A2_click'
              WHEN has_view_14d THEN 'A1_view'
              ELSE 'A0_no_activity'
         END AS activation_stage_14d
  
  FROM user_base u
),


--# Sessions filtered (global scan pruning)

sessions_filt AS 
(
  SELECT user_id,
         session_id,
         DATE(CAST(session_start_ts AS TIMESTAMP)) AS session_date
  
  FROM `eternal-argon-479503-e8.ecommerce.sessions`, bounds
  
  WHERE DATE(CAST(session_start_ts AS TIMESTAMP)) >= bounds.min_signup
    AND DATE(CAST(session_start_ts AS TIMESTAMP)) < DATE_ADD(bounds.max_signup, INTERVAL 180 DAY)
),

--# Observation window: 0~60d (0~59)
sessions_obs_60d AS 
(
  SELECT u.user_id,
         u.signup_date,
         s.session_id,
         s.session_date
  
  FROM activation u LEFT JOIN sessions_filt s
        ON s.user_id = u.user_id
        AND s.session_date >= u.signup_date
        AND s.session_date < DATE_ADD(u.signup_date, INTERVAL 60 DAY)
),

session_basic_60d AS 
(
  SELECT user_id,
         ANY_VALUE(signup_date) AS signup_date,
         COUNT(DISTINCT session_id) AS session_cnt_obs_60d,
         COUNT(DISTINCT session_date) AS active_days_obs_60d
  
  FROM sessions_obs_60d
  
  GROUP BY user_id
),

sessions_days_60d AS 
(
  SELECT DISTINCT user_id,
                  signup_date,
                  session_date
  
  FROM sessions_obs_60d
  
  WHERE session_date IS NOT NULL
),

intervisit_60d AS 
(
  SELECT user_id,
         DATE_DIFF(
           session_date,
           LAG(session_date) OVER (PARTITION BY user_id ORDER BY session_date),
           DAY
         ) AS intervisit_days

  FROM sessions_days_60d
),

intervisit_stats_60d AS 
(
  SELECT u.user_id,
         AVG(i.intervisit_days) AS intervisit_mean_obs_60d,
         APPROX_QUANTILES(i.intervisit_days, 101)[OFFSET(50)] AS intervisit_median_obs_60d,
         STDDEV_SAMP(i.intervisit_days) AS intervisit_std_obs_60d,
         SAFE_DIVIDE(
           STDDEV_SAMP(i.intervisit_days),
           NULLIF(AVG(i.intervisit_days), 0)
         ) AS intervisit_cv_obs_60d
  
  FROM activation u LEFT JOIN intervisit_60d i
      ON i.user_id = u.user_id
  
  WHERE i.intervisit_days IS NOT NULL
  
  GROUP BY u.user_id
),

weekly_stats_60d AS 
(
  SELECT u.user_id,
         COUNT(DISTINCT DATE_TRUNC(d.session_date, WEEK(MONDAY))) AS active_weeks_obs_60d,
         SAFE_DIVIDE(
         COUNT(DISTINCT DATE_TRUNC(d.session_date, WEEK(MONDAY))),
           ARRAY_LENGTH(
             GENERATE_DATE_ARRAY(
               DATE_TRUNC(u.signup_date, WEEK(MONDAY)),
               DATE_TRUNC(DATE_ADD(u.signup_date, INTERVAL 59 DAY), WEEK(MONDAY)),
               INTERVAL 7 DAY
             )
           )
         ) AS weekly_active_ratio_obs_60d
  
  FROM activation u LEFT JOIN sessions_days_60d d
      ON d.user_id = u.user_id
  
  GROUP BY u.user_id, u.signup_date
),

combined_obs AS 
(
  SELECT u.user_id,
         u.signup_date,

         sb.session_cnt_obs_60d,
         sb.active_days_obs_60d,

         iv.intervisit_mean_obs_60d,
         iv.intervisit_median_obs_60d,
         iv.intervisit_std_obs_60d,
         iv.intervisit_cv_obs_60d,

         ws.active_weeks_obs_60d,
         ws.weekly_active_ratio_obs_60d

  FROM activation u LEFT JOIN session_basic_60d sb 
      ON u.user_id = sb.user_id LEFT JOIN intervisit_stats_60d iv 
        ON u.user_id = iv.user_id LEFT JOIN weekly_stats_60d ws 
          ON u.user_id = ws.user_id
),
--# Consistency score (z(active_days) - z(intervisit_cv))
consistency_obs AS 
(
  SELECT c.*,
         (
           SAFE_DIVIDE(
             c.active_days_obs_60d - AVG(c.active_days_obs_60d) OVER(),
             NULLIF(STDDEV_SAMP(c.active_days_obs_60d) OVER(), 0)
           )
           -
           SAFE_DIVIDE(
             c.intervisit_cv_obs_60d - AVG(c.intervisit_cv_obs_60d) OVER(),
             NULLIF(STDDEV_SAMP(c.intervisit_cv_obs_60d) OVER(), 0)
           )
         ) AS consistency_score_obs_60d
  
  FROM combined_obs c
),

--# Consistency segment C1~C5 (obs score quintile)
--# score NULL(세션 2회 미만 등)은 보수적으로 C1 처리
consistency_segment AS 
(
  SELECT x.*,
        CASE WHEN x.consistency_score_obs_60d IS NULL THEN 'C1'
             ELSE CONCAT('C', CAST(NTILE(5) OVER (ORDER BY x.consistency_score_obs_60d) AS STRING))
        END AS consistency_segment_obs_60d
  
  FROM consistency_obs x
),
--# Performance window outcomes: 60~180d (DM_ltv_180d style)
orders_filt AS 
(
  SELECT o.user_id,
         o.order_id,
         DATE(CAST(o.order_ts AS TIMESTAMP)) AS order_date
  
  FROM `eternal-argon-479503-e8.ecommerce.orders` o, bounds
  
  WHERE DATE(CAST(o.order_ts AS TIMESTAMP)) >= bounds.min_signup
    AND DATE(CAST(o.order_ts AS TIMESTAMP)) <  DATE_ADD(bounds.max_signup, INTERVAL 180 DAY)
),

orders_perf_60_180 AS 
(
  SELECT u.user_id,
         u.signup_date,
         o.order_id,
         o.order_date
  
  FROM activation u LEFT JOIN orders_filt o
      ON o.user_id = u.user_id
      AND o.order_date >= DATE_ADD(u.signup_date, INTERVAL 60 DAY)
      AND o.order_date <  DATE_ADD(u.signup_date, INTERVAL 180 DAY)
),

order_rev AS 
(
  SELECT oi.order_id,
         SUM(oi.line_amount) AS order_revenue
  
  FROM `eternal-argon-479503-e8.ecommerce.order_items` oi
  
  GROUP BY oi.order_id
),

orders_with_rev AS 
(
  SELECT o.user_id,
         o.signup_date,
         o.order_id,
         o.order_date,
         r.order_revenue
  
  FROM orders_perf_60_180 o LEFT JOIN order_rev r
      ON r.order_id = o.order_id
),

outcome_60_180 AS 
(
  SELECT u.user_id,
         COUNT(DISTINCT o.order_id) AS orders_60_180,
         SUM(IFNULL(o.order_revenue, 0)) AS revenue_60_180,
         SAFE_DIVIDE(
           SUM(IFNULL(o.order_revenue, 0)),
           NULLIF(COUNT(DISTINCT o.order_id), 0)
         ) AS aov_60_180
  
  FROM activation u LEFT JOIN orders_with_rev o
      ON o.user_id = u.user_id
  
  GROUP BY u.user_id
),

--#  Retention: last 7 days of 0~180 window (day_index 174~180)
--   DM_retention_cohort의 day 180 포함 방식과 정합
retention_last_week AS 
(
  SELECT u.user_id,
         COUNTIF(
           s.session_date >= DATE_ADD(u.signup_date, INTERVAL 174 DAY)
           AND s.session_date <  DATE_ADD(u.signup_date, INTERVAL 181 DAY)
         ) > 0 AS retention_last_week_180d
  
  FROM activation u LEFT JOIN sessions_filt s
      ON s.user_id = u.user_id
  
  GROUP BY u.user_id
)

SELECT a.user_id,
       a.signup_date,

       -- controls (방어/확장용)
       a.device,
       a.region,
       a.marketing_source,
       a.anomaly_flag,

       -- Activation 14d
       a.has_view_14d,
       a.has_click_14d,
       a.has_add_to_cart_14d,
       a.has_checkout_14d,
       a.has_purchase_14d,
       a.activation_stage_14d,

       -- Observation Consistency (0~60d)
       c.session_cnt_obs_60d,
       c.active_days_obs_60d,
       c.intervisit_mean_obs_60d,
       c.intervisit_median_obs_60d,
       c.intervisit_std_obs_60d,
       c.intervisit_cv_obs_60d,
       c.active_weeks_obs_60d,
       c.weekly_active_ratio_obs_60d,
       c.consistency_score_obs_60d,
       c.consistency_segment_obs_60d,

       -- Performance Outcomes (60~180d)
       o.orders_60_180,
       o.revenue_60_180,
       (o.orders_60_180 > 0) AS has_purchase_60_180,
       o.aov_60_180,

       -- Retention
       r.retention_last_week_180d

FROM activation a LEFT JOIN consistency_segment c
    ON a.user_id = c.user_id LEFT JOIN outcome_60_180 o
      ON a.user_id = o.user_id LEFT JOIN retention_last_week r
        ON a.user_id = r.user_id
;
