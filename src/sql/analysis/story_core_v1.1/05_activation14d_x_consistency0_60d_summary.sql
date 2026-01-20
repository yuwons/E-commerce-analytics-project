-- C') Story-friendly summary
-- Activation bucket (14d) , Consistency segment (0-60d) -> Outcomes (60-180d)

WITH base AS 
(
  SELECT CASE WHEN activation_stage_14d IN ('A0_no_activity','A1_view') THEN 'Act_Low (A0-A1)'
              WHEN activation_stage_14d IN ('A2_click','A3_add_to_cart') THEN 'Act_Mid (A2-A3)'
              ELSE 'Act_High (A4-A5)'
         END AS activation_bucket_14d,
    consistency_segment_obs_60d AS consistency_seg,
    has_purchase_60_180,
    revenue_60_180,
    retention_last_week_180d
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_timesplit_60_180_final`
)

SELECT activation_bucket_14d,
       consistency_seg,
       COUNT(*) AS users,
       ROUND(AVG(CAST(has_purchase_60_180 AS INT64)),4) AS purchase_rate_60_180,
       ROUND(AVG(COALESCE(revenue_60_180, 0)),4) AS avg_revenue_60_180,
       ROUND(AVG(CAST(retention_last_week_180d AS INT64)),4) AS retention_last_week_180d_rate

FROM base

GROUP BY activation_bucket_14d, consistency_seg

ORDER BY activation_bucket_14d, consistency_seg;
