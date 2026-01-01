CREATE OR REPLACE TABLE `eternal-argon-479503-e8.ecommerce_dm.DM_consistency_180d`
PARTITION BY signup_date
CLUSTER BY user_id AS

WITH users_base as
(
  SELECT user_id,
         DATE(signup_date) as signup_date

  FROM `eternal-argon-479503-e8.ecommerce.users`

),
bounds as 
(
  SELECT MIN(signup_date) as min_signup,
         MAX(signup_date) as max_signup

  FROM users_base
),
-- session 을 Signup 기준 180 일로 기간 제한 
sessions_filt as
(
  SELECT session_id,
         user_id,
         DATE(CAST(session_start_ts AS TIMESTAMP)) as session_date

  FROM `eternal-argon-479503-e8.ecommerce.sessions`, bounds
  WHERE DATE(CAST(session_start_ts AS TIMESTAMP)) >= bounds.min_signup
    AND DATE(CAST(session_start_ts AS TIMESTAMP)) <  DATE_ADD(bounds.max_signup, INTERVAL 180 DAY)
),

-- users 별 180d 윈도우로 다시 필터
sessions_180d as
(
  SELECT u.user_id,
         u.signup_date,
         s.session_id,
         s.session_date
  
  FROM users_base u LEFT JOIN sessions_filt s
      ON u.user_id = s.user_id
      AND s.session_date >= u.signup_date
      AND s.session_date <  DATE_ADD(u.signup_date, INTERVAL 180 DAY)
),
-- SELECT * FROM sessions_180d LIMIT 100 // Quick check sessions_180d table 유저별로 정리확인
-- Create volume control: session_count / active days
session_basic as
(
  SELECT user_id,
         ANY_VALUE(signup_date) as signup_date,
         COUNT(DISTINCT session_id) as session_cnt_180d,
         COUNT(DISTINCT session_date) as active_days_180d
  
  FROM sessions_180d

  GROUP BY user_id
),
-- SELECT * FROM session_basic // Quick check 유저별 집계 

--# inter-visit (방문간격) 계산을 위한 Distinct 방문일 시퀀스 생성
sessions_days as
(
  SELECT DISTINCT user_id,
                  signup_date,
                  session_date
  
  FROM sessions_180d 

  WHERE session_date IS NOT NULL
),
--SELECT * FROM sessions_days LIMIT 100
--# DISTINCT 방문일에서 LAG 로 이전 방문일 가져와 gap(days) 계산
intervisit as 
(
  SELECT user_id,
         DATE_DIFF(
          session_date,
          LAG(session_date) OVER (PARTITION BY user_id ORDER BY session_date),
          DAY
         ) as intervisit_days
  
  FROM sessions_days
),

--# intervisit 통계 (첫방문은 gap = null 이므로 제외)
/* 함수 노트
STDDEV_SAMP (x) = 표본 표준편차 - 표준편차 (std)는 값들이 평균에서 얼마나 퍼져 있는지 변동성을 나타내는 지표
만약 intervisit_std_180d 가 크면 -> 방문 간격이 불규칙 하다는 의미 (Not consistent)

SAFE_DIVIDE (a,b) = 0 나누기/NULL 에러 방지 나눗셈. 
b 가 0 또는 NULL 이면 결과를 NULL 로 반환 (에러없이)

APPROX_QUANTILES(x, 101)[OFFSET(50)] = 근사 중앙값(median)
intervisit_median_180d 는 "보통 방문 간격" 의미

CV = Coefficient of Variation / 변동계수 -> CV = 표준편차 (std) / 평균 (mean)
intervisit_cv_180d = std / mean: 불규칙성의 핵심 지표
예시) 평균이 10 일인데 std 가 10 이면 CV = 1 -> 변동이 평균만큼 불규칙
      평균이 10 일인데 std 가 2 면 CV = 0.2 -> 꽤 규칙적
*/
intervisit_stats as
(
  SELECT u.user_id,
         AVG(i.intervisit_days) as intervisit_mean_180d,
         APPROX_QUANTILES(i.intervisit_days, 101)[OFFSET(50)] as intervisit_median_180d,
         STDDEV_SAMP(i.intervisit_days) as intervisit_std_180d,
         SAFE_DIVIDE(
          STDDEV_SAMP(i.intervisit_days),
          NULLIF(AVG(i.intervisit_days), 0)
         ) as intervisit_cv_180d

   FROM users_base u LEFT JOIN intervisit i
    ON i.user_id = u.user_id
  
  WHERE i.intervisit_days IS NOT NULL
  
  GROUP BY u.user_id
),
--SELECT * FROM intervisit_stats 

