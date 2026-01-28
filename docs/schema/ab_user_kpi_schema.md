# AB_user_kpi Schema (CSV Export)

- Source (BigQuery): `ecommerce_dm_ab.AB_user_kpi` (user-level DM)
- CSV file: `dm_ab_dataset.csv`
- Purpose: 2×2 factorial A/B 실험의 효과를 사용자 단위로 추정하기 위한 입력 테이블  
  (early KPI: 0–13d, long-term KPI: 60–180d + 0–60d 행동/리듬 feature)

## Key Definitions
- 기준 시점(anchor): `signup_date`
- Early window: Day 0–13 (signup_date 포함)
- Observation window: Day 0–60
- Long-term window: Day 60–180
- Revenue unit: synthetic units (통화 단위 미정)

## Experiment Design
- `exp_cell`: {CC, CT, TC, TT} (각 셀 균등 배정)
  - 1st char = Activation uplift (C=control, T=treatment)
  - 2nd char = Consistency uplift (C=control, T=treatment)
  - 예: `TC` = Activation만 개입, `CT` = Consistency만 개입, `TT` = 둘 다 개입

## Columns
- `user_id` (STRING): 사용자 ID
- `signup_date` (DATE): 가입일(윈도우 계산 기준)

- `exp_cell` (STRING): 실험 셀 {CC, CT, TC, TT}

### Early KPI (0–13d)
- `has_order_0_13` (BOOL): 0–13일 내 주문(=purchase) 발생 여부
- `orders_0_13` (INT): 0–13일 내 주문 수

### Behavior / Consistency Features (0–60d)
- `active_days_0_60` (INT): 0–60일 내 세션 발생 “활성 일수”(unique active days)
- `gap_cv_0_60` (FLOAT): 0–60일 내 inter-visit gap의 CV (std/mean) — 방문 리듬 불규칙성 지표
- `gap_cnt_0_60` (INT): gap 계산에 사용된 gap 개수(관측치 수)

### Long-term KPI (60–180d)
- `revenue_60_180` (FLOAT): 60–180일 매출 합계(synthetic units)
- `orders_60_180` (INT): 60–180일 주문 수
- `has_purchase_60_180` (BOOL): 60–180일 내 구매(주문) 발생 여부

## Notes
- 본 테이블은 A/B 분석용 “요약 DM”이며, Raw를 직접 수정하지 않고 DM에서 계산 후 CSV로 export하여 Python에서 bootstrap CI로 효과를 추정한다.
- KPI 해석/결론은 `docs/results/story.md`의 섹션 7(A/B Test)에서 다룬다.

