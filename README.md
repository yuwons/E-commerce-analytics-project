# E-commerce Analytics Project (Synthetic Data → BigQuery → SQL Story)

**한 줄 요약:** 유저의 **초기 Activation(첫 14일)**과 **방문 리듬(Consistency)**이 이후 **180일 LTV/Retention**과 어떤 관계가 있는지, BigQuery Data Mart와 SQL 분석으로 확인한 프로젝트입니다.

---

## 1) Project Goal

이 프로젝트는 “초기 전환”만 보고 유저 가치를 판단할 때 생길 수 있는 리스크를 줄이기 위해,
유저 행동을 **Activation(초기 퍼널 도달)**과 **Consistency(방문 리듬/규칙성)** 관점으로 나누고,
그 조합이 **장기 성과(180일 LTV/Retention)**와 어떻게 연결되는지 분석합니다.

### Hypotheses (H1–H3)
- **H1:** 초기 14일 전환이 높아도, 방문 리듬이 불규칙하면 180일 성과(LTV/Retention)가 낮을 수 있다.  
- **H2:** 초기 전환이 느리더라도, 방문 리듬이 일정하면 180일 성과가 높을 수 있다.  
- **H3:** Consistency는 단순 활동량(세션/이벤트 수)과 별개로 장기 성과를 설명하는 신호가 될 수 있다.

---

## 2) Data Model (ERD)

이 프로젝트는 “오늘의집 스타일” 이커머스 도메인을 가정한 **synthetic dataset**으로 구성되어 있습니다.

- ERD 이미지: `docs/erd.png`

핵심 테이블:
- `users` : 유저 속성 및 가입 정보
- `products` : 상품 마스터
- `promo_calendar` : 프로모션 캘린더
- `sessions` : 세션 단위 로그
- `events` : 이벤트 로그 (view → click → add_to_cart → checkout → purchase)
- `orders` : 주문 헤더 (purchase 이벤트 기준)
- `order_items` : 주문 아이템

> Funnel step은 5단계로 고정: **view → click → add_to_cart → checkout → purchase**  
> `order_id`는 purchase 이벤트에서만 생성되며, **purchase 1건 = orders 1건**을 가정합니다.

---

## 3) Synthetic Dataset Generation (Python)

이 프로젝트의 데이터는 실제 서비스 데이터를 사용하지 않고, 분석 목적에 맞게 설계한 규칙 기반 **synthetic dataset**을 Python으로 생성합니다.

- 생성 코드: `src/data_generation/`
- 생성 데이터(예): `data/generated/` (환경에 따라 경로 다를 수 있음)

생성 후 최소 sanity check를 통해:
- row count 확인
- PK uniqueness 확인
- 주요 테이블 간 FK 관계 점검(가능한 범위 내)

---

## 4) BigQuery (Raw Loading → Optimised Tables → Data Marts)

이 프로젝트는 Raw 로그를 원형 그대로 보존하고, 파생 지표는 BigQuery Data Mart에서 계산합니다.

### 4.1 BigQuery Setup (Summary)
- Project: `eternal-argon-479503-e8`
- Raw dataset: `ecommerce`
- DM dataset: `ecommerce_dm`
- Location: `US`

### 4.2 Raw Loading
Python으로 생성한 CSV를 BigQuery Raw dataset에 로딩합니다.  
Raw 테이블은 “가공 전 원본 보존”을 우선으로 유지합니다.

### 4.3 Optimised Tables (Partitioning/Clustering)
분석 비용/속도 최적화를 위해, 주요 대용량 테이블은 Partitioning/Clustering을 적용한 사본 테이블을 사용합니다.

- 예시: `events → events_p`, `sessions → sessions_p`, `orders → orders_p`

### 4.4 Data Marts (SQL)
분석에 필요한 지표(Activation/Retention/LTV/Consistency/Funnel)를 Data Mart로 정의하고, SQL로 계산합니다.

- Data Mart 생성 SQL: `docs/dm/`
- Sanity check SQL: `docs/sanity_check/`

대표 DM 목록:
- `DM_user_window` (유저 윈도우/피처 베이스)
- `DM_consistency_180d`
- `DM_ltv_180d`
- `DM_retention_cohort`
- `DM_funnel_session`
- `DM_funnel_kpi_window`
- `DM_timesplit_60_180_final` (v1.1용 Time-split 확장)

---

## 5) SQL Analysis (Story)

이 프로젝트의 SQL 분석 결과는 **Story 문서**로 정리되어 있습니다.
실무 관점에서 빠르게 이해할 수 있도록, 핵심 결과/스크린샷 중심으로 구성했습니다.

### 5.1 Results (Story)
- Story 문서: `docs/results/story.md`
- 결과 스크린샷: `docs/results/figures/`
  - 화면에 결과가 다 안 담기는 경우가 있어 `*_a.png`, `*_b.png`처럼 분리해 저장했습니다.

### 5.2 Query Organization
스토리 재현에 필요한 쿼리와, 전체 분석 과정 쿼리를 분리해 관리합니다.

- `src/sql/analysis/00_story_core/`  
  → `docs/results/story.md`에 직접 연결되는 **핵심 쿼리 세트**

- `src/sql/analysis/01_supporting/`  
  → 전체 분석 흐름(Activation ~ Retention + 실험 쿼리) 보관  
  - `01_activation/`
  - `02_consistency/`
  - `03_funnel_dropoff/`
  - `04_segment_deepdive/`
  - `05_retention/`
  - `side_experiments/`

> 보통은 `story.md`를 먼저 보고, 관심 가는 결과가 있으면 `00_story_core`에서 쿼리를 확인하고,  
> 더 깊게 들어가면 `01_supporting`에서 전체 분석 흐름/실험까지 확인할 수 있습니다.

---

## 6) Notes / Next
- 현재 Story는 v1.0 결과를 중심으로 정리되어 있습니다.
- 다음 단계(v1.1)는 Time-split(예: 0–60d 피처 / 60–180d 성과) 기반으로 더 안전하게 검증하는 방향으로 확장 예정입니다.
  - 관련 DM: `DM_timesplit_60_180_final`
