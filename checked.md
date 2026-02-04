**한 줄 요약:** Synthetic e-commerce 로그로 BigQuery **Raw→Optimized→Data Mart** 파이프라인을 구축하고, SQL **v1.0→v1.1(Time-split)** 로 Activation × Consistency의 **단기 전환(0–14d)→장기 성과(60–180d)** 연결을 재검증했으며, Python(**bootstrap CI**)과 **2×2 factorial A/B**로 “개입 효과” 관점까지 확장하였고, Tableau로 핵심 KPI/세그먼트 결과를 패키징하는 작업을 진행 중인 프로젝트입니다.

---

## 결론 요약 (Conclusion & Actions)

### 결론 (Decision)
**장기 성장(60–180d) 관점에서 핵심 레버는 Activation이 아니라 Consistency였다.**

Time-split(0–60 관측 / 60–180 성과)에서도 C1→C5로 갈수록  
60–180 구매율은 **0.049→0.467**, 마지막 주 리텐션은 **0.257→0.767**로 상승했다.

또한 2×2 A/B(bootstrap CI) 기준으로 **Consistency uplift는 60–180 매출(LTV proxy)을 유의미하게 개선**한 반면,  
Activation uplift는 **0–13 초기 전환 개선**에 더 가까웠다.


### Key Evidence (numbers)
- Time-split 기준에서도 Consistency C1→C5로 갈수록 성과가 상승  
  - purchase_rate_60_180: 0.049 → 0.467  
  - retention_last_week_180d_rate: 0.257 → 0.767
- Activation 수준이 같아도 Consistency에 따라 성과가 크게 갈림  
  - Act_Low(A0–A1): purchase_rate_60_180 0.016(C1) → 0.426(C5), retention 0.202 → 0.688  
  - Act_High(A4–A5): purchase_rate_60_180 0.068(C1) → 0.418(C5), retention 0.414 → 0.829
- 2×2 A/B(Activation uplift × Consistency uplift): 60–180 ΔE[rev]에서 **Consistency main effect**는 bootstrap 95% CI가 0을 상회(+)했고, Interaction(A×C)은 0을 포함해 불확실

### Actions (what I’d do in a real product)
1) 장기 KPI(60–180 매출/리텐션)를 목표로 한다면, 우선순위는 **Activation 단독 개선**이 아니라 **Consistency(주간 방문 리듬) 개입**에 둔다.  
2) 유저 타깃팅/운영 단위는 Activation 단독이 아니라 **Activation × Consistency persona**로 설계한다.  
3) 퍼널 개선은 “전사 공통 병목”과 “세그먼트 취약 병목”으로 분리해 실험한다.  
   - 14d: view→click (첫 클릭 유도)  
   - 30d: click→cart (특히 low-consistency 유저 타깃)

### Where to look (evidence links)
- Story (full narrative & figures): `docs/results/story.md`
- v1.1 time-split SQL: `src/sql/analysis/story_core_v1.1/`
- Python validation (dist/heatmap/bootstrap): `src/python/Python (EDA + Visualisation).ipynb`
- A/B experiment (bootstrap CI): `src/python/Python_(AB Experiment).ipynb`


## 이 프로젝트에서 보여주는 것
- **(Data Modeling)** Raw log → optimized tables → data marts로 이어지는 BigQuery 중심 분석용 데이터 모델링
- **(Analytics)** Activation/Consistency 기반 LTV·Retention·Funnel 분석 + time-split(0–60 관측 / 60–180 성과) 재검증
- **(Validation/Experiment)** Python 시각화·bootstrap CI로 불확실성을 확인하고, 2×2 A/B로 개입 효과를 보수적으로 평가
- **(BI/Delivery)** 핵심 KPI·세그먼트 결과를 Tableau 대시보드로 패키징하는 작업을 진행 중 *(산출물은 추후 업데이트 예정)*
---

## 1) Project Goal
이 프로젝트는 “초기 Activation(단기 전환)만으로는 장기 성과를 충분히 설명하기 어렵다”는 문제의식에서 출발합니다.  
특히, 같은 Activation 수준에서도 **방문 리듬(Consistency)** 차이가 이후 LTV/Retention을 추가로 분리하는지 확인하는 것이 목표입니다.

- **v1.0:** 0–180일 윈도우에서 핵심 패턴을 확인하고 결과를 `docs/results/story.md`에 정리
- **v1.1:** Time-split(관측 0–60d / 성과 60–180d) 구조로 누수 위험을 줄여 재검증 (`DM_timesplit_60_180_final`)
- **추가 검증:** Python으로 분포/불확실성(bootstrap CI)을 확인하고, 신규 유입 코호트 기반 2×2 A/B로 개입 효과를 보수적으로 평가

> Note: 자세한 분석 결과/해석은 `docs/results/story.md`에 요약했습니다.


---

## 2) Data Model (ERD)

이 프로젝트는 이커머스 도메인을 가정한 **synthetic dataset**으로 구성되어 있습니다.

![ERD](data/erd.png)

핵심 테이블:
- `users` : 유저 속성 및 가입 정보
- `products` : 상품 마스터
- `sessions` : 세션 단위 로그
- `events` : 이벤트 로그
- `orders` : 주문 헤더
- `order_items` : 주문 아이템

