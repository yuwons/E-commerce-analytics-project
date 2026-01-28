
**한 줄 요약:** Synthetic e-commerce 행동/주문 로그를 설계하고 생성 파이프라인을 구축(BigQuery 로딩/최적화/DM 구축)한 뒤,  
SQL로 *Activation × Consistency*가 이후 LTV/Retention과 연결되는 패턴을 **v1.0 → v1.1(Time-split)**로 검증하고, Python EDA/간단 통계 + Tableau 대시보드로 마무리하는 end-to-end 분석 프로젝트입니다.

**이 프로젝트에서 보여주는 것**
- (Data modeling) raw log → optimized tables → data marts로 이어지는 BigQuery 중심의 분석용 데이터 모델링
- (Analytics) Activation/Consistency 기반의 LTV·Retention·Funnel 분석 + time-split(0–60 관측 / 60–180 성과) 검증
- (Delivery) Python 시각화/검정으로 결과를 재확인하고, Tableau로 KPI/세그먼트 대시보드를 구성

---

## 1) Project Goal

이 프로젝트는 **초기 14일 Activation(단기 전환)**만으로는 유저의 **장기 성과(LTV/Retention)**를 충분히 설명하기 어려울 수 있다는 가정에서 출발합니다.  
같은 Activation 수준이라도, 유저가 **얼마나 규칙적으로 다시 방다)

- users ≈ 30,000 / products = 300  
- sessions ≈ 0.748,757 / events ≈ 1.8M  
- orders ≈ 15k / order_items ≈ 25k

Funnel event counts:
- view = 1,465,245
- click = 290,912
- add_to_cart = 74,228
- checkout = 25,223
- purchase = 15,721

생성 후 최소 sanity check로 아래를 확인합니다.
- row count 확인
- PK uniqueness 확인
- 주요 테이블 정합성(가능한 범위 내)

---

## 4) BigQuery (Raw Loading → Optimised Tables → Data Marts)

이 프로젝트는 Raw 로그를 원형 그대로 보존하고,
Retention / Funnel / Conversion / LTV / Consistency 등 파생 지표는 BigQuery Data Mart(SQL)에서 계산한다.

### 4.1 BigQuery Setup (요약)
- Project: `eternal-argon-479503-e8`
- Raw dataset: `ecommerce`
- DM dataset: `ecommerce_dm`
- Location: `US`

### 4.2 Raw Tables (보존)
Raw 테이블은 Python으로 생성한 CSV를 BigQuery에 로드하여 구성한다.
- `users`
- `sessions`
- `events`
- `orders`
- `order_items`

### 4.3 Optimised Tables (Partitioning / Clustering)
대용량 테이블의 비용/속도 최적화를 위해, Raw 테이블에서 partitioning/clustering을 적용한 사본 테이블을 운영한다.
- 예시: `events → events_p`, `sessions → sessions_p`, `orders → orders_p` *(프로젝트 적용 범위에 따라 운영)*

관련 문서:
- `docs/optimisation/design_note/` (설계노트 - PDF)
- `docs/optimisation/sql/` (생성코드 - SQL)

> Note: 대형 Raw 테이블 조회 시 날짜 필터 누락(full scan) 방지를 위해 `REQUIRE_PARTITION_FILTER = TRUE`

### 4.4 Data Marts (SQL)
Activation / Funnel / Consistency / LTV / Retention 지표를 Data Mart로 정의하고 SQL로 계산한다.

관련 문서 :
- `docs/dm/design_notes/` (DM 설계노트 - PDF)
- `docs/dm/sql/` (DM 생성코드 - SQL)
- 
DATA MART BUILT:
- `DM_user_window`
- `DM_consistency_180d`
- `DM_ltv_180d`
- `DM_retention_cohort`
- `DM_funnel_session`
- `DM_timesplit_60_180_final` (v1.1: 0–60 관측 / 60–180 성과 분리)

OPTIONAL (대시보드/KPI 요약용):
- `DM_funnel_kpi_window` (cohort_month × window_days(14/30) 전환율 요약; 핵심 분석에서는 미사용)

> Scope note: promo/discount 관련 지표는 synthetic 생성 품질 이슈로 v1 분석 스코프에서 제외(필요 시 optional로 재활성화 가능).

---

## 5) SQL Analysis (Story)

SQL 결과는 실무자가 빠르게 훑어볼 수 있도록 **Story 문서**로 요약했습니다.

- **Story 문서:** `docs/results/story.md`
- **결과 스크린샷:**
  - v1.0: `docs/results/figures/`
  - v1.1 (time-split): `docs/results/figures_v1.1/`

v1.0에서는 0–180일 윈도우에서 핵심 패턴을 먼저 확인했고,  
v1.1에서는 **Time-split(관측 0–60d / 성과 60–180d)** 구조로 동일 질문을 더 엄격하게 재검증해 완료했습니다.

**분석 목표(overview)**  
이 프로젝트의 SQL 분석은 “초기 Activation(0–14d)과 Consistency(방문 리듬)가 장기 성과(60–180d)에 어떤 trade-off를 만드는가”를 검증하는 데 초점을 둡니다.  
이를 위해 퍼널(노출→장바구니→구매), 세그먼트(행동/리듬 기반), 장기 KPI(매출/LTV proxy, 리텐션)를 동일한 기준으로 비교할 수 있도록 Data Mart를 구성하고, v1.0 관찰 → v1.1 time-split 재검증 순서로 스토리를 구성했습니다.

### 5.1 Query Organization
스토리 재현에 필요한 쿼리와, 전체 분석 과정 쿼리를 분리해 관리합니다.

- `src/sql/analysis/00_story_core/`  
  → `docs/results/story.md`의 **v1.0 핵심 쿼리 세트**
- `src/sql/analysis/story_core_v1.1/`  
  → `docs/results/story.md`의 **v1.1(Time-split) 핵심 쿼리 세트**
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

- v1.0(0–180d window) + v1.1(Time-split)까지 Story 정리를 완료했습니다. 
- 다음 단계는 **Python 파트(EDA/시각화/간단 통계 검정)**로 넘어가,
  Story 결과를 그래프/검정으로 보강하고 재현성을 높일 예정입니다.
