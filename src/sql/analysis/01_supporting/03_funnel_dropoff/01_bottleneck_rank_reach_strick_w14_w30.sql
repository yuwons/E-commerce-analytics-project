-- src/sql/analysis/03_funnel/03_funnel_bottleneck_rank.sql
-- Output: (window_days, activation_stage, consistency_segment, metric_type)별
--         가장 낮은 step conversion 1개 + (원하면 top2)까지

--“초기 14일에 A2(클릭까지)였던 유저들이,
--가입 후 14일 세션에서는 어디서 막히고,
--가입 후 30일 세션에서는 병목이 이동하는지(개선/--악화/고정) 본다.”

-- 1) Activation stage (14d) : user-level
-- 유저 퍼널 도달 최고 단계 라벨링 (A0-A5)

/*====================================================================================================================

목적: Activation(14d A0~A5) × Consistency(C0~C5) 세그먼트별로 퍼널 병목 step을 식별하고, window(14d vs 30d) 및 정의(reach vs strict)에 따라 병목이 어떻게 달라지는지(이동/차이)를 요약한다.
Data Mart input: DM_user_window (activation_stage_14d, anomaly_flag),
                 DM_consistency_180d (score_v1→NTILE로 C0~C5), 
                 DM_funnel_session (is_in_14d/is_in_30d, reach flags, strict flags)
출력 그레인: (window_days, activation_stage_14d, consistency_segment, metric_type) 1 row  ※ 각 조합마다 bottleneck_step 1개
핵심 로직: 14/30일 윈도우 세션을 union( session_base ) → 유저의 Activation/Consistency 라벨을 조인 → 세그먼트별 step 전환율 계산(4-step: view→click→cart→checkout→purchase) → long format으로 펼친 뒤(conv_rate) 최저 step을 병목으로 랭킹(rn=1)
주의사항: denom_sessions>=50 최소 분모 컷이 병목 결과를 좌우할 수 있음(필요 시 100 등으로 상향); conv_rate ASC 기준이라 “가장 낮은 전환율 step”을 병목으로 정의(드랍 최대와 거의 동치지만, 분모/분산 영향 있음)
결과 읽는법: 같은 세그먼트에서 reach vs strict, 14d vs 30d의 bottleneck_step이 바뀌는지 확인하고, 특히 C1과 C5의 병목 위치/강도 차이를 “왜 장기 성과가 갈리는가” 보조 설명으로 연결한다.

결과 요약: 세그먼트별로 ‘전환율이 가장 낮은 단계’가 14d/30d 및 reach/strict 정의에 따라 달라지며, 병목 step/강도(전환율·dropoff)가 비교 가능한 형태로 정리된다.
해석/의미: 메인 스토리(Activation×Consistency→LTV/Retention)에서 관측된 격차를 “퍼널의 어느 단계에서 막히는지”로 설명할 수 있는 근거 테이블이다.
-다음 액션: 병목이 가장 자주 나타나는 단계(빈도)와, 최악 세그먼트 Top10을 별도 요약해 ‘개선 우선순위(어디를 먼저 고칠지)’를 한 장으로 압축한다.

====================================================================================================================*/

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
         
         CASE WHEN has_purchase_14d THEN 5
              WHEN has_checkout_14d THEN 4
              WHEN has_add_to_cart_14d THEN 3
              WHEN has_click_14d THEN 2
              WHEN has_view_14d THEN 1
         ELSE 0
         END AS activation_stage_order,
    
         anomaly_flag
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`
),

-- 2) Consistency segment (C0~C5) : user-level
-- 유저 방문 리듬 라벨링 C0 ~ C5
consistency_raw AS 
(
  SELECT user_id,
         consistency_score_v1

  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`
),

-- CONSISTENCY SCORE 0 랑 분리. 
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
         END AS consistency_segment,
    
    COALESCE(n.seg5, 0) AS consistency_order
  
  FROM consistency_raw r LEFT JOIN consistency_ntile n
    ON r.user_id = n.user_id
),

-- 3) 14/30 윈도우 세션만 (세션 기반 진단)
session_base AS 
(
  SELECT 14 AS window_days,
         session_id,
         user_id,
         -- reach
         has_view,
         has_click,
         has_add_to_cart,
         has_checkout,
         has_purchase,
         -- strict
         strict_view,
         strict_click,
         strict_add_to_cart,
         strict_checkout,
         strict_purchase

  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`

  WHERE is_in_14d

  UNION ALL

  SELECT 30 AS window_days,
         session_id,
         user_id,
         -- reach
         has_view,
         has_click,
         has_add_to_cart,
         has_checkout,
         has_purchase,
         -- strict
         strict_view,
         strict_click,
         strict_add_to_cart,
         strict_checkout,
         strict_purchase

  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`

  WHERE is_in_30d
),

-- 4) Join
base AS (
  SELECT
    s.window_days,
    a.activation_stage_14d,
    a.activation_stage_order,
    c.consistency_segment,
    c.consistency_order,

    -- reach
    s.has_view, s.has_click, s.has_add_to_cart, s.has_checkout, s.has_purchase,
    -- strict
    s.strict_view, s.strict_click, s.strict_add_to_cart, s.strict_checkout, s.strict_purchase
  FROM session_base s
  JOIN activation a
    ON s.user_id = a.user_id
  LEFT JOIN consistency c
    ON s.user_id = c.user_id
  WHERE a.anomaly_flag = 0
),

