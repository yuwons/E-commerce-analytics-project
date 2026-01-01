--# Row count가 session 필터와 같아야 함
SELECT
  (SELECT COUNT(*) FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`) AS dm_rows,
  (SELECT COUNT(*)
   FROM `eternal-argon-479503-e8.ecommerce.sessions` s
   JOIN `eternal-argon-479503-e8.ecommerce.users` u USING(user_id)
   WHERE DATE(CAST(s.session_start_ts AS TIMESTAMP)) >= DATE(u.signup_date)
     AND DATE(CAST(s.session_start_ts AS TIMESTAMP)) <  DATE_ADD(DATE(u.signup_date), INTERVAL 180 DAY)
  ) AS expected_rows;

--# quick path = 0 확인 (checkout 있는데 cart 없는 세션)
SELECT COUNTIF(has_checkout AND NOT has_add_to_cart) AS quick_path_sessions
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`;


--# Strict는 Reach의 subset (strict_purchase인데 has_purchase가 false면 말이 안 됨)
SELECT
  COUNTIF(strict_purchase AND NOT has_purchase) AS viol1,
  COUNTIF(strict_checkout AND NOT has_checkout) AS viol2,
  COUNTIF(strict_add_to_cart AND NOT has_add_to_cart) AS viol3,
  COUNTIF(strict_click AND NOT has_click) AS viol4
FROM `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`;