/*-----------------------------------------------------------------------------------
Key Point for Persona_Analysis
Persona summary for Story

Activation: High = A4/A5 (checkout or purchase within 14d)
Consistency: High = intervisit_cv_obs_60d <= median (computed on non-null CV)

NULL CV (e.g. <2 sessions) -> Low consistency (conservative)
------------------------------------------------------------------------------------*/

WITH base AS 
(
  SELECT user_id,
         activation_stage_14d,
         has_purchase_14d,
         intervisit_cv_obs_60d,
         revenue_60_180,
         has_purchase_60_180,
         retention_last_week_180d
  
  FROM `eternal-argon-479503-e8.ecommerce_dm.DM_timesplit_60_180_final`
),

cv_median AS 
(
  SELECT APPROX_QUANTILES(intervisit_cv_obs_60d, 101)[OFFSET(50)] AS cv_p50
  
  FROM base
  
  WHERE intervisit_cv_obs_60d IS NOT NULL
),

labeled AS 
(
  SELECT b.*,
         CASE
           WHEN b.activation_stage_14d IN ('A4_checkout', 'A5_purchase') THEN 1
           ELSE 0
         END AS is_act_high,

         CASE
           WHEN b.intervisit_cv_obs_60d IS NULL THEN 0
           WHEN b.intervisit_cv_obs_60d <= m.cv_p50 THEN 1
           ELSE 0
         END AS is_cons_high,

         m.cv_p50

  FROM base b
  CROSS JOIN cv_median m
),

persona AS 
(
  SELECT *,
         CASE
           WHEN is_act_high = 1 AND is_cons_high = 1 THEN 'D_Loyal'
           WHEN is_act_high = 1 AND is_cons_high = 0 THEN 'A_Burst'
           WHEN is_act_high = 0 AND is_cons_high = 1 THEN 'C_Steady'
           ELSE 'B_Observer'
         END AS user_persona
  
  FROM labeled
)

SELECT user_persona,
       COUNT(*) AS users,
       ROUND(SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER()),4) AS user_distribution,

       -- Early KPI (0-14)
       ROUND(AVG(CAST(has_purchase_14d AS INT64)),4) AS purchase_rate_14d,

       -- Long-term outcomes (60-180)
       ROUND(AVG(COALESCE(revenue_60_180, 0)),4) AS avg_revenue_60_180,
       ROUND(AVG(CAST(has_purchase_60_180 AS INT64)),4) AS purchase_rate_60_180,
       
       -- ROUND(AVG(CAST(retention_last_week_180d AS INT64)),4) AS retention_last_week_180d_rate,

       --ROUND(ANY_VALUE(cv_p50),4) AS intervisit_cv_obs_60d_median_cut

FROM persona

GROUP BY user_persona

ORDER BY user_distribution DESC;

