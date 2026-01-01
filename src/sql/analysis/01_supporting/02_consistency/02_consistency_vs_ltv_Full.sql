-- 02_consistency/02_consistency_vs_ltv__FULL.sql
-- Purpose:
-- Consistency segment(C0~C5) vs 180d outcomes (purchase/orders/revenue/AOV + promo mix)
-- Consistency score: DM_consistency_180d.consistency_score_v1 (single source of truth)
-- Includes C0 bucket to avoid selection bias from NULL scores

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
         aov_180d,
         promo_orders_180d,
         promo_revenue_180d

  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`
),

cons AS 
(
  SELECT user_id,
         session_cnt_180d,
         active_days_180d,
         intervisit_mean_180d,
         intervisit_median_180d,
         intervisit_std_180d,
         intervisit_cv_180d,
         active_weeks_180d,
         weekly_active_ratio_180d,

         repeat_interval_mean_180d,
         repeat_interval_std_180d,
         repeat_interval_cv_180d,
         repurchase_30d,
         repurchase_60d,
         repurchase_90d,

         consistency_score_v1
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`
),

base AS 
(
  SELECT l.*,
         c.session_cnt_180d,
         c.active_days_180d,
         c.intervisit_mean_180d,
         c.intervisit_median_180d,
         c.intervisit_std_180d,
         c.intervisit_cv_180d,
         c.active_weeks_180d,
         c.weekly_active_ratio_180d,

         c.repeat_interval_mean_180d,
         c.repeat_interval_std_180d,
         c.repeat_interval_cv_180d,

         c.repurchase_30d,
         c.repurchase_60d,
         c.repurchase_90d,

         c.consistency_score_v1

  FROM ltv l LEFT JOIN cons c 
    ON l.user_id = c.user_id

  WHERE l.anomaly_flag = 0

),

-- NTILE is computed only among non-null scores
cons_non_null AS 
(
  SELECT user_id,
         NTILE(5) OVER (ORDER BY consistency_score_v1) AS q5
  
  FROM base
  
  WHERE consistency_score_v1 IS NOT NULL
),

segmented AS (
  SELECT b.*,
         n.q5,
         CASE WHEN b.consistency_score_v1 IS NULL THEN 'C0_no_consistency_data'
              WHEN n.q5 = 1 THEN 'C1_low_consistency'
              WHEN n.q5 = 2 THEN 'C2'
              WHEN n.q5 = 3 THEN 'C3_mid'
              WHEN n.q5 = 4 THEN 'C4'
              WHEN n.q5 = 5 THEN 'C5_high_consistency'
              ELSE 'C0_no_consistency_data'
              END AS consistency_segment,
    
         COALESCE(n.q5, 0) AS consistency_order
  
  FROM base b LEFT JOIN cons_non_null n
    ON b.user_id = n.user_id
)

SELECT consistency_segment,
       COUNT(*) AS users,

       -- Outcomes (overall)
       AVG(CAST(has_purchase_180d AS INT64)) AS purchase_rate_180d,
       AVG(orders_180d) AS avg_orders_180d,
       AVG(revenue_180d) AS avg_revenue_180d,
       APPROX_QUANTILES(revenue_180d, 100)[OFFSET(50)] AS median_revenue_180d,
       AVG(aov_180d) AS avg_aov_180d,

       -- Buyer-only outcomes (해석 안정용)
       AVG(IF(has_purchase_180d, orders_180d, NULL)) AS avg_orders_180d_buyer_only,
       AVG(IF(has_purchase_180d, revenue_180d, NULL)) AS avg_revenue_180d_buyer_only,
       APPROX_QUANTILES(IF(has_purchase_180d, revenue_180d, NULL), 100)[OFFSET(50)] AS median_revenue_180d_buyer_only,

       -- Promo composition (권장: 합 기준 share)
       SAFE_DIVIDE(SUM(promo_orders_180d), NULLIF(SUM(orders_180d), 0)) AS promo_order_share_180d,
       SAFE_DIVIDE(SUM(promo_revenue_180d), NULLIF(SUM(revenue_180d), 0)) AS promo_revenue_share_180d,

       -- Consistency diagnostics (세그먼트 분리 검증용)
       AVG(active_days_180d) AS avg_active_days_180d,
       AVG(intervisit_cv_180d) AS avg_intervisit_cv_180d,
       AVG(weekly_active_ratio_180d) AS avg_weekly_active_ratio_180d,
       AVG(session_cnt_180d) AS avg_session_cnt_180d,
       AVG(consistency_score_v1) AS avg_consistency_score_v1,

       -- Orders-based consistency signals
       AVG(CAST(repurchase_30d AS INT64)) AS repurchase_rate_30d_overall,
       AVG(CAST(repurchase_60d AS INT64)) AS repurchase_rate_60d_overall,
       AVG(CAST(repurchase_90d AS INT64)) AS repurchase_rate_90d_overall,

       -- Repurchase among buyers only (더 중요한 해석)
       AVG(IF(has_purchase_180d, CAST(repurchase_30d AS INT64), NULL)) AS repurchase_rate_30d_buyer_only,
       AVG(IF(has_purchase_180d, CAST(repurchase_60d AS INT64), NULL)) AS repurchase_rate_60d_buyer_only,
       AVG(IF(has_purchase_180d, CAST(repurchase_90d AS INT64), NULL)) AS repurchase_rate_90d_buyer_only

  FROM segmented

  GROUP BY consistency_segment

  ORDER BY CASE consistency_segment
                WHEN 'C0_no_consistency_data' THEN 0
                WHEN 'C1_low_consistency' THEN 1
                WHEN 'C2' THEN 2
                WHEN 'C3_mid' THEN 3
                WHEN 'C4' THEN 4
                WHEN 'C5_high_consistency' THEN 5
           ELSE 99
           END;
