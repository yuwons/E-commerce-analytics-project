# E-commerce Analytics (Personal Project)

> **핵심 메시지(v1.0)**  
> **초기 Activation(단기 전환)만으로는 장기 성과(LTV/Retention)를 충분히 설명하기 어렵다.**  
> 이 프로젝트는 유저의 **초기 방문 리듬(Consistency)** 이 이후 성과를 어떻게 갈라놓는지,  
> **관측창(0–60일) vs 성과창(60–180일)** 을 분리한 Time-split 방식으로 검증한다.

- DM 설계 노트(1-page): 📁 `docs/dm/`
- Sanity check SQL: 📁 `docs/sanity_check/`

---

# 1. 프로젝트 목표 (Project Objective)

## 한 줄 요약
**유저 행동 패턴의 차이가 ‘단기 전환(빠른 첫 구매)’과 ‘장기 가치(LTV/Retention)’ 사이의 trade-off를 어떻게 만들어내는가?**

---

## 배경
많은 E-commerce에서 “전환율을 올리면 매출도 같이 오른다”는 가정이 자주 쓰이지만,  
실제 운영에서는 **빠른 전환을 만드는 행동**과 **장기적으로 높은 가치를 만드는 행동**이 항상 일치하지 않는다.

이 프로젝트는 그 차이가 **행동의 양(volume)** 이 아니라,  
**행동의 구조(조합/리듬/일관성)**에서 발생할 수 있다는 관점에서 시작한다.

---

## 핵심 KPI 정의 (Window 고정)
- **Short-term Conversion (메인):** 가입 후 **14일 내 첫 구매**
- **보조 KPI:** 가입 후 **30일 내 첫 구매**
- **Observation Window:** 가입 후 **0–60일** (초기 행동 피처 계산)
- **Performance Window:** 가입 후 **60–180일** (성과 측정)
- **LTV window:** 가입 후 **180일 누적 매출** (추가 outcome)

---

## 핵심 가설 (H1/H2/H3)
- **H1 (Burst risk):** 초기 14일 전환이 높아도 **방문 리듬이 불규칙**하면(예: inter-visit CV↑) 이후 60–180일 성과가 낮다.
- **H2 (Steady wins):** 초기 전환이 느려도 **방문 리듬이 안정적**이면(active days/weeks↑, CV↓) 이후 60–180일 LTV가 높다.
- **H3 (Independent effect):** Consistency는 단순 행동량(세션/이벤트 수)과 독립적으로 장기 성과를 설명한다(통제변수 고려 시에도 효과 유지).

---

## 이 프로젝트가 답하려는 핵심 질문
- 어떤 행동 패턴은 **14일 내 첫 구매(단기 전환)**를 빠르게 만들지만, 왜 **이후 60–180일 성과**는 낮아지는가?
- 반대로, 초기 전환은 느리더라도 **더 높은 60–180일 성과(구매율/매출)** 를 만드는 패턴은 무엇인가?
- 그 차이는 “행동의 양”이 아니라, **행동의 구조/리듬/일관성(Consistency)** 차이에서 발생하는가?

---

# 2. 데이터 모델 (ERD)

본 프로젝트의 Raw 데이터는 아래 테이블로 구성된다. (Synthetic)

### Tables (v1.0 Scope)
- **Dimension**
  - `users` : 유저 프로필/속성
  - `products` : 상품 마스터
- **Raw Logs (행동 로그)**
  - `sessions` : 방문/세션 단위 로그
  - `events` : 세션 내 이벤트 로그 (**funnel 5-step**)
- **Transaction**
  - `orders` : 주문 헤더 (purchase 이벤트에서 파생)
  - `order_items` : 주문 상세

---

### Integrity Rules (Frozen Specs)
- Funnel 이벤트는 **5단계 고정**: `view → click → add_to_cart → checkout → purchase`
- `order_id`는 **purchase 이벤트에서만 존재**
- **purchase 이벤트 1건 = orders 1건** (정합성 유지)
- Raw 로그(`sessions/events`)는 원형을 유지하고, 리텐션/퍼널/KPI/Consistency 같은 파생 지표는 **BigQuery Data Mart(SQL)에서 계산**

<details>
  <summary><b>(클릭) Detailed Schema (대표 컬럼) — v1.0</b></summary>

> 상세 스키마는 추후 `docs/schema.md` 형태로 보강 예정

### users
- `user_id`(PK), `signup_date`, `device`, `region`, `marketing_source`, `anomaly_flag`
- `user_type`은 Raw에 존재할 수 있으나, v1.0 분석에서는 **누수 방지 목적**으로 직접 사용하지 않고  
  Python에서 행동 기반으로 재현한 그룹과의 **검증용 비교(정답지)**로만 활용 예정

### products
- `product_id`(PK), `category`, `brand`, `price`, `rating_avg`, `is_new_arrival`

### sessions
- `session_id`(PK), `user_id`(FK), `session_start_ts`, `device`