--# Weekly regularity
-- 가입후 180일동안 활동한 주가 몆주였는가, 주단위 consistency 체크
weekly_stats as
(
  SELECT u.user_id,
         COUNT(DISTINCT DATE_TRUNC(d.session_date, WEEK(MONDAY))) as active_weeks_180d,
         --# 윈도우 내 총 주 계산
         SAFE_DIVIDE(
          COUNT(DISTINCT DATE_TRUNC(d.session_date,WEEK(MONDAY))),
          ARRAY_LENGTH(
            GENERATE_DATE_ARRAY(
              DATE_TRUNC(u.signup_date,WEEK(MONDAY)),
              DATE_TRUNC(DATE_ADD(u.signup_date,INTERVAL 179 DAY), WEEK(MONDAY)),
              INTERVAL 7 DAY
            )
          )
         ) as weekly_active_ratio_180d

  FROM users_base u LEFT JOIN sessions_days d
    ON d.user_id = u.user_id
  
  GROUP BY u.user_id, u.signup_date
),
-- SELECT * FROM weekly_stats LIMIT 100;

-- Check 모든 세션 base 계산 체크 
/* 
SELECT u.user_id,
       u.signup_date,
       sb.session_cnt_180d,
       sb.active_days_180d,

       iv.intervisit_mean_180d,
       iv.intervisit_median_180d,
       iv.intervisit_std_180d,
       iv.intervisit_cv_180d,

       ws.active_weeks_180d,
       ws.weekly_active_ratio_180d

FROM users_base u LEFT JOIN session_basic sb 
      ON u.user_id = sb.user_id LEFT JOIN intervisit_stats iv 
        ON u.user_id = iv.user_id LEFT JOIN weekly_stats ws 
          ON u.user_id = ws.user_id

*/

--# Orders-based Consistency 위 session 과 똑같은 원리
orders_filt as 
(
  SELECT o.user_id,
         o.order_id,
         DATE(CAST(o.order_ts as TIMESTAMP)) as order_date

  FROM `eternal-argon-479503-e8.ecommerce.orders` o, bounds
  WHERE DATE(CAST(o.order_ts AS TIMESTAMP)) >= bounds.min_signup
    AND DATE(CAST(o.order_ts AS TIMESTAMP)) <  DATE_ADD(bounds.max_signup, INTERVAL 180 DAY)
),

orders_180d as
(
  SELECT u.user_id, 
         u.signup_date,
         o.order_id,
         o.order_date

  FROM users_base u LEFT JOIN orders_filt o
        ON o.user_id = u.user_id
        AND o.order_date >= u.signup_date
        AND o.order_date <  DATE_ADD(u.signup_date, INTERVAL 180 DAY)
),
-- SELECT * FROM orders_180d LIMIT 100;
-- # 주문량 + 첫 구매일
order_basic as 
(
  SELECT user_id,
         COUNT(DISTINCT order_id) as orders_180d,
         MIN(order_date) as first_order_date_180d
  
  FROM orders_180d

  GROUP BY user_id
),
-- repeat interval : DISTINCT 주문일 시퀀스 
order_days as 
(
  SELECT DISTINCT user_id,
                  order_date
  
  FROM orders_180d
  
  WHERE order_date IS NOT NULL

),
--SELECT * FROM order_days LIMIT 100;

-- 유저별 LAG 로 이전 구매일 가져와 gap(days) 계산
repeat_gaps as
(
  SELECT user_id,
         DATE_DIFF(
           order_date,
           LAG(order_date) OVER (PARTITION BY user_id ORDER BY order_date),
           DAY
         ) AS repeat_gap_days

  FROM order_days
),
-- SELECT * from repeat_gaps limit 100;

