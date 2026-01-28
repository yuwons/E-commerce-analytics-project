# Time-split Validation Schema (CSV Export)

- Source (BigQuery): time-split DM 결과 export (user-level)
- CSV file: `time_split_min.csv`
- Purpose: v1.1 time-split(관측 0–60d / 성과 60–180d) 구조에서
  Consistency 신호와 장기 KPI의 관계를 Python으로 검증하기 위한 입력 테이블

## Key Definitions
- 기준 시점(anchor): `signup_date`
- Observation window: Day 0–60
- Outcome window: Day 60–180
- Revenue unit: synthetic units (통화 단위 미정)

## Columns
- `user_id` (STRING): 사용자 ID
- `signup_date` (DATE): 가입일(윈도우 계산 기준)

### Activation (0–14d)
- `activation_stage_14d` (STRING): 가입 후 14일 내 “최대 도달 funnel stage”
  - 예: A0_no_activity, A1_view, A2_click, A3_add_to_cart, A4_checkout, A5_purchase  
  *(정확한 정의는 Story/SQL 기준으로 유지)*

### Consistency (obs: 0–60d)
- `consistency_score_obs_60d` (FLOAT): 0–60d 방문 리듬 기반 consistency score
- `consistency_segment_obs_60d` (STRING): score 기반 구간화 세그먼트(예: C1~C5)
- `active_days_obs_60d` (INT): 0–60d 활성 일수(unique active days)
- `intervisit_cv_obs_60d` (FLOAT): 0–60d inter-visit gap CV (불규칙성 지표)

### Outcomes (60–180d)
- `revenue_60_180` (FLOAT): 60–180d 매출 합계(synthetic units)
- `orders_60_180` (INT): 60–180d 주문 수
- `has_purchase_60_180` (BOOL): 60–180d 구매 발생 여부
- `retention_last_week_180d` (BOOL/INT): 180일차 기준 “마지막 7일(또는 마지막 주) 활성 여부” 리텐션 플래그

## Notes
- 본 CSV는 “검증/시각화 목적”의 최소 컬럼만 포함한다.
- 최종 해석/결론은 `docs/results/story.md`의 v1.1 섹션 및 Python figure에서 확인한다.
