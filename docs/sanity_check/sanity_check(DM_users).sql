-- #Row count = users와 동일해야 함
SELECT
  (SELECT COUNT(*) FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`) AS dm_rows,
  (SELECT COUNT(*) FROM `eternal-argon-479503-e8.ecommerce.users`) AS users_rows;

-- #PK 유일성 + NULL 체크
SELECT
  COUNT(*) AS rows_num,
  COUNT(DISTINCT user_id) AS distinct_user_id,
  COUNTIF(user_id IS NULL) AS null_user_id,
  COUNTIF(signup_date IS NULL) AS null_signup
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`;

--# 논리 체크 14d 는 30d 의 subset
SELECT
  COUNTIF(has_purchase_14d AND NOT has_purchase_30d) AS violation_purchase,
  COUNTIF(has_view_14d AND NOT has_view_30d) AS violation_view,
  COUNTIF(has_click_14d AND NOT has_click_30d) AS violation_click,
  COUNTIF(has_add_to_cart_14d AND NOT has_add_to_cart_30d) AS violation_cart,
  COUNTIF(has_checkout_14d AND NOT has_checkout_30d) AS violation_checkout
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`;

# orders/revenue 정합성 
SELECT
  COUNTIF(orders_14d > orders_30d)  AS viol_o_14_30,
  COUNTIF(orders_30d > orders_180d) AS viol_o_30_180,
  COUNTIF(revenue_14d > revenue_30d)  AS viol_r_14_30,
  COUNTIF(revenue_30d > revenue_180d) AS viol_r_30_180
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`;

--revenue가 있는데 orders가 0이면 이상
SELECT
  COUNTIF(revenue_180d > 0 AND orders_180d = 0) AS viol_rev_no_orders
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`;

--# promo counts는 전체 counts보다 클 수 없음
SELECT
  COUNTIF(promo_orders_30d > orders_30d) AS viol_promo_orders,
  COUNTIF(promo_session_cnt_30d > session_cnt_180d) AS viol_promo_sessions
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`;

--# Funnel 논리: checkout 있으면 view/click은 대체로 앞에 있어야 함 (Soft check)
SELECT
  COUNTIF(has_checkout_30d AND NOT has_view_30d)  AS checkout_without_view_30d,
  COUNTIF(has_checkout_30d AND NOT has_click_30d) AS checkout_without_click_30d
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`;


