CREATE OR REPLACE TABLE `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_kpi_window`
PARTITION BY cohort_month
CLUSTER BY window_days AS

/* =====================================================================
  목적:
  - DM_funnel_session(원자, 1 row = 1 session)을
    가입 후 14일/30일 윈도우 기준으로 cohort_month 단위로 요약한 KPI 테이블
  - reach(도달) vs strict(순서 정상) 두 버전의 전환율을 모두 제공
===================================================================== */

-- DM_funnel_session에서 "윈도우(14/30일) 안에 들어오는 세션"만 골라서
-- cohort_month + window_days(14/30) 기준으로 동일 스키마로 쌓아놓기 위해 UNION ALL
-- 14일/30일을 cohort_month 기준으로 같이 분석하기 위해
WITH base AS 
(
  SELECT DATE_TRUNC(signup_date, MONTH) AS cohort_month,
         14 AS window_days,
         session_id,
         user_id,

         -- Reach flags: 해당 세션에서 이벤트가 있었는지
         has_view,
         has_click,
         has_add_to_cart,
         has_checkout,
         has_purchase,

         -- Strict flags: 순서가 정상(view→click→cart→checkout→purchase)인지
         strict_view,
         strict_click,
         strict_add_to_cart,
         strict_checkout,
         strict_purchase
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`
  
  WHERE is_in_14d

  UNION ALL

  SELECT DATE_TRUNC(signup_date, MONTH) AS cohort_month,
         30 AS window_days,
         session_id,
         user_id,

         has_view,
         has_click,
         has_add_to_cart,
         has_checkout,
         has_purchase,

         strict_view,
         strict_click,
         strict_add_to_cart,
         strict_checkout,
         strict_purchase
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`
  
  WHERE is_in_30d
),

-- base에서 cohort_month × window_days 단위로 세션 수 및 단계별 세션수 집계
-- conversion rate 계산은 최종 SELECT에서 SAFE_DIVIDE로 수행
agg AS 
(
  SELECT cohort_month,
         window_days,
         COUNT(*) AS session,

         -- Reach counts: 단계 이벤트가 존재한 세션 수
         COUNTIF(has_view)        AS reach_view_sessions,
         COUNTIF(has_click)       AS reach_click_sessions,
         COUNTIF(has_add_to_cart) AS reach_cart_sessions,
         COUNTIF(has_checkout)    AS reach_checkout_sessions,
         COUNTIF(has_purchase)    AS reach_purchase_sessions,

         -- Strict counts: 순서가 정상인 단계 도달 세션 수
         COUNTIF(strict_view)        AS strict_view_sessions,
         COUNTIF(strict_click)       AS strict_click_sessions,
         COUNTIF(strict_add_to_cart) AS strict_cart_sessions,
         COUNTIF(strict_checkout)    AS strict_checkout_sessions,
         COUNTIF(strict_purchase)    AS strict_purchase_sessions

  FROM base

  GROUP BY 1, 2
)

-- agg에서 만든 counts를 사용해 전환율 계산
SELECT cohort_month,
       window_days,
       session,

       -- Reach conversion rates (step-to-step)
       SAFE_DIVIDE(reach_click_sessions,    NULLIF(reach_view_sessions, 0))        AS reach_view_to_click,
       SAFE_DIVIDE(reach_cart_sessions,     NULLIF(reach_click_sessions, 0))       AS reach_click_to_cart,
       SAFE_DIVIDE(reach_checkout_sessions, NULLIF(reach_cart_sessions, 0))        AS reach_cart_to_checkout,
       SAFE_DIVIDE(reach_purchase_sessions, NULLIF(reach_checkout_sessions, 0))    AS reach_checkout_to_purchase,
       SAFE_DIVIDE(reach_purchase_sessions, NULLIF(reach_view_sessions, 0))        AS reach_view_to_purchase,

       -- Strict conversion rates (step-to-step)
       SAFE_DIVIDE(strict_click_sessions,    NULLIF(strict_view_sessions, 0))      AS strict_view_to_click,
       SAFE_DIVIDE(strict_cart_sessions,     NULLIF(strict_click_sessions, 0))     AS strict_click_to_cart,
       SAFE_DIVIDE(strict_checkout_sessions, NULLIF(strict_cart_sessions, 0))      AS strict_cart_to_checkout,
       SAFE_DIVIDE(strict_purchase_sessions, NULLIF(strict_checkout_sessions, 0))  AS strict_checkout_to_purchase,
       SAFE_DIVIDE(strict_purchase_sessions, NULLIF(strict_view_sessions, 0))      AS strict_view_to_purchase,

       -- Debug / ReadMe용 counts
       reach_view_sessions,
       reach_click_sessions,
       reach_cart_sessions,
       reach_checkout_sessions,
       reach_purchase_sessions,
       strict_view_sessions,
       strict_click_sessions,
       strict_cart_sessions,
       strict_checkout_sessions,
       strict_purchase_sessions
       
FROM agg;
