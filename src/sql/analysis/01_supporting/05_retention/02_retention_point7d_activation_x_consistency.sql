/* =========================================================
Retention-Point Checkpoints (no new DM, CTE only)
- 목적: Activation(14d) × Consistency가 "장기 잔존"에 미치는 영향 요약
- 정의: checkpoint 직전 7일 동안 1회라도 session 있으면 active
  * D30: day 23~29
  * D60: day 53~59
  * D90: day 83~89
  * D180 proxy: day 173~179 (last week)
========================================================= */

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
        
         anomaly_flag,    
         DATE(signup_date) AS signup_date
  
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

sessions AS 
(
  SELECT user_id,
         DATE(CAST(session_start_ts AS TIMESTAMP)) AS session_date
  
  FROM `eternal-argon-479503-e8.ecommerce.sessions`
),

user_point_flags AS 
(
  SELECT a.user_id,
         a.activation_stage_14d,
         c.consistency_segment,

         MAX(IF(DATE_DIFF(s.session_date, a.signup_date, DAY) BETWEEN 23 AND 29, 1, 0)) AS active_w30,
         MAX(IF(DATE_DIFF(s.session_date, a.signup_date, DAY) BETWEEN 53 AND 59, 1, 0)) AS active_w60,
         MAX(IF(DATE_DIFF(s.session_date, a.signup_date, DAY) BETWEEN 83 AND 89, 1, 0)) AS active_w90,
         MAX(IF(DATE_DIFF(s.session_date, a.signup_date, DAY) BETWEEN 173 AND 179, 1, 0)) AS active_last_week_173_179

  FROM activation a LEFT JOIN consistency c 
    ON a.user_id = c.user_id LEFT JOIN sessions s 
      ON a.user_id = s.user_id

  WHERE a.anomaly_flag = 0

  GROUP BY 1,2,3
)

SELECT activation_stage_14d,
       consistency_segment,
       COUNT(*) AS users,

       AVG(active_w30) AS retention_w30,
       AVG(active_w60) AS retention_w60,
       AVG(active_w90) AS retention_w90,
       AVG(active_last_week_173_179) AS retention_last_week_173_179

FROM user_point_flags

WHERE consistency_segment != 'C0_no_consistency_data'

GROUP BY 1,2

ORDER BY activation_stage_14d, consistency_segment;