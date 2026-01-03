CREATE OR REPLACE TABLE `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`
PARTITION BY signup_date 
CLUSTER BY user_id AS 

--# Get user information from users_target
WITH users_base as 
(
  SELECT user_id,
         DATE(signup_date) as signup_date,
         user_type,
         device,
         region,
         marketing_source,
         anomaly_flag
  
  FROM `eternal-argon-479503-e8.ecommerce.users`
),
--# Get boundary of signup_date for users
bounds as 
(
  SELECT MIN(signup_date) as min_signup,
         MAX(signup_date) as max_signup

  FROM users_base
),
--# 전체 스캔 방지용 (파티션 프루닝 유도) : 전체 기간을 먼저 좁히기
-- bounds cte 사용해서 기간 조정 이벤트는 무조건 >= min_signup 
-- 그리고 180일 이 timewindow 니 event_ts < max_singup + 180 
events_filt as 
(
  SELECT user_id,
         DATE(event_ts) AS event_date,
         event_type,
         session_id
  
  FROM `eternal-argon-479503-e8.ecommerce.events`, bounds
  WHERE DATE(event_ts) >= bounds.min_signup
    AND DATE(event_ts) <  DATE_ADD(bounds.max_signup, INTERVAL 180 DAY)
),
-- SELECT * FROM events_filt LIMIT 100; // quick check table
-- events 와 같은 원리
sessions_filt AS (
  SELECT user_id,
         DATE(session_start_ts) AS session_date,
         session_id,
         is_promo

  FROM `eternal-argon-479503-e8.ecommerce.sessions`, bounds
  WHERE DATE(session_start_ts) >= bounds.min_signup
    AND DATE(session_start_ts) < DATE_ADD(bounds.max_signup, INTERVAL 180 DAY)
),
#event 와 같은 원리 
-- SELECT * FROM sessions_filt LIMIT 100; // quick check table
orders_filt as
(
  SELECT user_id,
         DATE(order_ts) as order_date,
         order_id,
         is_promo
  
  FROM `eternal-argon-479503-e8.ecommerce.orders`, bounds
  WHERE DATE(order_ts) >= bounds.min_signup
    AND DATE(order_ts) <  DATE_ADD(bounds.max_signup, INTERVAL 180 DAY)
),
-- SELECT * FROM orders_filt LIMIT 100;
-- create revenue filter same rule
order_rev_filt as
(
  SELECT o.user_id,
         o.order_id,
         DATE(o.order_ts) as order_date,
         SUM(t.line_amount) as revenue

  FROM `eternal-argon-479503-e8.ecommerce.orders` o
  INNER JOIN `eternal-argon-479503-e8.ecommerce.order_items` t
    ON o.order_id = t.order_id

  WHERE DATE(o.order_ts) >= (SELECT min_signup FROM bounds)
    AND DATE(o.order_ts) <  DATE_ADD((SELECT max_signup FROM bounds), INTERVAL 180 DAY)
  
  GROUP BY 1,2,3 
),
-- 아직 고민단계 여기서 orders table 을 다시 조인할지 아니면 order_filt cte 를 사용할지.
--SELECT * FROM order_rev_filt limit 100;

