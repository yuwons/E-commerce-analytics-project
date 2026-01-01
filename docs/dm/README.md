# Data Marts (DM)

이 폴더는 BigQuery에서 생성한 **분석용 Data Mart 테이블**들의 인덱스 페이지 입니다.  
Raw 테이블(`users`, `sessions`, `events`, `orders`, `order_items` 등)을 그대로 분석하지 않고, **프로젝트 목표(Short-term Conversion vs Long-term LTV/Retention trade-off)**에 맞춰 재사용 가능한 형태로 요약/정리 했습니다.

---

## Quick Index

| DM Table | Grain | Purpose (1-line) | Key outputs (examples) |
|---|---|---|---|
| `DM_user_window` | 1 row per `user_id` | 가입일 기준 14/30/180일 윈도우의 핵심 유저 KPI/퍼널 reach 요약 | `has_*_14d/30d`, `orders_14d/30d/180d`, `revenue_14d/30d/180d`, `session_cnt_180d` |
| `DM_funnel_session` | 1 row per `session_id` | 세션 내 이벤트 흐름(퍼널)을 세션 단위로 재구성 | `funnel_step flags`, `first/last event`, `purchase_session_flag` |
| `DM_funnel_kpi_window` | 1 row per `cohort_month` (또는 cohort x segment) | 코호트 단위 퍼널 KPI를 윈도우 기준으로 요약 | `view→click→cart→checkout→purchase rates`, `drop-off` |
| `DM_consistency_180d` | 1 row per `user_id` | 180일 방문 리듬/불규칙성(Consistency) 지표 생성 | `active_days_180d`, `intervisit_mean/std/cv`, `weekly_active_ratio` |
| `DM_ltv_180d` | 1 row per `user_id` | 180일 LTV/매출 지표 요약 (장기 성과) | `revenue_180d`, `orders_180d`, `AOV/ARPU` |
| `DM_retention_cohort` | 1 row per `cohort_month` x `day_n` (0~180) | 코호트 Retention curve 생성 (0~180일) | `retained_users`, `retention_rate` |
| `DM_timesplit_60_180_final` | 1 row per `user_id` | Time-split 핵심 DM: 0–60일(관측) 행동 피처로 60–180일(성과) outcome을 연결 | `activation_stage_14d`, `consistency_*_obs_60d`, `orders/revenue_60_180`, `retention_last_week_180d` |

---

## Why multiple DMs?

한 번에 만능 DM 하나 로 만들면:
- 쿼리가 무겁고 유지보수가 어려워지고
- 서로 다른 grain(user, session, cohort-day)을 한 테이블에 섞게 되어
- 분석/검증/확장이 오히려 어려워진다.

그래서 본 프로젝트는 **목적/그레인 별로 DM을 분리**하고,
SQL 분석은 이 DM들을 조합해서 빠르고 명확하게 수행하도록 설계했습니다.

---

## Related documentation

- Optimisation (Partitioning/Clustering): `../optimisation/README.md`
- Sanity checks (validation queries): `../sanity_check/README.md`

---

## Notes

- 모든 날짜 윈도우는 기본적으로 `signup_date` 기준 14/30/180일을 사용한다.
- Time-split 분석을 위해 `DM_timesplit_60_180_final`에서는 관측창(day 0–59)과 성과창(day 60–179)을 분리한다.
- 퍼널 단계는 `view → click → add_to_cart → checkout → purchase` 순서로 정의한다.
- “Consistency”는 행동량(volume)과 분리된 설명력을 갖도록 별도 DM으로 구성했다.