### events
- `event_id`(PK), `user_id`, `event_ts`, `event_type`, `session_id`, `product_id`, `order_id`(purchase에만)

### orders
- `order_id`(PK), `user_id`, `order_ts`

### order_items
- `order_item_id`(PK), `order_id`, `user_id`, `product_id`, `quantity`, `final_unit_price`, `line_amount`

</details>

---

# 3. Synthetic Dataset Generation (Python)

본 프로젝트는 E-commerce 환경을 재현하기 위해 Python 기반으로 **재현 가능한(Same seed)** synthetic dataset을 생성한다.

### 3.1 Generation Principles (설계 원칙)
- **Raw 로그 보존:** `sessions/events`는 원시 로그 형태로 유지하고,  
  revisit/retention/funnel conversion/consistency 같은 파생 지표는 **BigQuery Data Mart(SQL)**에서 계산
- **Funnel 5-step 고정:** `view → click → add_to_cart → checkout → purchase`
- **정합성 규칙:** `order_id`는 purchase 이벤트에서만 생성되며, **purchase 이벤트 1건 = orders 1건**

### 3.2 Dataset Scale (현재 버전: 대략)
(생성 시점/파라미터에 따라 달라질 수 있음)
- users ≈ **30,000**
- sessions ≈ **0.7–0.8M**
- events ≈ **~1.8M**
- orders ≈ **~15K**
- products = **300**

### 3.3 Reproducibility (재현성)
- random seed를 고정해 동일 환경에서 동일한 데이터 생성이 가능하도록 설계
- 생성 이후 정합성 검증(sanity check) 후 BigQuery 적재

