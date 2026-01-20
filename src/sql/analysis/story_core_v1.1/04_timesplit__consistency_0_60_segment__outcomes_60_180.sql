-- v1.1 핵심 결과 뽑기
-- Consistency segment (0-60d) -> Future outcomes (60-180d)

SELECT consistency_segment_obs_60d AS consistency_seg,
       COUNT(*) AS users,
       SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER()) AS user_distribution,

       -- 60-180 outcomes
       ROUND(AVG(COALESCE(revenue_60_180, 0)),4) AS avg_revenue_60_180,
       ROUND(AVG(CAST(has_purchase_60_180 AS INT64)),4) AS purchase_rate_60_180,
       ROUND(AVG(CAST(retention_last_week_180d AS INT64)),4) AS retention_last_week_180d_rate,

       -- supporting metrics (optional)
       ROUND(AVG(COALESCE(orders_60_180, 0)),4) AS avg_orders_60_180,
       ROUND(AVG(COALESCE(aov_60_180, 0)),4) AS avg_aov_60_180

FROM `eternal-argon-479503-e8.ecommerce_dm.DM_timesplit_60_180_final`

GROUP BY consistency_seg

ORDER BY consistency_seg;  -- C1 -> C5