/*
Note : 이전 단계 cte 에서는 timewindow 로 event, order, session 테이블
데이터 스캔을 줄이기 위해서 min_signup ≤ order_date < max_signup + 180 
타임 제약. 이제 user 별 agg 을 위해 유저 테이블과 조인을 할떄는
다시 유저별 가입일 기준 time window 를 다시 걸어줘야됨. 
*/
-- # Aggregate event count
event_agg as 
(
  SELECT u.user_id,
    -- 14d funnel reach (events 기반) return boolean 1 true 0 false
        --COUNTIF(e.event_type='view' AND e.event_date >= u.signup_date AND e.event_date < DATE_ADD(u.signup_date, INTERVAL 14 DAY)) > 0 AS has_view_14d
        MAX(IF(e.event_type='view'        AND e.event_date >= u.signup_date AND e.event_date < DATE_ADD(u.signup_date, INTERVAL 14 DAY), 1, 0))=1 AS has_view_14d,
        MAX(IF(e.event_type='click'       AND e.event_date >= u.signup_date AND e.event_date < DATE_ADD(u.signup_date, INTERVAL 14 DAY), 1, 0))=1 AS has_click_14d,
        MAX(IF(e.event_type='add_to_cart' AND e.event_date >= u.signup_date AND e.event_date < DATE_ADD(u.signup_date, INTERVAL 14 DAY), 1, 0))=1 AS has_add_to_cart_14d,
        MAX(IF(e.event_type='checkout'    AND e.event_date >= u.signup_date AND e.event_date < DATE_ADD(u.signup_date, INTERVAL 14 DAY), 1, 0))=1 AS has_checkout_14d,

    -- 30d funnel reach (events 기반) return boolean 1 true 0 false
        MAX(IF(e.event_type='view'        AND e.event_date >= u.signup_date AND e.event_date < DATE_ADD(u.signup_date, INTERVAL 30 DAY), 1, 0))=1 AS has_view_30d,
        MAX(IF(e.event_type='click'       AND e.event_date >= u.signup_date AND e.event_date < DATE_ADD(u.signup_date, INTERVAL 30 DAY), 1, 0))=1 AS has_click_30d,
        MAX(IF(e.event_type='add_to_cart' AND e.event_date >= u.signup_date AND e.event_date < DATE_ADD(u.signup_date, INTERVAL 30 DAY), 1, 0))=1 AS has_add_to_cart_30d,
        MAX(IF(e.event_type='checkout'    AND e.event_date >= u.signup_date AND e.event_date < DATE_ADD(u.signup_date, INTERVAL 30 DAY), 1, 0))=1 AS has_checkout_30d,

    -- 180d control (events volume)
        COUNTIF(e.event_date >= u.signup_date AND e.event_date < DATE_ADD(u.signup_date, INTERVAL 180 DAY)) AS event_cnt_180d

  FROM users_base u LEFT JOIN events_filt e
      ON e.user_id = u.user_id
  
  GROUP BY u.user_id
),
--# Aggrecate session count
session_agg AS (
  SELECT u.user_id,
         COUNTIF(s.session_date >= u.signup_date AND s.session_date < DATE_ADD(u.signup_date, INTERVAL 180 DAY)) AS session_cnt_180d,
         COUNTIF(s.is_promo = 1 AND s.session_date >= u.signup_date AND s.session_date < DATE_ADD(u.signup_date, INTERVAL 30 DAY)) AS promo_session_cnt_30d
  
  FROM users_base u LEFT JOIN sessions_filt s
      ON s.user_id = u.user_id
  
  GROUP BY u.user_id
),
--SELECT * FROM session_agg LIMIT 100;
--# aggreate order count
order_agg as
(
  SELECT u.user_id,
      -- purchase는 orders 기준(정합성: purchase 1 = orders 1)
         COUNT(DISTINCT IF(o.order_date >= u.signup_date AND o.order_date < DATE_ADD(u.signup_date, INTERVAL 14 DAY), o.order_id, NULL)) AS orders_14d,
         COUNT(DISTINCT IF(o.order_date >= u.signup_date AND o.order_date < DATE_ADD(u.signup_date, INTERVAL 30 DAY), o.order_id, NULL)) AS orders_30d,
         COUNT(DISTINCT IF(o.order_date >= u.signup_date AND o.order_date < DATE_ADD(u.signup_date, INTERVAL 180 DAY), o.order_id, NULL)) AS orders_180d,

      -- get the revenue = order_items 합 (line_amount)
         SUM(IF(r.order_date >= u.signup_date AND r.order_date < DATE_ADD(u.signup_date, INTERVAL 14 DAY), r.revenue, 0)) AS revenue_14d,
         SUM(IF(r.order_date >= u.signup_date AND r.order_date < DATE_ADD(u.signup_date, INTERVAL 30 DAY), r.revenue, 0)) AS revenue_30d,
         SUM(IF(r.order_date >= u.signup_date AND r.order_date < DATE_ADD(u.signup_date, INTERVAL 180 DAY), r.revenue, 0)) AS revenue_180d,

         COUNT(DISTINCT IF(o.is_promo = 1 AND o.order_date >= u.signup_date AND o.order_date < DATE_ADD(u.signup_date, INTERVAL 30 DAY), o.order_id, NULL)) AS promo_orders_30d

  FROM users_base u LEFT JOIN orders_filt o
      ON o.user_id = u.user_id LEFT JOIN order_rev_filt r
        ON r.user_id = u.user_id AND r.order_id = o.order_id
  
  GROUP BY u.user_id
)
--# combine all above
SELECT
  u.user_id,
  u.signup_date,
  u.user_type,
  u.device,
  u.region,
  u.marketing_source,
  u.anomaly_flag,

  e.has_view_14d,
  e.has_click_14d,
  e.has_add_to_cart_14d,
  e.has_checkout_14d,

  e.has_view_30d,
  e.has_click_30d,
  e.has_add_to_cart_30d,
  e.has_checkout_30d,

  -- purchase reach는 orders로 정의 boolean flag 생성
  (o.orders_14d > 0) AS has_purchase_14d,
  (o.orders_30d > 0) AS has_purchase_30d,

  o.orders_14d,  o.revenue_14d,
  o.orders_30d,  o.revenue_30d,
  o.orders_180d, o.revenue_180d,

  s.session_cnt_180d,
  e.event_cnt_180d,

  s.promo_session_cnt_30d,
  o.promo_orders_30d

FROM users_base u LEFT JOIN event_agg e
      on u.user_id = e.user_id LEFT JOIN session_agg s 
        on u.user_id = s.user_id LEFT JOIN order_agg o
          on u.user_id = o.user_id
