--# window_days는 14/30만 있어야 함

SELECT window_days, COUNT(*) row_num
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_kpi_window`
GROUP BY 1
ORDER BY 1;


--# 기대한 “대략 전환율”이랑 비슷한지 spot check
SELECT *
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_kpi_window`
ORDER BY cohort_month DESC, window_days;


--# 전환율 범위 체크 (0~1, NULL 허용)

SELECT
  COUNTIF(reach_view_to_click < 0 OR reach_view_to_click > 1) AS bad1,
  COUNTIF(reach_click_to_cart < 0 OR reach_click_to_cart > 1) AS bad2,
  COUNTIF(reach_cart_to_checkout < 0 OR reach_cart_to_checkout > 1) AS bad3,
  COUNTIF(reach_checkout_to_purchase < 0 OR reach_checkout_to_purchase > 1) AS bad4
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_kpi_window`;

--# strict는 reach보다 클 수 없음 (counts 기준) 

SELECT
  COUNTIF(strict_purchase_sessions > reach_purchase_sessions) AS viol_p,
  COUNTIF(strict_checkout_sessions > reach_checkout_sessions) AS viol_c,
  COUNTIF(strict_cart_sessions > reach_cart_sessions) AS viol_cart,
  COUNTIF(strict_click_sessions > reach_click_sessions) AS viol_click,
  COUNTIF(strict_view_sessions > reach_view_sessions) AS viol_view
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_kpi_window`;