- Raw data 보관: `data/`

### Frozen Specs (분석 일관성 유지)
아래 규칙은 데이터 생성/가공 과정에서 일관되게 유지하여, 분석 결과가 데이터 정합성 이슈에 의해 흔들리지 않도록 했습니다.

- Funnel step은 5단계로 고정: **view → click → add_to_cart → checkout → purchase**
- `order_id`는 **purchase 이벤트에서만** 생성
- **purchase 1건 = orders 1건** 정합성 유지
- Raw 로그(`sessions`/`events`)는 원형 보존, 파생 지표는 **Data Mart(DM)** 에서 계산

---

## 3) Synthetic Dataset Generation (Python)

실제 서비스 데이터가 아닌, 분석 목적에 맞게 설계한 규칙 기반 **synthetic dataset**을 Python으로 생성했습니다.  
목표는 “현업 데이터 모사”가 아니라, **Activation / Consistency / Funnel / LTV/Retention** 분석을 재현 가능한 형태로 구성하는 것입니다.

> 데이터 생성 로직/상세 파라미터는 분석 재현에 필수적이지 않은 구현 상세이므로, 본 공개 repo에서는 제외했습니다.


### 3.1 Dataset Scale (예시)
아래 수치는 **생성 시점/파라미터에 따라 달라질 수 있는 예시 값**입니다.

- users ≈ 30,000 / products = 300  
- sessions ≈ 748,757 / events ≈ 1.8M  
- orders ≈ 15k / order_items ≈ 25k  

Funnel event counts (예시):
- view = 1,465,245
- click = 290,912
- add_to_cart = 74,228
- checkout = 25,223
- purchase = 15,721

### 3.2 Minimum Sanity Checks
생성 후 최소 sanity check로 아래를 확인합니다.
- row count 확인
- PK uniqueness 확인
- 주요 테이블 정합성(가능한 범위 내: `orders`–`order_items`, 이벤트 순서/누락 등)

> Note: 분석에서 사용하는 KPI/파생 feature는 Raw를 직접 수정하지 않고, BigQuery **Data Mart(SQL)** 에서 계산합니다.

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

## 6) Python Validation & A/B Experiment

SQL(v1.1 time-split) 결과를 Python에서 **분포/추세/불확실성(CI)** 관점으로 재확인하고, 관찰 결과를 “개입 효과” 관점에서 보기 위해 **2×2 factorial A/B Test**를 추가로 수행했습니다.  
(핵심 해석/결론은 `docs/results/story.md`에 정리)

> **Note (Reproducibility):** GitHub에는 용량 이슈로 `data/sample/`의 **샘플 CSV**만 포함했습니다.  
> 노트북은 샘플로도 실행 가능하며, `docs/results/story.md` 및 `docs/results/figures(python)/`의 **최종 결과/그래프는 full export 기준**으로 생성되었습니다.

### 6.1 Python Validation (v1.1 결과 재확인)
- **Notebook:** `src/python/Python (EDA + Visualisation).ipynb`
- **Figures:** `docs/results/figures(python)/`
- **Story:** `docs/results/story.md`의 Python validation 섹션
- **Schema:** `docs/schema/timesplit_validation_schema.md`
- **Sample CSV:** `data/sample/time_split_min_sample.csv`

### 6.2 A/B Experiment (2×2 factorial: Activation uplift × Consistency uplift)
베이스라인과 분리된 **AB 전용 신규 유입 코호트(≈30,000 users)**로 데이터셋을 별도 생성해 실험을 구성했습니다.

- **Notebook:** `src/python/Python_(AB Experiment).ipynb`
- **Figures:** `docs/results/figures(python)/`
- **Data/Analysis pipeline:** `ecommerce_dm_ab.AB_user_kpi` → CSV export → Python (bootstrap CI)
- **Story:** `docs/results/story.md`의 섹션 7 (A/B Test)
- **Schema:** `docs/schema/ab_user_kpi_schema.md`
- **Sample CSV:** `data/sample/dm_ab_dataset_sample.csv`

### 6.3 Repro Steps (빠른 재현 순서)
1. **Story 확인:** `docs/results/story.md`에서 문제정의/결론과 figure를 먼저 훑는다.
2. **SQL 재현(v1.1):** `src/sql/analysis/story_core_v1.1/` 쿼리로 time-split 결과를 재현한다.
3. **Python validation:** `src/python/Python (EDA + Visualisation).ipynb` 실행 후, figure는 `docs/results/figures(python)/`에서 확인한다.  
   - (샘플 입력: `data/sample/time_split_min_sample.csv`)
4. **A/B experiment:** `src/python/Python_(AB Experiment).ipynb` 실행 후, 효과 추정은 bootstrap CI로 확인한다.  
   - (샘플 입력: `data/sample/dm_ab_dataset_sample.csv` / full export 입력: `ecommerce_dm_ab.AB_user_kpi` export CSV)

> Note: `docs/results/figures(python)/`처럼 폴더명에 괄호가 포함되어 있어, Story에서는 GitHub 렌더링 안정성을 위해 `<...>` 형태 경로를 사용합니다.
