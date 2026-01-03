# Data Marts (DM)

BigQuery에서 생성하는 분석용 Data Mart(SQL) 모음.
Raw(`users`, `sessions`, `events`, `orders`, `order_items`)를 보존하고, 파생 지표는 DM에서 계산한다.

## Folder structure
- `design_notes/` : DM 1-page 설계노트 (PDF)
- `sql/` : DM 생성 SQL
- `README.md` : DM 인덱스

---

## Quick Index

| DM Table | Grain | Purpose | Key outputs (examples) |
|---|---|---|---|
| `DM_user_window` | 1 row per `user_id` | 가입일 기준 14/30/180일 윈도우 KPI + 퍼널 reach 요약 (Downstream 공통 베이스) | `has_*_14d/30d`, `orders_*`, `revenue_*`, `session_cnt_180d` |
| `DM_consistency_180d` | 1 row per `user_id` | 180일 방문 리듬/불규칙성(Consistency) 지표 | `active_days_180d`, `intervisit_mean/std/cv`, `weekly_active_ratio` |
| `DM_ltv_180d` | 1 row per `user_id` | 180일 LTV/매출 지표 요약 | `revenue_180d`, `orders_180d`, `aov_180d` |
| `DM_retention_cohort` | 1 row per `cohort_month` × `day_index` (0~180) | 코호트 Retention curve (0~180일) | `active_users`, `retention_rate` |
| `DM_funnel_session` | 1 row per `session_id` | 세션 단위 퍼널 재구성 (Reach + Strict) | `has_*`, `strict_*`, `first_ts`, `order_id` |
| `DM_timesplit_60_180_final` | 1 row per `user_id` | Time-split 핵심 DM: 0–60(관측) 피처로 60–180(성과) outcome 연결 | `activation_stage_14d`, `consistency_*_obs_60d`, `revenue_60_180`, `retention_last_week_180d` |
| `DM_funnel_kpi_window` | 1 row per `cohort_month` × `window_days` (14/30) | 코호트 단위 퍼널 KPI 요약 | `view→click→...` 전환율 |

### Status
- Core analysis: `DM_funnel_session`, `DM_timesplit_60_180_final` 중심
- Optional/summary: `DM_funnel_kpi_window` (요약 KPI)

---

## DM design principles
- Grain 분리: user / session / cohort-day 단위 혼합 금지
- Window 기준: `signup_date` 기반 (14/30/60/180d), start inclusive / end exclusive
- Funnel 단계: `view → click → add_to_cart → checkout → purchase`
- Time-split: 관측(0–59) / 성과(60–179) 분리

---

## Related documentation
- Optimisation (Partitioning/Clustering): `../optimisation/README.md`
- Sanity checks (validation queries): `../sanity_check/README.md`
