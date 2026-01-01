CREATE OR REPLACE TABLE `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`
PARTITION BY signup_date
CLUSTER BY user_id AS

/*===============================
DM_Ltv_180d (1 row = 1 user)
- Outcome DM: 180d revenue / orders / AOV etc
- Revenue = SUM(order_items.line_amount) within singup+180d window
=================================*/

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
bounds as 
(
  SELECT MIN(signup_date) as min_signup,
         MAX(signup_date) as max_signup

  FROM users_base
),
-- # orders 기간 제한 time window 180days
orders_filt as
(
  SELECT o.user_id,
         o.order_id,
         DATE(CAST(o.order_ts AS TIMESTAMP)) AS order_date,
         o.is_promo,
         o.discount_rate,
         o.promo_id
  FROM `eternal-argon-479503-e8.ecommerce.orders` o, bounds
  WHERE DATE(CAST(o.order_ts AS TIMESTAMP)) >= bounds.min_signup
    AND DATE(CAST(o.order_ts AS TIMESTAMP)) <  DATE_ADD(bounds.max_signup, INTERVAL 180 DAY)

),

--# user 별 180d 윈도우 적용
orders_180d as 
(
  SELECT u.user_id,
         u.signup_date,
         o.order_id,
         o.order_date,
         o.is_promo,
         o.discount_rate,
         o.promo_id
  
  FROM users_base u LEFT JOIN orders_filt o
       ON o.user_id = u.user_id
       AND o.order_date >= u.signup_date
       AND o.order_date <  DATE_ADD(u.signup_date, INTERVAL 180 DAY)
),

--# Get revenue = sum(line_amount)
order_rev as
(
  SELECT oi.order_id,
         SUM(oi.line_amount) as order_revenue

  FROM `eternal-argon-479503-e8.ecommerce.order_items` oi
  
  GROUP BY oi.order_id

),
--# 주문 단위로 revenue 붙이기
orders_with_rev as 
(
  SELECT o.user_id,
         o.signup_date,
         o.order_id,
         o.order_date,
         o.is_promo,
         o.discount_rate,
         o.promo_id,
         r.order_revenue
  
  FROM orders_180d o LEFT JOIN order_rev r
       ON r.order_id = o.order_id

),

--# user-level LTV 합산

ltv_agg as
(
  SELECT u.user_id,
         u.signup_date,

         COUNT(DISTINCT o.order_id) AS orders_180d,
         SUM(IFNULL(o.order_revenue, 0)) AS revenue_180d,

        -- 구매 여부/첫 구매일
         (COUNT(DISTINCT o.order_id) > 0) AS has_purchase_180d,
         MIN(o.order_date) AS first_order_date_180d,

        -- AOV(주문당 평균 매출)
         SAFE_DIVIDE(SUM(IFNULL(o.order_revenue, 0)), NULLIF(COUNT(DISTINCT o.order_id), 0)) AS aov_180d,

        -- promo outcome (180d 기준)
         COUNT(DISTINCT IF(o.is_promo = 1, o.order_id, NULL)) AS promo_orders_180d,
         SUM(IF(o.is_promo = 1, IFNULL(o.order_revenue, 0), 0)) AS promo_revenue_180d

  FROM users_base u LEFT JOIN orders_with_rev o
       ON o.user_id = u.user_id

  GROUP BY u.user_id, u.signup_date
)
--# Final SELECT statement including all of above
SELECT u.user_id,
       u.signup_date,
       u.user_type,
       u.device,
       u.region,
       u.marketing_source,
       u.anomaly_flag,

       l.orders_180d,
       l.revenue_180d,
       l.has_purchase_180d,
       l.first_order_date_180d,
       l.aov_180d,

       l.promo_orders_180d,
       l.promo_revenue_180d

FROM users_base u LEFT JOIN ltv_agg l
     ON l.user_id = u.user_id;

