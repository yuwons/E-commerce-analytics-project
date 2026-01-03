# BigQuery Optimisation (Partitioning & Clustering)

목적: BigQuery 비용/성능 최적화(스캔량 감소, 조인/집계 효율 개선)  
적용 시점: Data Mart(DM) build 이전

## Folder structure
- `design_notes/` : Optimisation 설계노트 (PDF)
- `sql/` : Partitioning/Clustering 적용 SQL
- `screenshots/` : 적용 전/후 캡처(쿼리 플랜/스캔 비교)
- `README.md` : Optimisation 인덱스

---

## Scope (Final)
Raw 테이블은 보존하고, 아래 3개 대형 테이블에 대해 **날짜 Partition + 핵심 키 Clustering** 적용:

- `events` → `events_p`
- `sessions` → `sessions_p`
- `orders` → `orders_p`

> Output: 이후 분석/DM 쿼리는 최적화 테이블 기준으로 동일 로직 수행(지표 값 영향 없음)

---

## Query patterns
- `signup_date` 기준 14/30/60/180d 윈도우 반복
- `user_id` / `session_id` 중심 조인 및 집계 반복
- 대형 테이블(events/sessions/orders) 날짜 필터 기반 조회 빈도 높음

---

## Table specs

### 1) events → events_p
- Partition: `DATE(event_ts)`
- Cluster: `user_id, session_id, event_type`
- Rationale:
  - 이벤트 테이블이 가장 크며 날짜 필터 + user/session 조합 스캔이 빈번
  - `event_type`는 funnel 단계 필터링에 반복 사용
  - `product_id`는 일부 분석에만 사용되어 기본 clustering에서 제외

**Before (no partitioning/clustering)**  
![](screenshots/event_before.png)

**After (partitioning/clustering applied)**  
![](screenshots/event_after.png)

---

### 2) sessions → sessions_p
- Partition: `DATE(session_start_ts)`
- Cluster: `user_id, session_id`
- Rationale:
  - 세션 기반 조인/집계의 중심 키가 `user_id`, `session_id`
  - 날짜 필터(기간/윈도우) + 유저 단위 집계가 반복

**Before (no partitioning/clustering)**  
![](screenshots/session_before.png)

**After (partitioning/clustering applied)**  
![](screenshots/session_after.png)

---

### 3) orders → orders_p
- Partition: `DATE(order_ts)`
- Cluster: `user_id`
- Rationale:
  - 주문 데이터는 user-level outcome(LTV/재구매/구매여부) 집계 중심
  - `order_id`는 high-cardinality(사실상 unique)라 clustering 효율 낮아 제외

**Before (no partitioning/clustering)**  
![](screenshots/order_before.png)

**After (partitioning/clustering applied)**  
![](screenshots/order_after.png)

---

## Swap strategy (Rename)
원본 테이블 보존 + 최적화 테이블 병행 운영 전제.  
운영 단계에서 rename 방식으로 교체 가능(쿼리 변경 최소화 목적).

---

## Guardrails (쿼리 작성 규칙)

### 1) Partition pruning 깨지는 대표 케이스
- Partition 컬럼에 함수/변형을 추가하고, WHERE에서 원본을 필터하는 경우
- 문자열/타임존 변환으로 partition key와 다른 표현을 쓰는 경우
- 파티션 컬럼과 무관한 조건만 두고 스캔하는 경우(날짜 필터 누락)

### 2) Require partition filter (실수 방지)
- 대형 테이블에 대해 `REQUIRE_PARTITION_FILTER = TRUE` 적용 고려  
  - 목적: 날짜 필터 누락(full scan) 방지

### 3) 실무 규칙(최소)
- 날짜 조건은 partition key에 직접 적용(동일 컬럼 기준)
- 범위 필터는 `>= start_date AND < end_date`
- 조인 키는 `user_id`, `session_id` 우선(클러스터 키 정합)

---

## Notes
- Clustering 키는 “많이”보다 “반복 패턴에 맞춘 최소 구성” 우선
- Partitioning/Clustering은 저장/스캔 최적화 목적이며, 지표 값 자체는 변하지 않음
