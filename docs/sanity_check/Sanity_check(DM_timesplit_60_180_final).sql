-- # Row count = users 확인
SELECT (SELECT COUNT(*) FROM `eternal-argon-479503-e8.ecommerce_dm.DM_timesplit_60_180_final`) AS dm_rows,
       (SELECT COUNT(*) FROM `eternal-argon-479503-e8.ecommerce.users`) AS users_rows;


-- # Null 체크 (signup_date/activation_stage)
SELECT COUNTIF(signup_date IS NULL) AS null_signup,
       COUNTIF(activation_stage_14d IS NULL) AS null_activation_stage

FROM `eternal-argon-479503-e8.ecommerce_dm.DM_timesplit_60_180_final`;


--# Activation stage 분포 체크 
SELECT activation_stage_14d,
       COUNT(*) AS users

FROM `eternal-argon-479503-e8.ecommerce_dm.DM_timesplit_60_180_final`
GROUP BY 1
ORDER BY 1;

--# window 체크 active_days / session_cnt
SELECT MIN(active_days_obs_60d) AS min_active_days,
       MAX(active_days_obs_60d) AS max_active_days,
       MIN(session_cnt_obs_60d) AS min_sessions,
       MAX(session_cnt_obs_60d) AS max_sessions

FROM `eternal-argon-479503-e8.ecommerce_dm.DM_timesplit_60_180_final`;


-- consistency score null 비율
SELECT COUNT(*) AS users,
       COUNTIF(consistency_score_obs_60d IS NULL) AS null_score_users,
       SAFE_DIVIDE(COUNTIF(consistency_score_obs_60d IS NULL), COUNT(*)) AS null_score_rate

FROM `eternal-argon-479503-e8.ecommerce_dm.DM_timesplit_60_180_final`;

-- retention last week 분포 
SELECT retention_last_week_180d,
       COUNT(*) AS users

FROM `eternal-argon-479503-e8.ecommerce_dm.DM_timesplit_60_180_final`
GROUP BY 1;


