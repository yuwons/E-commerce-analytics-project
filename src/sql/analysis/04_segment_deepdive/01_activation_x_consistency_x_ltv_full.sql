-- 04_segment_deepdive/01_activation_x_consistency_x_ltv__FULL.sql
-- Activation(14d stage) × Consistency(C0~C5) × LTV(180d)

WITH ltv AS 
(
  SELECT user_id,
         signup_date,
         user_type,
         device,
         region,
         marketing_source,
         anomaly_flag,
         orders_180d,
         revenue_180d,
         has_purchase_180d,
         promo_orders_180d,
         promo_revenue_180d

  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`
),

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
         
         CASE WHEN has_purchase_14d THEN 5
              WHEN has_checkout_14d THEN 4
              WHEN has_add_to_cart_14d THEN 3
              WHEN has_click_14d THEN 2
              WHEN has_view_14d THEN 1
              ELSE 0
         END AS activation_stage_order
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`
),

-- DM에서 score_v1 가져오기
consistency_raw AS 
(
  SELECT user_id,
         active_days_180d,
         weekly_active_ratio_180d,
         intervisit_cv_180d,
         consistency_score_v1
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`
),

-- NULL 제외한 유저만 NTILE로 C1~C5 분할
consistency_scored_nonnull AS
(
  SELECT user_id,
         consistency_score_v1
  
  FROM consistency_raw

  WHERE consistency_score_v1 IS NOT NULL
),

consistency_segment_nonnull AS 
(
  SELECT user_id,
         NTILE(5) OVER (ORDER BY consistency_score_v1) AS seg5
  
  FROM consistency_scored_nonnull
),

-- 다시 전체 유저에 LEFT JOIN해서 C0 버킷 포함
consistency AS 
(
  SELECT r.user_id,
         r.active_days_180d,
         r.weekly_active_ratio_180d,
         r.intervisit_cv_180d,
         r.consistency_score_v1,

         CASE WHEN s.seg5 IS NULL THEN 'C0_no_consistency_data'
              WHEN s.seg5 = 1 THEN 'C1_low_consistency'
              WHEN s.seg5 = 2 THEN 'C2'
              WHEN s.seg5 = 3 THEN 'C3_mid'
              WHEN s.seg5 = 4 THEN 'C4'
              WHEN s.seg5 = 5 THEN 'C5_high_consistency'
         END AS consistency_segment,

         COALESCE(s.seg5, 0) AS consistency_order
  
  FROM consistency_raw r LEFT JOIN consistency_segment_nonnull s
        ON r.user_id = s.user_id
),

base AS 
(
  SELECT l.user_id,
         l.signup_date,
         l.user_type, l.device, l.region, l.marketing_source,
         l.anomaly_flag,

         l.orders_180d,
         l.revenue_180d,
         l.has_purchase_180d,
         l.promo_orders_180d,
         l.promo_revenue_180d,

         a.activation_stage_14d,
         a.activation_stage_order,

         c.consistency_segment,
         c.consistency_order,
         c.active_days_180d,
         c.weekly_active_ratio_180d,
         c.intervisit_cv_180d,
         c.consistency_score_v1
  
  FROM ltv l LEFT JOIN activation a 
      ON l.user_id = a.user_id LEFT JOIN consistency c 
            ON l.user_id = c.user_id
),
result as
(
SELECT activation_stage_14d,
       consistency_segment,

       COUNT(*) AS users,
       COUNTIF(has_purchase_180d) AS buyers_180d,
       SAFE_DIVIDE(COUNTIF(has_purchase_180d), COUNT(*)) AS purchase_rate_180d,

       -- overall(0 포함)
       AVG(orders_180d) AS avg_orders_180d,
       AVG(revenue_180d) AS avg_revenue_180d,
       APPROX_QUANTILES(revenue_180d, 100)[OFFSET(50)] AS median_revenue_180d,

       -- buyer-only(구매자만)
       AVG(IF(has_purchase_180d, orders_180d, NULL)) AS avg_orders_180d_buyer_only,
       AVG(IF(has_purchase_180d, revenue_180d, NULL)) AS avg_revenue_180d_buyer_only,
       APPROX_QUANTILES(IF(has_purchase_180d, revenue_180d, NULL), 100)[OFFSET(50)] AS median_revenue_180d_buyer_only,

       -- promo mix
       AVG(promo_orders_180d) AS avg_promo_orders_180d,
       SAFE_DIVIDE(SUM(promo_revenue_180d), NULLIF(SUM(revenue_180d), 0)) AS promo_revenue_share,

       -- sanity check: consistency 지표 분리 확인
       AVG(active_days_180d) AS avg_active_days_180d,
       AVG(weekly_active_ratio_180d) AS avg_weekly_active_ratio_180d,
       AVG(intervisit_cv_180d) AS avg_intervisit_cv_180d,
       AVG(consistency_score_v1) AS avg_consistency_score_v1

  FROM base

  WHERE anomaly_flag = 0

  GROUP BY 1,2
)
SELECT *
FROM result
WHERE users >= 100
ORDER BY activation_stage_14d, consistency_segment;
