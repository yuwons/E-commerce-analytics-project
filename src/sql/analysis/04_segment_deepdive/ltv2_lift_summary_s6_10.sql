--# 의미: S_6_10 고정 + lift 계산 결과(“한 장짜리” 요약)
/* ============================================================================
[LTV-2-SUMMARY] Volume 통제(S_6_10) 하에서 late recovery lift 요약 (ReadMe/면접용)

목표 연결:
- A2_click(14d) 유저 내에서
- 0~29일 세션수(sessions_0_29)를 6~10으로 고정(Volume 최소 통제)
- 그 안에서 14~29일 late cart recovery 여부가
  180d 구매율/매출(LTV proxy)에 어떤 lift를 주는지 consistency별로 요약한다.

해석 주의:
- 인과 주장 금지. "연관/경로 후보"로만 서술.
============================================================================ */

WITH activation AS 
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

-- 0~29일 세션 볼륨(버킷)
user_0_29_volume AS 
(
  SELECT user_id,
         COUNT(DISTINCT session_id) AS sessions_0_29
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`
  
  WHERE is_in_30d AND days_since_signup BETWEEN 0 AND 29
  
  GROUP BY user_id
),

-- late recovery (14~29 strict cart)
recovery AS 
(
  SELECT user_id,
         MAX(IF(is_in_30d AND days_since_signup BETWEEN 14 AND 29 AND strict_add_to_cart, 1, 0)) AS late_cart_recovery_14_29
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`
  
  GROUP BY user_id
),

ltv AS 
(
  SELECT user_id,
         revenue_180d,
         orders_180d,
         has_purchase_180d
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`
),

base AS 
(
  SELECT c.consistency_segment,
         r.late_cart_recovery_14_29 AS recovered,
         v.sessions_0_29,
         l.revenue_180d,
         l.orders_180d,
         l.has_purchase_180d
  
  FROM activation a LEFT JOIN consistency c 
    ON a.user_id = c.user_id LEFT JOIN recovery r 
      ON a.user_id = r.user_id LEFT JOIN user_0_29_volume v 
        ON a.user_id = v.user_id LEFT JOIN ltv l 
          ON a.user_id = l.user_id

  WHERE a.anomaly_flag = 0
    AND a.activation_stage_14d = 'A2_click'
    
    --  Volume 통제: S_6_10만
    AND v.sessions_0_29 BETWEEN 6 AND 10
),

-- recovered(0/1)별 지표 요약
by_rec AS 
(
  SELECT consistency_segment,
         recovered,
         COUNT(*) AS users,
         AVG(CAST(has_purchase_180d AS INT64)) AS purchase_rate_180d,

         AVG(revenue_180d) AS avg_revenue_180d,
         APPROX_QUANTILES(revenue_180d, 100)[OFFSET(50)] AS median_revenue_180d,

         -- buyer-only (구매자만)
         AVG(IF(has_purchase_180d, revenue_180d, NULL)) AS avg_revenue_180d_buyer_only,
         APPROX_QUANTILES(IF(has_purchase_180d, revenue_180d, NULL), 100)[OFFSET(50)] AS median_revenue_180d_buyer_only,

         AVG(orders_180d) AS avg_orders_180d
  
  FROM base
  
  GROUP BY 1,2
),

-- recovered=0 vs 1을 한 줄로 합치고 lift 계산
pivot AS 
(
  SELECT consistency_segment,
         -- n
         MAX(IF(recovered=0, users, NULL)) AS users_no_recovery,
         MAX(IF(recovered=1, users, NULL)) AS users_recovered,

         -- purchase rate
         MAX(IF(recovered=0, purchase_rate_180d, NULL)) AS pr_no_recovery,
         MAX(IF(recovered=1, purchase_rate_180d, NULL)) AS pr_recovered,

         -- revenue (overall)
         MAX(IF(recovered=0, avg_revenue_180d, NULL)) AS avg_rev_no_recovery,
         MAX(IF(recovered=1, avg_revenue_180d, NULL)) AS avg_rev_recovered,

         MAX(IF(recovered=0, median_revenue_180d, NULL)) AS med_rev_no_recovery,
         MAX(IF(recovered=1, median_revenue_180d, NULL)) AS med_rev_recovered,

         -- revenue (buyer-only)
         MAX(IF(recovered=0, avg_revenue_180d_buyer_only, NULL)) AS avg_rev_no_recovery_buyer,
         MAX(IF(recovered=1, avg_revenue_180d_buyer_only, NULL)) AS avg_rev_recovered_buyer,

         MAX(IF(recovered=0, median_revenue_180d_buyer_only, NULL)) AS med_rev_no_recovery_buyer,
         MAX(IF(recovered=1, median_revenue_180d_buyer_only, NULL)) AS med_rev_recovered_buyer
  
  FROM by_rec
  
  GROUP BY 1
)

SELECT consistency_segment,
       users_no_recovery,
       users_recovered,

       pr_no_recovery,
       pr_recovered,
       (pr_recovered - pr_no_recovery) AS pr_lift_abs,
       SAFE_DIVIDE(pr_recovered, NULLIF(pr_no_recovery, 0)) AS pr_lift_ratio,

       avg_rev_no_recovery,
       avg_rev_recovered,
       (avg_rev_recovered - avg_rev_no_recovery) AS avg_rev_lift_abs,
       SAFE_DIVIDE(avg_rev_recovered, NULLIF(avg_rev_no_recovery, 0)) AS avg_rev_lift_ratio,

       -- buyer-only는 median/avg가 더 해석 가능
       avg_rev_no_recovery_buyer,
       avg_rev_recovered_buyer,
       (avg_rev_recovered_buyer - avg_rev_no_recovery_buyer) AS avg_rev_buyer_lift_abs,
       SAFE_DIVIDE(avg_rev_recovered_buyer, NULLIF(avg_rev_no_recovery_buyer, 0)) AS avg_rev_buyer_lift_ratio,

       med_rev_no_recovery_buyer,
       med_rev_recovered_buyer

  FROM pivot

  -- C0는 표본 거의 없을 수 있어 제외해도 됨(원하면 WHERE로 제거)
  WHERE consistency_segment != 'C0_no_consistency_data'
  
ORDER BY
  CASE consistency_segment
    WHEN 'C1_low_consistency' THEN 1
    WHEN 'C2' THEN 2
    WHEN 'C3_mid' THEN 3
    WHEN 'C4' THEN 4
    WHEN 'C5_high_consistency' THEN 5
    ELSE 99
  END;
