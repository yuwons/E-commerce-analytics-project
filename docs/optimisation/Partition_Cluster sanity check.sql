SELECT 'events' ,
  (SELECT COUNT(*) FROM `eternal-argon-479503-e8.ecommerce.events_old_20251226`) as old_cnt,
  (SELECT COUNT(*) FROM `eternal-argon-479503-e8.ecommerce.events`) as new_cnt
UNION ALL
SELECT 'sessions',
  (SELECT COUNT(*) FROM `eternal-argon-479503-e8.ecommerce.sessions_old_20251226`) as old_cnt,
  (SELECT COUNT(*) FROM `eternal-argon-479503-e8.ecommerce.sessions`) as new_cnt 
UNION ALL
SELECT 'orders',
  (SELECT COUNT(*) FROM `eternal-argon-479503-e8.ecommerce.orders_old_20251226`) as old_cnt,
  (SELECT COUNT(*) FROM `eternal-argon-479503-e8.ecommerce.orders`) as new_cnt;

--===================Before partitioning/clustering ==================
--event before
SELECT
  event_type,
  COUNT(*) AS events
FROM `eternal-argon-479503-e8.ecommerce.events_raw`
WHERE DATE(event_ts) BETWEEN '2025-06-01' AND '2025-06-30'
  AND event_type IN ('view','click','add_to_cart','checkout','purchase')
  AND RAND() < 2  -- cache bust (항상 true)
GROUP BY 1;


--session before 
SELECT
  device,
  COUNT(*) AS sessions
FROM `eternal-argon-479503-e8.ecommerce.session_raw`
WHERE DATE(session_start_ts) BETWEEN '2025-06-01' AND '2025-06-30'
  AND RAND() < 2  -- cache bust (항상 true)
GROUP BY 1
ORDER BY sessions DESC;


--order before

SELECT
  is_promo,
  COUNT(*) AS orders
FROM `eternal-argon-479503-e8.ecommerce.orders_raw`
WHERE DATE(order_ts) BETWEEN '2025-06-01' AND '2025-06-30'
  AND RAND() < 2  -- cache bust
GROUP BY 1
ORDER BY orders DESC;


--================= After Partitioning/clustering=======================
--event after
SELECT
  event_type,
  COUNT(*) AS events
FROM `eternal-argon-479503-e8.ecommerce.events`
WHERE DATE(event_ts) BETWEEN '2025-06-01' AND '2025-06-30'
  AND event_type IN ('view','click','add_to_cart','checkout','purchase')
  AND RAND() < 2  -- cache bust
GROUP BY 1;

--session after
SELECT
  device,
  COUNT(*) AS sessions
FROM `eternal-argon-479503-e8.ecommerce.sessions`
WHERE DATE(session_start_ts) BETWEEN '2025-06-01' AND '2025-06-30'
  AND RAND() < 2  -- cache bust
GROUP BY 1
ORDER BY sessions DESC;

--order after
SELECT
  is_promo,
  COUNT(*) AS orders
FROM `eternal-argon-479503-e8.ecommerce.orders`
WHERE DATE(order_ts) BETWEEN '2025-06-01' AND '2025-06-30'
  AND RAND() < 2  -- cache bust
GROUP BY 1
ORDER BY orders DESC;

