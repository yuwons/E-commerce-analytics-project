# Data Mart Sanity Checks

각 Data Mart 생성 후, 데이터 정합성과 범위/분포가 기대와 일치하는지 확인하는 sanity check SQL 을 작성하여 실행하였습니다.

## Check categories

### 1) Row count / key uniqueness
- Grain이 유지되는지 확인 (예: DM_user_window 는 user_id 1행)

### 2) Range checks
- 가능한 값 범위 확인 (예: active_days_180d 는 0~180)

### 3) Cross-table consistency
- 논리적 연결이 맞는지 확인 (예: orders 수와 purchase 이벤트 정합성)

### 4) Null / missingness
- 핵심 컬럼의 NULL 비율이 비정상적으로 높지 않은지 확인

## Files
- `dm_user_window_checks.sql`
- `dm_funnel_session_checks.sql`
- `dm_funnel_kpi_window_checks.sql`
- `dm_consistency_180d_checks.sql`
- `dm_ltv_180d_checks.sql`
- `dm_retention_cohort_checks.sql`

## Related docs
- DM 설계 인덱스: `../dm/README.md`
- Optimisation: `../optimisation/README.md`
