/* ============================================================================
[LTV-2] Volume(0~29일 세션 수) 통제 후에도
       late recovery(14~29일 cart)가 180d 성과와 연결되는지 확인

프로젝트 목표 연결:
- Consistency가 "단순히 많이 접속한 사람(Volume)"의 대리변수라면 스토리가 약해짐.
- 그래서 A2_click 내에서 sessions_0_29 버킷을 잡고,
  같은 버킷 안에서도 recovery=1이 LTV를 올리는지 확인한다.

해석:
- 같은 sessions_bucket_0_29에서도 recovery=1이 consistently 더 높은 LTV면
  "회복 경로"가 단순 volume 설명을 넘어선다는 근거가 됨.
============================================================================ */

WITH
activation AS (
  SELECT
    user_id,
    CASE
      WHEN has_purchase_14d THEN 'A5_purchase'
      WHEN has_checkout_14d THEN 'A4_checkout'
      WHEN has_add_to_cart_14d THEN 'A3_add_to_cart'
      WHEN has_click_14d THEN 'A2_click'
      WHEN has_view_14d THEN 'A1_view'
      ELSE 'A0_no_activity'
    END AS activation_stage_14d,
    anomaly_flag
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`
),

consistency_raw AS (
  SELECT user_id, consistency_score_v1
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`
),
consistency_nonnull AS (
  SELECT user_id, consistency_score_v1
  FROM consistency_raw
  WHERE consistency_score_v1 IS NOT NULL
),
consistency_ntile AS (
  SELECT user_id, NTILE(5) OVER (ORDER BY consistency_score_v1) AS seg5
  FROM consistency_nonnull
),
consistency AS (
  SELECT
    r.user_id,
    CASE
      WHEN n.seg5 IS NULL THEN 'C0_no_consistency_data'
      WHEN n.seg5 = 1 THEN 'C1_low_consistency'
      WHEN n.seg5 = 2 THEN 'C2'
      WHEN n.seg5 = 3 THEN 'C3_mid'
      WHEN n.seg5 = 4 THEN 'C4'
      WHEN n.seg5 = 5 THEN 'C5_high_consistency'
    END AS consistency_segment
  FROM consistency_raw r
  LEFT JOIN consistency_ntile n USING(user_id)
),

-- 0~29일 구간의 유저별 세션 볼륨(단순 활동량 통제용)
user_0_29_volume AS (
  SELECT
    user_id,
    COUNT(DISTINCT session_id) AS sessions_0_29,
    COUNTIF(strict_click)      AS strict_click_sessions_0_29
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`
  WHERE is_in_30d AND days_since_signup BETWEEN 0 AND 29
  GROUP BY user_id
),

-- late recovery 플래그(유저 단위)
recovery AS (
  SELECT
    user_id,
    MAX(IF(is_in_30d AND days_since_signup BETWEEN 14 AND 29 AND strict_add_to_cart, 1, 0)) AS late_cart_recovery_14_29
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`
  GROUP BY user_id
),

ltv AS (
  SELECT user_id, revenue_180d, orders_180d, has_purchase_180d
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`
),

base AS (
  SELECT
    c.consistency_segment,
    r.late_cart_recovery_14_29,
    v.sessions_0_29,
    v.strict_click_sessions_0_29,
    ltv.revenue_180d,
    ltv.orders_180d,
    ltv.has_purchase_180d
  FROM activation a
  LEFT JOIN consistency c USING(user_id)
  LEFT JOIN recovery r USING(user_id)
  LEFT JOIN user_0_29_volume v USING(user_id)
  LEFT JOIN ltv USING(user_id)
  WHERE a.anomaly_flag = 0
    AND a.activation_stage_14d = 'A2_click'
)

SELECT
  consistency_segment,
  late_cart_recovery_14_29,

  CASE
    WHEN sessions_0_29 <= 2  THEN 'S_0_2'
    WHEN sessions_0_29 <= 5  THEN 'S_3_5'
    WHEN sessions_0_29 <= 10 THEN 'S_6_10'
    ELSE 'S_11p'
  END AS sessions_bucket_0_29,

  COUNT(*) AS users,
  AVG(CAST(has_purchase_180d AS INT64)) AS purchase_rate_180d,
  AVG(revenue_180d)                      AS avg_revenue_180d,
  APPROX_QUANTILES(revenue_180d, 100)[OFFSET(50)] AS median_revenue_180d
FROM base
GROUP BY 1,2,3
HAVING users >= 100
ORDER BY 1,2,3;