repeat_stats as
(
  SELECT u.user_id,
         AVG(IF(r.repeat_gap_days IS NOT NULL, r.repeat_gap_days, NULL)) AS repeat_interval_mean_180d,
         STDDEV_SAMP(IF(r.repeat_gap_days IS NOT NULL, r.repeat_gap_days, NULL)) AS repeat_interval_std_180d,
         SAFE_DIVIDE(
          STDDEV_SAMP(IF(r.repeat_gap_days IS NOT NULL, r.repeat_gap_days, NULL)),
          NULLIF(AVG(IF(r.repeat_gap_days IS NOT NULL, r.repeat_gap_days, NULL)), 0)
         ) AS repeat_interval_cv_180d

  FROM users_base u LEFT JOIN repeat_gaps r
         ON r.user_id = u.user_id
  
  GROUP BY u.user_id
),
-- # repurchase flags : 첫 구매 이후 몆일 내 재구매 여부 체크
repurchase_flag as
(
  SELECT u.user_id,
         -- first_order_date가 NULL이면 전부 FALSE
         IFNULL(
           COUNTIF(o.order_date > b.first_order_date_180d
                 AND o.order_date <= DATE_ADD(b.first_order_date_180d, INTERVAL 30 DAY)) > 0,
          FALSE
         ) AS repurchase_30d,

         IFNULL(
           COUNTIF(o.order_date > b.first_order_date_180d
                 AND o.order_date <= DATE_ADD(b.first_order_date_180d, INTERVAL 60 DAY)) > 0,
           FALSE
         ) AS repurchase_60d,

         IFNULL(
           COUNTIF(o.order_date > b.first_order_date_180d
                 AND o.order_date <= DATE_ADD(b.first_order_date_180d, INTERVAL 90 DAY)) > 0,
           FALSE
         ) AS repurchase_90d

  FROM users_base u LEFT JOIN order_basic b
        ON b.user_id = u.user_id  LEFT JOIN orders_180d o
          ON o.user_id = u.user_id
  
  GROUP BY u.user_id
),

--# Session, order 합쳐주기 
combined as 
(
  SELECT u.user_id,
         u.signup_date,
         
         sb.session_cnt_180d,
         sb.active_days_180d,

         iv.intervisit_mean_180d,
         iv.intervisit_median_180d,
         iv.intervisit_std_180d,
         iv.intervisit_cv_180d,

         ws.active_weeks_180d,
         ws.weekly_active_ratio_180d,

         ob.orders_180d,
         rs.repeat_interval_mean_180d,
         rs.repeat_interval_std_180d,
         rs.repeat_interval_cv_180d,

         ob.first_order_date_180d,
         rf.repurchase_30d,
         rf.repurchase_60d,
         rf.repurchase_90d

  FROM users_base u LEFT JOIN session_basic sb      
        ON u.user_id = sb.user_id LEFT JOIN intervisit_stats iv  
          ON u.user_id = iv.user_id LEFT JOIN weekly_stats ws 
            ON u.user_id = ws.user_id LEFT JOIN order_basic ob
              ON u.user_id = ob.user_id LEFT JOIN repeat_stats rs
                ON u.user_id = rs.user_id LEFT JOIN repurchase_flag rf
                  ON u.user_id = rf.user_id

)
-- v1 score = z(active_days) - z(intervisit_cv) 공식 
SELECT c.*,
  (
    SAFE_DIVIDE(
      c.active_days_180d - AVG(c.active_days_180d) OVER(),
      NULLIF(STDDEV_SAMP(c.active_days_180d) OVER(), 0)
    )
    -
    SAFE_DIVIDE(
      c.intervisit_cv_180d - AVG(c.intervisit_cv_180d) OVER(),
      NULLIF(STDDEV_SAMP(c.intervisit_cv_180d) OVER(), 0)
    )
  ) AS consistency_score_v1

FROM combined c;









