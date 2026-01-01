-- ## 중요 포인트 
-- session, events 둘다 TIMESTAMP 로 CAST 필요. 시간에 따라 session 수 계산하기위해

CREATE OR REPLACE TABLE `eternal-argon-479503-e8.ecommerce_dm.DM_funnel_session`
PARTITION BY session_date
CLUSTER BY user_id, session_id AS

--# Create base user 
WITH users_base as
(
  SELECT user_id,
         DATE(signup_date) as signup_date

  FROM `eternal-argon-479503-e8.ecommerce.users`
),
--# Create time boundary by signup_date
bounds as
(
  SELECT MIN(signup_date) as min_signup,
         MAX(signup_date) as max_signup
  
  FROM users_base
),
--# Create session base. Critical condition
-- CAST TIMESTAMP 필요, 시간떄별로 SESSION 계산위해
-- session_start_ts >= min_signup and session_start_ts < max_signup
sessions_base as 
(
  SELECT s.session_id,
         s.user_id,
         CAST(s.session_start_ts AS TIMESTAMP) AS session_start_ts,
         DATE(CAST(s.session_start_ts AS TIMESTAMP)) AS session_date,
         s.user_type,
         s.device,
         s.is_promo,
         s.discount_rate,
         s.promo_id

  FROM `eternal-argon-479503-e8.ecommerce.sessions` s, bounds
  WHERE DATE(CAST(s.session_start_ts AS TIMESTAMP)) >= bounds.min_signup
    AND DATE(CAST(s.session_start_ts AS TIMESTAMP)) <  DATE_ADD(bounds.max_signup, INTERVAL 180 DAY)

),
-- SELECT * FROM sessions_base LIMIT 100;
--# 이벤트도 session base 랑 같은 원리
events_base as 
(
  SELECT e.user_id,
         e.session_id,
         e.event_type,
         CAST(e.event_ts AS TIMESTAMP) AS event_ts,
         e.order_id,
         e.product_id

  FROM `eternal-argon-479503-e8.ecommerce.events` e, bounds
  WHERE DATE(CAST(e.event_ts AS TIMESTAMP)) >= bounds.min_signup
    AND DATE(CAST(e.event_ts AS TIMESTAMP)) <  DATE_ADD(bounds.max_signup, INTERVAL 180 DAY)
    AND e.event_type IN ('view','click','add_to_cart','checkout','purchase')
),
-- SELECT * FROM events_base LIMIT 100;

--# Make data pivot table format
events_pivot as
(
  SELECT user_id,
         session_id,

         -- 유저별 각 세션에서 각 이벤트마다 처음 발생한 시각 저장
         MIN(IF(event_type='view',event_ts, NULL)) as view_ts,
         MIN(IF(event_type='click',event_ts, NULL)) as click_ts,
         MIN(IF(event_type='add_to_cart',event_ts, NULL)) as add_to_cart_ts,
         MIN(IF(event_type='checkout',event_ts, NULL)) as checkout_ts,
         MIN(IF(event_type='purchase',event_ts, NULL)) as purchase_ts,
         
         -- 각 스텝 합계 
         COUNTIF(event_type='view') as view_cnt,
         COUNTIF(event_type='click') as click_cnt,
         COUNTIF(event_type='add_to_cart') as add_to_cart_cnt,
         COUNTIF(event_type='checkout') as checkout_cnt,
         COUNTIF(event_type='purchase') as purchase_cnt,
         
         -- purchase 까지 갔다면 order_id 하나 저장
         MAX(IF(event_type='purchase', order_id, NULL)) as order_id

  FROM events_base

  GROUP BY 1,2

)
-- SELECT * FROM events_pivot 

SELECT s.session_id,
       s.user_id,
       u.signup_date,
       s.session_start_ts,
       s.session_date,
       
       -- signup 이후 session 이 언제 발생했는지 확인
       DATE_DIFF(s.session_date, u.signup_date, DAY) AS days_since_signup,
       (s.session_date >= u.signup_date AND s.session_date < DATE_ADD(u.signup_date, INTERVAL 14 DAY)) AS is_in_14d,
       (s.session_date >= u.signup_date AND s.session_date < DATE_ADD(u.signup_date, INTERVAL 30 DAY)) AS is_in_30d,

       s.user_type,
       s.device,
       s.is_promo,
       s.discount_rate,
       s.promo_id,

       -- Reach flags (해당 세션에서 발생 여부)
       (p.view_ts IS NOT NULL)        AS has_view,
       (p.click_ts IS NOT NULL)       AS has_click,
       (p.add_to_cart_ts IS NOT NULL) AS has_add_to_cart,
       (p.checkout_ts IS NOT NULL)    AS has_checkout,
       (p.purchase_ts IS NOT NULL)    AS has_purchase,

      -- First timestamps
       p.view_ts, p.click_ts, p.add_to_cart_ts, p.checkout_ts, p.purchase_ts,

      -- Counts
       p.view_cnt, p.click_cnt, p.add_to_cart_cnt, p.checkout_cnt, p.purchase_cnt,

      -- purchase ↔ orders 정합용
       p.order_id,

      -- Strict flags (순서 정상: view→click→cart→checkout→purchase)
       (p.view_ts IS NOT NULL) AS strict_view,
       (p.view_ts IS NOT NULL AND p.click_ts IS NOT NULL AND p.view_ts <= p.click_ts) AS strict_click,
       (p.view_ts IS NOT NULL AND p.click_ts IS NOT NULL AND p.add_to_cart_ts IS NOT NULL
        AND p.view_ts <= p.click_ts AND p.click_ts <= p.add_to_cart_ts) AS strict_add_to_cart,
       (p.view_ts IS NOT NULL AND p.click_ts IS NOT NULL AND p.add_to_cart_ts IS NOT NULL AND p.checkout_ts IS NOT NULL
        AND p.view_ts <= p.click_ts AND p.click_ts <= p.add_to_cart_ts AND p.add_to_cart_ts <= p.checkout_ts) AS strict_checkout,
       (p.view_ts IS NOT NULL AND p.click_ts IS NOT NULL AND p.add_to_cart_ts IS NOT NULL AND p.checkout_ts IS NOT NULL AND p.purchase_ts IS NOT NULL
        AND p.view_ts <= p.click_ts AND p.click_ts <= p.add_to_cart_ts AND p.add_to_cart_ts <= p.checkout_ts AND p.checkout_ts <= p.purchase_ts) AS strict_purchase

FROM sessions_base s INNER JOIN users_base u
      ON u.user_id = s.user_id LEFT JOIN events_pivot p
        ON p.user_id = s.user_id AND p.session_id = s.session_id;