-- src/sql/analysis/01_activation/01_activation_base.sql
-- Purpose: Activation을 14d/30d 기준으로 표준 라벨링해 분석 베이스를 만든다.
-- DM used: ecommerce_dm.DM_user_window (+ 필요시 consistency/ltv/retention join)

WITH base AS (
  SELECT
    user_id,
    signup_date,
    DATE_TRUNC(signup_date, MONTH) AS cohort_month,

    -- 14d funnel reach flags
    has_view_14d,
    has_click_14d,
    has_add_to_cart_14d,
    has_checkout_14d,
    has_purchase_14d,

    -- 30d funnel reach flags
    has_view_30d,
    has_click_30d,
    has_add_to_cart_30d,
    has_checkout_30d,
    has_purchase_30d,

    -- long window volumes / outcomes
    orders_180d,
    revenue_180d,
    session_cnt_180d,
    event_cnt_180d,

    -- dimensions
    user_type,
    device,
    region,
    marketing_source,
    anomaly_flag
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`
),

labeled AS (
  SELECT
    *,
    -- 14d activation stage (가장 깊게 도달한 단계)
    CASE
      WHEN has_purchase_14d THEN 'A5_purchase'
      WHEN has_checkout_14d THEN 'A4_checkout'
      WHEN has_add_to_cart_14d THEN 'A3_add_to_cart'
      WHEN has_click_14d THEN 'A2_click'
      WHEN has_view_14d THEN 'A1_view'
      ELSE 'A0_no_activity'
    END AS activation_stage_14d,

    -- 14d activation score (정렬/세그먼트에 쓰기 좋음)
    CASE
      WHEN has_purchase_14d THEN 5
      WHEN has_checkout_14d THEN 4
      WHEN has_add_to_cart_14d THEN 3
      WHEN has_click_14d THEN 2
      WHEN has_view_14d THEN 1
      ELSE 0
    END AS activation_score_14d
  FROM base
)

SELECT * FROM labeled;
