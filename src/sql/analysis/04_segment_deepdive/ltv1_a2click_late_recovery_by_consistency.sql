--#의미: A2_click 고정 + late recovery(14~29) + consistency별 결과(기본 비교)

/* 
“초기 14일에는 click까지만 도달(A2_click)했던 유저들 중에서도,
 15–30일에 cart로 ‘회복(late recovery)’하는지가 180일 LTV/구매로 이어지는가?
그리고 그 회복이 Consistency와 연결되는가?”

이게 프로젝트 목표(Short-term Activation ↔ Long-term LTV/Retention trade-off를 **행동(Consistency)**로 설명)랑 직접 연결되는 이유는:
Short-term: 14일 기준 activation(A2_click = 초기 한계)
Mid-term: 30일 안에서 14~29일 회복(late recovery) 여부
Long-term: 180일 LTV(orders/revenue)
연결고리: Consistency(C1~C5)가 late recovery 확률을 끌어올리고, 그게 LTV로 이어진다면 “행동→전환→장기성과” 구조 설명이 완성됨
*/

/* ============================================================================
[LTV-1] A2_click 유저의 "Late Cart Recovery(14~29일)"가 180d LTV/구매로 이어지는지 확인

프로젝트 목표 연결:
- Short-term Activation(14d): A2_click (클릭까지만, 14d 내 cart 미도달)
- Mid-term Funnel 회복(30d): 14~29일 구간에서 cart(strict_add_to_cart) 발생 여부
- Long-term Outcome(180d): DM_ltv_180d의 revenue/orders/구매여부

핵심 질문:
1) Consistency(C1~C5)가 높을수록 late recovery 비율이 증가하는가?
2) late recovery가 있는 그룹이 180d 구매율/LTV가 더 높은가?

주의(객관적):
- consistency_score_v1은 0~180d 세션 기반이라 LTV와 내생성(endogeneity)이 있을 수 있음.
  -> 본 쿼리는 "구조적 설명(연관/경로 후보)" 목적이며, 인과 주장 금지.
============================================================================ */

WITH
-- 1) Activation 정의(14d 기준). 여기서는 A2_click만 분석 타겟으로 사용.
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

-- 2) Consistency segment(C0~C5): score_v1 기반 5분위 + NULL은 C0
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

-- 3) (유저 단위) 30일 내 cart 회복 플래그 생성
-- - late_cart_recovery_14_29: 14~29일 구간에 strict_add_to_cart가 1번이라도 있으면 1
-- - any_cart_0_29: 0~29일 전체에서 cart가 있으면 1 (sanity/참고용)
recovery AS (
  SELECT
    user_id,
    MAX(IF(is_in_30d AND days_since_signup BETWEEN 14 AND 29 AND strict_add_to_cart, 1, 0)) AS late_cart_recovery_14_29,
    MAX(IF(is_in_30d AND days_since_signup BETWEEN 0 AND 29 AND strict_add_to_cart, 1, 0))  AS any_cart_0_29
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`
  GROUP BY user_id
),

-- 4) 180d outcome(LTV)
ltv AS (
  SELECT user_id, revenue_180d, orders_180d, aov_180d, has_purchase_180d
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`
)

-- 5) 결과: consistency × late_recovery 조합별 180d 성과 비교
SELECT
  c.consistency_segment,
  r.late_cart_recovery_14_29,

  COUNT(*) AS users,
  AVG(CAST(r.any_cart_0_29 AS INT64))            AS cart_rate_0_29,
  AVG(CAST(ltv.has_purchase_180d AS INT64))      AS purchase_rate_180d,

  AVG(ltv.revenue_180d)                          AS avg_revenue_180d,
  APPROX_QUANTILES(ltv.revenue_180d, 100)[OFFSET(50)] AS median_revenue_180d,
  AVG(ltv.orders_180d)                           AS avg_orders_180d,
  AVG(ltv.aov_180d)                              AS avg_aov_180d

FROM activation a
LEFT JOIN consistency c USING(user_id)
LEFT JOIN recovery r USING(user_id)
LEFT JOIN ltv USING(user_id)
WHERE a.anomaly_flag = 0
  AND a.activation_stage_14d = 'A2_click'
GROUP BY 1,2
ORDER BY
  CASE c.consistency_segment
    WHEN 'C0_no_consistency_data' THEN 0
    WHEN 'C1_low_consistency' THEN 1
    WHEN 'C2' THEN 2
    WHEN 'C3_mid' THEN 3
    WHEN 'C4' THEN 4
    WHEN 'C5_high_consistency' THEN 5
    ELSE 99
  END,
  r.late_cart_recovery_14_29;
