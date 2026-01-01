/* =========================================================
[HEADLINE] C5 vs C1 Lift by Activation (6 rows)
- 목적: "Activation만으로는 부족하고, Consistency가 장기 성과를 크게 분리"를
        한 표로 빠르게 보여주기
- 비교: 각 activation_stage_14d 내에서 C5_high_consistency vs C1_low_consistency
- 지표:
  1) retention_last_week_173_179 (point retention proxy)
  2) avg_revenue_180d (overall, 0 포함)
  3) purchase_rate_180d (보조)
========================================================= */

WITH
activation AS (
  SELECT
    user_id,
    DATE(signup_date) AS signup_date,
    anomaly_flag,
    CASE
      WHEN has_purchase_14d THEN 'A5_purchase'
      WHEN has_checkout_14d THEN 'A4_checkout'
      WHEN has_add_to_cart_14d THEN 'A3_add_to_cart'
      WHEN has_click_14d THEN 'A2_click'
      WHEN has_view_14d THEN 'A1_view'
      ELSE 'A0_no_activity'
    END AS activation_stage_14d
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_user_window`
),

consistency_raw AS (
  SELECT user_id, consistency_score_v1
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`
),
consistency_nonnull AS (
  SELECT user_id, consistency_score_v1
  FROM consistency_raw
  WHERE consistency_score_v1 IS NOT NULL
),
consistency_ntile AS (
  SELECT user_id, NTILE(5) OVER (ORDER BY consistency_score_v1) AS seg5
  FROM consistency_nonnull
),
consistency AS (
  SELECT
    r.user_id,
    CASE
      WHEN n.seg5 = 1 THEN 'C1_low_consistency'
      WHEN n.seg5 = 5 THEN 'C5_high_consistency'
      ELSE NULL
    END AS consistency_segment
  FROM consistency_raw r
  LEFT JOIN consistency_ntile n USING(user_id)
),

ltv AS (
  SELECT
    user_id,
    revenue_180d,
    has_purchase_180d
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_ltv_180d`
),

sessions AS (
  SELECT
    user_id,
    DATE(CAST(session_start_ts AS TIMESTAMP)) AS session_date
  FROM `eternal-argon-479503-e8.ecommerce.sessions`
),

retention_flags AS (
  SELECT
    a.user_id,
    MAX(IF(DATE_DIFF(s.session_date, a.signup_date, DAY) BETWEEN 173 AND 179, 1, 0)) AS active_last_week_173_179
  FROM activation a
  LEFT JOIN sessions s USING(user_id)
  WHERE a.anomaly_flag = 0
  GROUP BY 1
),

base AS (
  SELECT
    a.activation_stage_14d,
    c.consistency_segment,
    l.revenue_180d,
    l.has_purchase_180d,
    r.active_last_week_173_179
  FROM activation a
  JOIN consistency c USING(user_id)
  LEFT JOIN ltv l USING(user_id)
  LEFT JOIN retention_flags r USING(user_id)
  WHERE a.anomaly_flag = 0
    AND c.consistency_segment IS NOT NULL   -- C1/C5만 유지
),

agg AS (
  SELECT
    activation_stage_14d,
    consistency_segment,
    COUNT(*) AS users,
    AVG(CAST(has_purchase_180d AS INT64)) AS purchase_rate_180d,
    AVG(revenue_180d) AS avg_revenue_180d,
    AVG(active_last_week_173_179) AS retention_last_week_173_179
  FROM base
  GROUP BY 1,2
),

c1 AS (
  SELECT * FROM agg WHERE consistency_segment = 'C1_low_consistency'
),
c5 AS (
  SELECT * FROM agg WHERE consistency_segment = 'C5_high_consistency'
)

SELECT
  c1.activation_stage_14d,

  -- sample sizes
  c1.users AS users_c1,
  c5.users AS users_c5,

  -- levels
  c1.purchase_rate_180d AS purchase_rate_180d_c1,
  c5.purchase_rate_180d AS purchase_rate_180d_c5,
  c1.avg_revenue_180d    AS avg_revenue_180d_c1,
  c5.avg_revenue_180d    AS avg_revenue_180d_c5,
  c1.retention_last_week_173_179 AS retention_last_week_c1,
  c5.retention_last_week_173_179 AS retention_last_week_c5,

  -- lifts (absolute)
  (c5.purchase_rate_180d - c1.purchase_rate_180d) AS purchase_rate_lift_abs,
  (c5.avg_revenue_180d  - c1.avg_revenue_180d)    AS avg_revenue_lift_abs,
  (c5.retention_last_week_173_179 - c1.retention_last_week_173_179) AS retention_last_week_lift_abs,

  -- lifts (relative)
  SAFE_DIVIDE(c5.purchase_rate_180d - c1.purchase_rate_180d, NULLIF(c1.purchase_rate_180d, 0)) AS purchase_rate_lift_ratio,
  SAFE_DIVIDE(c5.avg_revenue_180d  - c1.avg_revenue_180d,   NULLIF(c1.avg_revenue_180d, 0))   AS avg_revenue_lift_ratio,
  SAFE_DIVIDE(c5.retention_last_week_173_179 - c1.retention_last_week_173_179,
              NULLIF(c1.retention_last_week_173_179, 0)) AS retention_last_week_lift_ratio

FROM c1
JOIN c5
  ON c1.activation_stage_14d = c5.activation_stage_14d
ORDER BY
  CASE c1.activation_stage_14d
    WHEN 'A0_no_activity' THEN 0
    WHEN 'A1_view' THEN 1
    WHEN 'A2_click' THEN 2
    WHEN 'A3_add_to_cart' THEN 3
    WHEN 'A4_checkout' THEN 4
    WHEN 'A5_purchase' THEN 5
    ELSE 99
  END;
