/* =========================================================
[Retention-1] Checkpoints retention by Activation×Consistency
- Goal: Activation(14d)과 Consistency가 장기 Retention에 어떻게 연결되는지 요약
- Active 정의: 해당 기간에 session >= 1
- day 180 누락 이슈 대응: last_week(173~179) 사용
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

sessions_filt AS 
(
  SELECT user_id,
         DATE(CAST(session_start_ts AS TIMESTAMP)) AS session_date
  
  FROM `eternal-argon-479503-e8.ecommerce.sessions`
),

user_flags AS 
(
  SELECT a.user_id,
         a.activation_stage_14d,
         c.consistency_segment,

         -- D30/D60/D90: signup 후 [0,29], [0,59], [0,89]에 세션이 있으면 active
         MAX(IF(s.session_date >= a.signup_date AND s.session_date < DATE_ADD(a.signup_date, INTERVAL 30 DAY), 1, 0)) AS active_d30,
         MAX(IF(s.session_date >= a.signup_date AND s.session_date < DATE_ADD(a.signup_date, INTERVAL 60 DAY), 1, 0)) AS active_d60,
         MAX(IF(s.session_date >= a.signup_date AND s.session_date < DATE_ADD(a.signup_date, INTERVAL 90 DAY), 1, 0)) AS active_d90,

         -- last_week: day 173~179 중 세션이 있으면 active (day180 누락 대응)
         MAX(IF(s.session_date >= DATE_ADD(a.signup_date, INTERVAL 173 DAY)
             AND s.session_date <= DATE_ADD(a.signup_date, INTERVAL 179 DAY), 1, 0)) AS active_last_week_173_179

  FROM activation a LEFT JOIN consistency c 
      ON a.user_id = c.user_id LEFT JOIN sessions_filt s 
        ON c.user_id = s.user_id

  WHERE a.anomaly_flag = 0

  GROUP BY 1,2,3
)

SELECT activation_stage_14d,
       consistency_segment,
       COUNT(*) AS users,

       AVG(active_d30) AS retention_d30,
       AVG(active_d60) AS retention_d60,
       AVG(active_d90) AS retention_d90,
       AVG(active_last_week_173_179) AS retention_last_week_173_179

FROM user_flags

WHERE consistency_segment != 'C0_no_consistency_data'

GROUP BY 1,2

ORDER BY
  CASE activation_stage_14d
    WHEN 'A0_no_activity' THEN 0
    WHEN 'A1_view' THEN 1
    WHEN 'A2_click' THEN 2
    WHEN 'A3_add_to_cart' THEN 3
    WHEN 'A4_checkout' THEN 4
    WHEN 'A5_purchase' THEN 5
    ELSE 99
  END,
  CASE consistency_segment
    WHEN 'C1_low_consistency' THEN 1
    WHEN 'C2' THEN 2
    WHEN 'C3_mid' THEN 3
    WHEN 'C4' THEN 4
    WHEN 'C5_high_consistency' THEN 5
    ELSE 99
  END;
