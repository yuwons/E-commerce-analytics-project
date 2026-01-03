-- events_p
CREATE OR REPLACE TABLE `eternal-argon-479503-e8.ecommerce.events_p`
PARTITION BY DATE(event_ts)
CLUSTER BY user_id, session_id, event_type AS
SELECT * FROM `eternal-argon-479503-e8.ecommerce.events`;

-- sessions_p
CREATE OR REPLACE TABLE `eternal-argon-479503-e8.ecommerce.sessions_p`
PARTITION BY DATE(session_start_ts)
CLUSTER BY user_id, session_id AS
SELECT * FROM `eternal-argon-479503-e8.ecommerce.sessions`;

-- orders_p
CREATE OR REPLACE TABLE `eternal-argon-479503-e8.ecommerce.orders_p`
PARTITION BY DATE(order_ts)
CLUSTER BY user_id AS
SELECT * FROM `eternal-argon-479503-e8.ecommerce.orders`;


-- swap (add date suffix to avoid collision)
ALTER TABLE `eternal-argon-479503-e8.ecommerce.events`     RENAME TO `events_old_20251226`;
ALTER TABLE `eternal-argon-479503-e8.ecommerce.events_p`   RENAME TO `events`;

ALTER TABLE `eternal-argon-479503-e8.ecommerce.sessions`   RENAME TO `sessions_old_20251226`;
ALTER TABLE `eternal-argon-479503-e8.ecommerce.sessions_p` RENAME TO `sessions`;

ALTER TABLE `eternal-argon-479503-e8.ecommerce.orders`     RENAME TO `orders_old_20251226`;
ALTER TABLE `eternal-argon-479503-e8.ecommerce.orders_p`   RENAME TO `orders`;