-- 5) 세그먼트별 step 카운트/전환율
agg AS 
(
  SELECT window_days,
         activation_stage_14d,
         activation_stage_order,
         consistency_segment,
         consistency_order,

         COUNT(*) AS sessions,

         -- Reach counts
         COUNTIF(has_view)        AS reach_view_sessions,
         COUNTIF(has_click)       AS reach_click_sessions,
         COUNTIF(has_add_to_cart) AS reach_cart_sessions,
         COUNTIF(has_checkout)    AS reach_checkout_sessions,
         COUNTIF(has_purchase)    AS reach_purchase_sessions,
         
         -- Reach conversion rate 계산
         SAFE_DIVIDE(COUNTIF(has_click),       NULLIF(COUNTIF(has_view), 0))        AS reach_view_to_click,
         SAFE_DIVIDE(COUNTIF(has_add_to_cart), NULLIF(COUNTIF(has_click), 0))       AS reach_click_to_cart,
         SAFE_DIVIDE(COUNTIF(has_checkout),    NULLIF(COUNTIF(has_add_to_cart), 0)) AS reach_cart_to_checkout,
         SAFE_DIVIDE(COUNTIF(has_purchase),    NULLIF(COUNTIF(has_checkout), 0))    AS reach_checkout_to_purchase,

         -- Strict counts
         COUNTIF(strict_view)        AS strict_view_sessions,
         COUNTIF(strict_click)       AS strict_click_sessions,
         COUNTIF(strict_add_to_cart) AS strict_cart_sessions,
         COUNTIF(strict_checkout)    AS strict_checkout_sessions,
         COUNTIF(strict_purchase)    AS strict_purchase_sessions,
         
         -- Strict conversion rate 계산 
         SAFE_DIVIDE(COUNTIF(strict_click),       NULLIF(COUNTIF(strict_view), 0))        AS strict_view_to_click,
         SAFE_DIVIDE(COUNTIF(strict_add_to_cart), NULLIF(COUNTIF(strict_click), 0))       AS strict_click_to_cart,
         SAFE_DIVIDE(COUNTIF(strict_checkout),    NULLIF(COUNTIF(strict_add_to_cart), 0)) AS strict_cart_to_checkout,
         SAFE_DIVIDE(COUNTIF(strict_purchase),    NULLIF(COUNTIF(strict_checkout), 0))    AS strict_checkout_to_purchase

  FROM base

  GROUP BY 1,2,3,4,5
),

-- 6) step을 세로(long)로 펼치기 + 병목 랭킹
step_long AS 
(
  -- Reach
  SELECT window_days,
         activation_stage_14d,
         activation_stage_order,
         consistency_segment,
         consistency_order,
         sessions,
         'reach' AS metric_type,
         step,
         conv_rate,
         denom_sessions,
         num_sessions,
         (1.0 - conv_rate) AS dropoff_rate
  
  FROM agg,
  -- 4 개의 배열 생성 for each funnel step,and long format 으로 만들어주기
  UNNEST([
    STRUCT('view_to_click' AS step, reach_view_to_click AS conv_rate,
           reach_view_sessions AS denom_sessions, reach_click_sessions AS num_sessions),
    STRUCT('click_to_cart', reach_click_to_cart,
           reach_click_sessions, reach_cart_sessions),
    STRUCT('cart_to_checkout', reach_cart_to_checkout,
           reach_cart_sessions, reach_checkout_sessions),
    STRUCT('checkout_to_purchase', reach_checkout_to_purchase,
           reach_checkout_sessions, reach_purchase_sessions)
  ])

  UNION ALL

  -- Strict
  SELECT window_days,
         activation_stage_14d,
         activation_stage_order,
         consistency_segment,
         consistency_order,
         sessions,
         'strict' AS metric_type,
         step,
         conv_rate,
         denom_sessions,
         num_sessions,
         (1.0 - conv_rate) AS dropoff_rate
  
  FROM agg,
  -- 4 개의 배열 생성 for each funnel step,and long format 으로 만들어주기
  UNNEST([
    STRUCT('view_to_click' AS step, strict_view_to_click AS conv_rate,
           strict_view_sessions AS denom_sessions, strict_click_sessions AS num_sessions),
    STRUCT('click_to_cart', strict_click_to_cart,
           strict_click_sessions, strict_cart_sessions),
    STRUCT('cart_to_checkout', strict_cart_to_checkout,
           strict_cart_sessions, strict_checkout_sessions),
    STRUCT('checkout_to_purchase', strict_checkout_to_purchase,
           strict_checkout_sessions, strict_purchase_sessions)
  ])
),

ranked AS 
(
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY window_days, activation_stage_14d, consistency_segment, metric_type
      ORDER BY conv_rate ASC, denom_sessions DESC
    ) AS rn
  FROM step_long
  WHERE TRUE
    -- 표본 적은 세그먼트는 noisy하니 옵션으로 컷
    -- AND sessions >= 100
    AND denom_sessions >= 50  -- 분모가 너무 작은 step은 병목으로 보기 애매해서 최소 분모컷(원하면 조정)
)

SELECT window_days,
       activation_stage_14d,
       consistency_segment,
       metric_type,
       step AS bottleneck_step,
       conv_rate AS bottleneck_conv_rate,
       dropoff_rate AS bottleneck_dropoff_rate,
       denom_sessions,
       num_sessions,
       sessions

FROM ranked

WHERE rn = 1

ORDER BY window_days,
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
    WHEN 'C0_no_consistency_data' THEN 0
    WHEN 'C1_low_consistency' THEN 1
    WHEN 'C2' THEN 2
    WHEN 'C3_mid' THEN 3
    WHEN 'C4' THEN 4
    WHEN 'C5_high_consistency' THEN 5
    ELSE 99
  END,
  metric_type;
