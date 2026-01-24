/* =========================================================
[FINAL] Activation(14d) * Consistency → LTV(180d) + Point Retention
- 프로젝트 목표 연결:
  초기 전환(Activation) 수준이 장기 성과를 완전히 설명하지 못함
  Consistency(방문 리듬/불규칙성)가 장기 LTV/Retention을 강하게 분리
  즉 Short-term Activation vs Long-term outcome trade-off를
     Consistency로 구조적으로 설명

- Promo/discount deep dive 제외 이유:
  데이터 희소(orders is_promo ~0.3%, discount도 극소) - 노이즈 위험 큼
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


/* 3) LTV outcome (180d): user-level */
ltv AS 
(
  SELECT user_id,
         orders_180d,
         revenue_180d,
         has_purchase_180d
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`
),

/* 4) Point Retention flags (최근 7일 기준)
   - w30: day 23~29
   - w60: day 53~59
   - w90: day 83~89
   - last_week: day 173~179 (day180 누락 이슈 대응) */
sessions AS 
(
  SELECT user_id,
         DATE(CAST(session_start_ts AS TIMESTAMP)) AS session_date
  
  FROM `eternal-argon-479503-e8.ecommerce.sessions`
),
retention_flags AS 
(
  SELECT a.user_id,
         MAX(IF(DATE_DIFF(s.session_date, a.signup_date, DAY) BETWEEN 23 AND 29, 1, 0)) AS active_w30,
         MAX(IF(DATE_DIFF(s.session_date, a.signup_date, DAY) BETWEEN 53 AND 59, 1, 0)) AS active_w60,
         MAX(IF(DATE_DIFF(s.session_date, a.signup_date, DAY) BETWEEN 83 AND 89, 1, 0)) AS active_w90,
         MAX(IF(DATE_DIFF(s.session_date, a.signup_date, DAY) BETWEEN 173 AND 179, 1, 0)) AS active_last_week_173_179
  
  FROM activation a LEFT JOIN sessions s 
    ON a.user_id = s.user_id

  WHERE a.anomaly_flag = 0

  GROUP BY 1
),

/* 5) Final user base */
base AS 
(
  SELECT a.user_id,
         a.activation_stage_14d,
         c.consistency_segment,

         l.has_purchase_180d,
         l.orders_180d,
         l.revenue_180d,

         r.active_w30,
         r.active_w60,
         r.active_w90,
         r.active_last_week_173_179

  FROM activation a LEFT JOIN consistency c 
    ON a.user_id = c.user_id LEFT JOIN ltv l 
      ON a.user_id = l.user_id LEFT JOIN retention_flags r 
        ON a.user_id = r.user_id

  WHERE a.anomaly_flag = 0
)
/* ======================== full select outcome check ==================== */
SELECT activation_stage_14d,
       consistency_segment,
       COUNT(*) AS users,

       /* LTV */
       AVG(CAST(has_purchase_180d AS INT64)) AS purchase_rate_180d,
       AVG(orders_180d) AS avg_orders_180d,
       AVG(revenue_180d) AS avg_revenue_180d,
       APPROX_QUANTILES(revenue_180d, 100)[OFFSET(50)] AS median_revenue_180d,

       /* buyer-only LTV (구매자만) */
       AVG(IF(has_purchase_180d, orders_180d, NULL)) AS avg_orders_180d_buyer_only,
       AVG(IF(has_purchase_180d, revenue_180d, NULL)) AS avg_revenue_180d_buyer_only,

       /* Point retention */
       AVG(active_w30) AS retention_w30,
       AVG(active_w60) AS retention_w60,
       AVG(active_w90) AS retention_w90,
       AVG(active_last_week_173_179) AS retention_last_week_173_179

FROM base

WHERE consistency_segment != 'C0_no_consistency_data'  -- v1 메인 스토리는 C1~C5로 통일 추천

GROUP BY 1,2

ORDER BY activation_stage_14d, consistency_segment;

/*======================== For Story.md screenshot =========================================
SELECT activation_stage_14d,
       consistency_segment,
       COUNT(*) AS users,
       --# LTV 
       ROUND(AVG(CAST(has_purchase_180d AS INT64)),4) AS purchase_rate_180d,
       --#ROUND(AVG(orders_180d),4) AS avg_orders_180d,
       ROUND(AVG(revenue_180d),4) AS avg_revenue_180d,
       ROUND(AVG(active_last_week_173_179),4) AS retention_last_week_173_179

FROM base

WHERE activation_stage_14d IN ('A0_no_activity','A1_view','A2_click')
  AND consistency_segment IN ('C1_low_consistency','C3_mid','C5_high_consistency')

GROUP BY 1,2

ORDER BY activation_stage_14d, consistency_segment;
=========================================================================================*/

