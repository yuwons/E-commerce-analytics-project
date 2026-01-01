# E-commerce Analytics Project (Synthetic Data → BigQuery → SQL Story)

**한 줄 요약:** Synthetic e-commerce 로그를 생성하고(BigQuery 로딩/최적화/DM 구축),  
유저의 **초기 Activation(14일)**과 **방문 리듬(Consistency)**이 **장기 성과(LTV/Retention)**와 어떤 관계가 있는지 SQL 분석 결과(Story)로 정리한 프로젝트입니다.

---

## 1) Project Goal

이 프로젝트는 **초기 14일 Activation(단기 전환)**만으로는 유저의 **장기 성과(LTV/Retention)**를 충분히 설명하기 어려울 수 있다는 가정에서 출발합니다.  
같은 Activation 수준이라도, 유저가 **얼마나 규칙적으로 다시 방문하는지(Consistency)**가 이후 성과를 추가로 분리하는지 확인하는 것이 목표입니다.

- v1.0에서는 0–180일 윈도우에서 Activation/Consistency/LTV/Retention 간의 관계를 먼저 확인했고, 결과를 `docs/results/story.md`로 정리했습니다.
- v1.1에서는 해석을 더 안전하게 만들기 위해 **Time-split(관측창 vs 성과창)** 구조(`DM_timesplit_60_180_final`)를 추가해, “초기 행동 → 이후 성과” 형태로 재검증할 수 있도록 확장했습니다.

### Hypotheses (H1–H3)
- **H1:** 초기 14일 Activation이 높아도, 방문 리듬이 불규칙하면 장기 성과가 낮게 나타날 수 있습니다.  
- **H2:** 초기 전환이 느리더라도, 방문 리듬이 안정적이면 장기 성과가 높게 나타날 수 있습니다.  
- **H3:** Consistency는 단순 활동량(세션/이벤트 수)과는 별개로 장기 성과를 설명하는 신호가 될 수 있습니다.

---

## 2) Data Model (ERD)

이 프로젝트는 “오늘의집 스타일” 이커머스 도메인을 가정한 **synthetic dataset**으로 구성되어 있습니다.

- ERD 이미지: `docs/erd.png`

핵심 테이블:
- `users` : 유저 속성 및 가입 정보
- `products` : 상품 마스터
- `sessions` : 세션 단위 로그
- `events` : 이벤트 로그
- `orders` : 주문 헤더
- `order_items` : 주문 아이템

### Frozen Specs (분석 일관성 유지)
- Funnel step은 5단계로 고정: **view → click → add_to_cart → checkout → purchase**
- `order_id`는 purchase 이벤트에서만 생성
- **purchase 1건 = orders 1건** 정합성 유지  
- Raw 로그(sessions/events)는 원형 보존, 파생 지표는 DM에서 계산

---

## 3) Synthetic Dataset Generation (Python)

실제 서비스 데이터가 아닌, 분석 목적에 맞게 설계한 규칙 기반 **synthetic dataset**을 Python으로 생성합니다.

- 데이터 생성 코드: `src/data_generation/`

생성 후 최소 sanity check로 아래를 확인합니다.
- row count 확인
- PK uniqueness 확인
- 주요 테이블 정합성(가능한 범위 내)

---

## 4) BigQuery (Raw Loading → Optimised Tables → Data Marts)

이 프로젝트는 Raw 로그를 원형 그대로 보존하고, 파생 지표는 BigQuery Data Mart에서 계산합니다.

### 4.1 BigQuery Setup (Summary)
- Project: `eternal-argon-479503-e8`
- Raw dataset: `ecommerce`
- DM dataset: `ecommerce_dm`
- Location: `US`

### 4.2 Raw Loading
Python으로 생성한 데이터를 BigQuery Raw dataset에 로딩합니다.  
Raw 테이블은 “가공 전 원본 보존”을 우선으로 유지합니다.

### 4.3 Optimised Tables (Partitioning / Clustering)
대용량 테이블의 비용/속도 최적화를 위해, 주요 테이블은 partitioning/clustering이 적용된 사본 테이블을 사용합니다.

- 예시: `events → events_p`, `sessions → sessions_p`, `orders → orders_p`

> 최적화 관련 SQL은 repo의 `docs/optimisation/` 폴더에 정리되어 있습니다.  
> (설계 노트/상세 근거 문서는 추후 보강 예정)

### 4.4 Data Marts (SQL)
Activation / Funnel / Consistency / LTV / Retention 지표를 Data Mart로 정의하고 SQL로 계산합니다.

- Data Mart 생성 SQL: `docs/dm/`
- Sanity check SQL: `docs/sanity_check/`

대표 DM:
- `DM_user_window`
- `DM_consistency_180d`
- `DM_ltv_180d`
- `DM_retention_cohort`
- `DM_funnel_session`
- `DM_funnel_kpi_window`
- `DM_timesplit_60_180_final` (Time-split 확장, v1.1)

---

## 5) SQL Analysis (Story)

SQL 결과는 실무자가 빠르게 훑어볼 수 있도록 **Story 문서**로 요약했습니다.  
Story(v1.0)는 0–180일 윈도우 기반으로 핵심 패턴을 정리한 결과이며, 이후에는 Time-split(v1.1) 기반으로 동일 질문을 더 엄격하게 재검증할 수 있도록 확장할 예정입니다.

- Story 문서: `docs/results/story.md`
- 결과 스크린샷: `docs/results/figures/`
  - 한 화면에 결과가 다 안 담기는 경우가 있어 `*_a.png`, `*_b.png`로 분리해 저장했습니다.

### 5.1 Query Organization
스토리 재현에 필요한 쿼리와, 전체 분석 과정 쿼리를 분리해 관리합니다.

- `src/sql/analysis/00_story_core/`  
  → `docs/results/story.md`에 직접 연결되는 **핵심 쿼리 세트**
- `src/sql/analysis/01_supporting/`  
  → 전체 분석 흐름(Activation~Retention + 실험 쿼리) 보관  
  - `01_activation/`
  - `02_consistency/`
  - `03_funnel_dropoff/`
  - `04_segment_deepdive/`
  - `05_retention/`
  - `side_experiments/`

---

## 6) Notes / Next

- 현재 공개된 결과는 v1.0 Story(0–180일 윈도우 기반)이며, 핵심 결과는 `docs/results/story.md`에 정리했습니다.
- 해석의 설득력을 높이기 위해 Time-split Data Mart(`DM_timesplit_60_180_final`)를 추가했으며,  
  다음 단계에서는 관측창(0–60일) 지표가 성과창(60–180일) outcome과도 연결되는지 확인할 계획입니다.
