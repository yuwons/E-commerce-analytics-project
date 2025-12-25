--# 의미 : mix 차이를 통제한 표준화 전환율로 C1 ~ C5 의 순수 Gradient
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
consistency AS (
  SELECT r.user_id,
         CASE WHEN n.seg5 IS NULL THEN 'C0_no_consistency_data'
              WHEN n.seg5 = 1 THEN 'C1_low_consistency'
              WHEN n.seg5 = 2 THEN 'C2'
              WHEN n.seg5 = 3 THEN 'C3_mid'
              WHEN n.seg5 = 4 THEN 'C4'
              WHEN n.seg5 = 5 THEN 'C5_high_consistency'
         END AS consistency_segment
  
  FROM consistency_raw r
  
  LEFT JOIN consistency_ntile n 
      ON r.user_id = n.user_id 
),

sess30 AS 
(
  SELECT user_id,
         days_since_signup,
         device AS session_device,
         is_promo,
         discount_rate,
         click_cnt,
         strict_click,
         strict_add_to_cart
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`
  
  WHERE is_in_30d
),

base AS 
(
  SELECT c.consistency_segment,
         s.days_since_signup,
         s.session_device,
         s.is_promo,

    CASE WHEN s.discount_rate IS NULL THEN 'D0_null'
         WHEN s.discount_rate = 0 THEN 'D1_0'
         WHEN s.discount_rate < 0.10 THEN 'D2_lt10%'
         WHEN s.discount_rate < 0.20 THEN 'D3_10_20%'
         ELSE 'D4_ge20%'
    END AS discount_bucket,

    CASE WHEN s.click_cnt <= 1 THEN 'CLK_1'
         WHEN s.click_cnt <= 3 THEN 'CLK_2_3'
         WHEN s.click_cnt <= 8 THEN 'CLK_4_8'
         ELSE 'CLK_9p'
    END AS click_intensity,

    CASE WHEN s.days_since_signup BETWEEN 0 AND 13 THEN 'P0_13'
         WHEN s.days_since_signup BETWEEN 14 AND 29 THEN 'P14_29'
         ELSE 'OUT'
    END AS period,

    s.strict_click,
    s.strict_add_to_cart
  
  FROM sess30 s JOIN activation a 
    ON s.user_id = a.user_id LEFT JOIN consistency c 
      ON s.user_id = c.user_id

  WHERE a.anomaly_flag = 0
    AND a.activation_stage_14d = 'A2_click'
    AND s.days_since_signup BETWEEN 0 AND 29
)
-- (공통 CTE 붙이고 실행)

, bucket_conv AS (
  SELECT
    consistency_segment,
    period,
    session_device,
    is_promo,
    discount_bucket,
    click_intensity,
    COUNTIF(strict_click) AS denom,
    SAFE_DIVIDE(COUNTIF(strict_add_to_cart), NULLIF(COUNTIF(strict_click), 0)) AS conv
  FROM base
  GROUP BY 1,2,3,4,5,6
  HAVING denom >= 200
),

bucket_weights AS 
(
  -- 전체 base에서의 bucket 가중치(공통 분포)
  SELECT period,
         session_device,
         is_promo,
         discount_bucket,
         click_intensity,
         SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER(PARTITION BY period)) AS w
  FROM base
  
  GROUP BY 1,2,3,4,5
)

SELECT bc.consistency_segment,
       bc.period,
       SUM(bw.w * bc.conv) AS standardized_strict_click_to_cart,
       SUM(bw.w) AS total_weight_used

FROM bucket_conv bc JOIN bucket_weights bw
  USING(period, session_device, is_promo, discount_bucket, click_intensity)

GROUP BY 1,2

ORDER BY period, standardized_strict_click_to_cart;