📁 경로: `src/data_generation/`
```text
src/data_generation/
├── generate_users.py
├── generate_products.py
├── generate_orders.py
├── generate_order_items.py
└── generate_events.py

---

# 4. BigQuery (Raw Loading → Optimised Tables → Data Marts)

이 프로젝트는 **Raw 로그를 원형 그대로 보존**하고,  
리텐션/퍼널/전환/LTV/Consistency 등 **파생 지표는 BigQuery Data Mart(SQL)** 에서 계산한다.

## 4.1 Frozen Specs (절대 변경 금지)
- **Raw 로그 보존:** `sessions`/`events`는 Raw 유지, 파생지표는 DM에서 계산
- **Funnel 이벤트 5단계 고정:** `view → click → add_to_cart → checkout → purchase`
- **`order_id`는 `purchase` 이벤트에서만 존재**
- **`purchase` 이벤트 1건 = `orders` 1건**

## 4.2 BigQuery Setup (요약)
- **Project:** `eternal-argon-479503-e8`
- **Raw dataset:** `ecommerce`
- **DM dataset:** `ecommerce_dm`
- **Location:** `US`

## 4.3 Raw Loading (개요)
1. Python에서 생성한 CSV(또는 parquet)를 `data/generated/`에 저장
2. BigQuery에 Raw 테이블로 적재  
   (`users` / `products` / `sessions` / `events` / `orders` / `order_items`)
3. 적재 후 sanity check로 정합성 검증  
   (행 수, PK 유일성, FK join 가능 여부)

## 4.4 Query Cost & Performance (최적화 방향)
분석 쿼리는 대부분 가입일 기준 14/30/60/180일 윈도우를 사용하고,  
집계는 주로 user/session 단위로 발생한다.  
그래서 `events`/`sessions`/`orders` 중심으로  
**Partitioning(날짜)** + **Clustering(user/session/event_type)** 을 적용해  
스캔 바이트와 비용을 줄이는 방향으로 설계했다.

- 상세 설계 및 증거: 📁 `docs/optimisation/`

---

# 5. Data Mart (Modeling Layer)

단순히 쿼리를 몇 개 실행하는 방식이 아니라,  
**분석 가능한 구조(모델링 레이어)** 를 먼저 만들고 그 위에서 질문에 답하도록 설계했다.

## 5.1 Data Mart 설계 원칙
- Raw → DM를 분리해 **정합성 유지 + 재현성 확보 + 분석 속도 개선**
- Grain(단위)을 명확히 나눠 **유저 단위/세션 단위/코호트 단위** 분석을 각각 최적화
- KPI/지표 정의를 테이블 레벨로 고정해, 동일 조건의 분석을 반복 실행 가능하게 구성

## 5.2 Data Mart Map (전체 구조)
Raw → DM 설계의 목적은 아래 질문을 **재현 가능한 SQL** 로 검증하기 위함이다.

> **H1/H2/H3:** 초기 전환(14/30일)과 Consistency(방문 리듬)가  
> **이후 성과(60–180일)** 를 어떻게 설명하는가?

Data Mart는 **Grain(단위)** 기준으로 역할을 분리했다.

### User-level (스토리 핵심)
- `DM_user_window` : 유저 속성 + 14/30일 funnel reach + 180일 요약 KPI
- `DM_consistency_180d` : 방문 리듬/불규칙성(Consistency) 피처  
  (inter-visit stats, weekly regularity 등)
- `DM_ltv_180d` : 180일 매출(LTV) outcome 집계
- ✅ `DM_timesplit_60_180_final` : **0–60일 피처 + 60–180일 outcome 결합** (핵심 분석 테이블)

### Session-level (퍼널의 원자 데이터)
- `DM_funnel_session` : 세션 단위 퍼널 재구성  
  (정합성/디버깅 가능, reach/strict 플래그)

### Cohort-level (리포팅/커브)
- `DM_funnel_kpi_window` : 14/30일 퍼널 KPI 요약 (reach/strict)
- `DM_retention_cohort` : cohort_month × day_index(0..180) retention curve

## 5.3 Data Mart 설계 노트 & Sanity Checks
각 Data Mart는 아래 항목을 포함해 문서화했다.
- Grain / 주요 쿼리 패턴(WHERE/GROUP BY)
- Frozen Specs 반영 포인트
- Sanity checks (범위/정합성/유일성 검증)

---

# 6. Airflow Workflow Automation (Planned)

데이터 생성 및 Data Mart 업데이트를 자동화하기 위해 **Apache Airflow** 적용을 계획하고 있다.

## 계획 DAG (초안)
- `generate_synthetic_data` : Python 데이터 생성 → BigQuery 적재
- `refresh_data_mart` : Data Mart 정기 업데이트

📁 예정 경로: `airflow/dags/`

---

# 7. SQL-Based Analysis (✅ 완료)

Python으로 넘어가기 전, 핵심 결과를 **SQL로 먼저 고정(freeze)** 해서  
QA(합계/NULL/윈도우 범위)와 재현 가능한 분석 기반을 만들었다.

📁 경로: `src/sql/analysis/`

## SQL#1 — Activation stage 분포 QA
- activation_stage_14d 분포 합이 전체 유저 수로 정확히 일치  
  → 누락/중복 없이 정상

## SQL#2 — Activation × Consistency(0–60) → Outcome(60–180)
- 동일 activation 단계 내에서도 Consistency segment(C1→C5)가 높아질수록  
  purchase_rate_60_180 / avg_orders / avg_revenue가 **단조 증가** 패턴 확인
- 미구매자 비중이 커 median=0이 많은 현상은 자연스러운 결과로 해석

## SQL#3 — Funnel bottleneck 요약 (14d vs 30d)
- window_days(14/30) + metric_type(reach/strict) + bottleneck_step 결과 테이블 생성
- 다음 단계(Python)에서 **유저군 × 병목 step** 교차 분석으로 확장 예정

---

# 8. 🐍 Python EDA & Statistical Analysis (Planned)

SQL에서 고정한 결과를 바탕으로 Python에서 아래 확장 분석을 진행할 계획이다.

## 계획 항목
- 행동 기반 유저군(A/B/C/D) 재현 (raw 라벨 누수 방지)
- 유저군 × 병목 step 교차 분석 (14d vs 30d, reach vs strict)
- Time-split 결과 시각화 + “mix effect” 분해  
  - 구매자 비중(purchase_rate) vs 구매자당 매출(buyer-only revenue)

📁 예정 경로: `src/python/`

---

# 9. Tableau Dashboard (Planned)

분석 결과를 이해하기 쉽게 전달하기 위해 Tableau 대시보드를 구성할 계획이다.

## 계획 Dashboard 구성 (4 pages)
1. KPI Overview
2. Cohort & Retention
3. Funnel & Drop-off (14d/30d, reach/strict)
4. Segment Comparison (Activation × Consistency / Time-split Outcomes)

📁 예정 경로: `tableau/`

---

# 10. Final Insights (Planned)

최종 산출물은 아래 형태로 정리될 예정이다.
1. 유저 행동 패턴 기반 세그먼트 정의 및 장기 성과 차이 설명
2. Funnel 단계별 이탈 지점(병목)과 개선 포인트
3. “단기 전환 vs 장기 가치” trade-off를 설명하는 스토리라인 문서(`Story.md`)

---

# Current Limitations (keep note)

## 1) Core problem (tautology / leakage)
“180일 Consistency로 180일 LTV를 설명”하면  
**‘오래 남아 자주 온 사람이 돈을 많이 쓴다’**는 동어반복이 될 수 있다.  
그래서 본 프로젝트는 **관측창(0–60일)** 과 **성과창(60–180일)** 을 분리해  
“예측형 분석”으로 전환했다.

## 2) Scope exclusions (v1.0)
- Subscription 분석 제외 (스코프에서 제거)
- Promo 분석 제외 (희소/신호 약함 — v1.0에서는 해석 가치 낮음)

---

# Tech Stack
- **Python:** pandas, numpy (data generation / EDA planned)
- **SQL:** BigQuery (Data Mart modeling + analysis)
- **Airflow:** workflow automation (planned)
- **Visualization:** Tableau (planned)
- **Infra:** GitHub
