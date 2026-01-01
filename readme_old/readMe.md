# E-commerce Analytics (Personal Project)

> **핵심 메시지(v1.0)**  
> **초기 Activation(단기 전환)만으로는 장기 성과(LTV/Retention)를 충분히 설명하기 어렵다.**  
> 이 프로젝트는 유저의 **초기 방문 리듬(Consistency)** 이 이후 성과를 어떻게 갈라놓는지,  
> **관측창(0–60일) vs 성과창(60–180일)** 을 분리한 **Time-split** 방식으로 검증한다.

- DM 설계 노트(1-page): 📁 `docs/dm/`
- Sanity check SQL: 📁 `docs/sanity_check/`
- SQL analysis: 📁 `src/sql/analysis/`

---

# 1. 프로젝트 목표 (Project Objective)

## 1.1 한 줄 요약
**유저 행동 패턴의 차이가 ‘단기 전환(빠른 첫 구매)’과 ‘장기 가치(LTV/Retention)’ 사이의 trade-off를 어떻게 만들어내는가?**

## 1.2 배경
많은 E-commerce 분석은 “초기 전환이 높으면 장기 매출도 높을 것”이라는 가정에서 출발한다.  
하지만 실제로는 아래 같은 상황이 자주 발생한다.

- 어떤 유저는 초반에 빠르게 구매하지만 이후 재방문이 끊긴다.
- 어떤 유저는 초반 전환은 느려도 꾸준히 돌아오며 결국 더 높은 장기 가치를 만든다.

이 프로젝트는 이 차이가 **행동의 양(volume)** 만으로는 설명되지 않고,  
**행동의 구조(리듬/일관성/반복 패턴 = Consistency)** 에서 비롯될 수 있다는 관점에서 시작했다.

## 1.3 핵심 KPI 정의 (Window 고정)
- **Short-term Conversion (메인):** 가입 후 **14일 내 첫 구매**
- **보조 KPI:** 가입 후 **30일 내 첫 구매**
- **Observation Window:** 가입 후 **0–60일** (초기 행동 피처 계산)
- **Performance Window:** 가입 후 **60–180일** (성과 측정)
- **LTV window:** 가입 후 **180일 누적 매출** (추가 outcome)

## 1.4 핵심 가설 (H1/H2/H3)
- **H1 (Burst risk):** 초기 14일 전환이 높아도 **방문 리듬이 불규칙**하면(예: inter-visit CV↑) 이후 60–180일 성과가 낮다.
- **H2 (Steady wins):** 초기 전환이 느려도 **방문 리듬이 안정적**이면(active days/weeks↑, CV↓) 이후 60–180일 성과가 높다.
- **H3 (Independent effect):** Consistency는 단순 행동량(세션/이벤트 수)과 독립적으로 장기 성과를 설명한다(통제변수 고려 시에도 효과 유지).

## 1.5 이 프로젝트가 답하려는 핵심 질문
- **Q1:** 어떤 행동 패턴은 14일 내 첫 구매를 빠르게 만들지만, 왜 이후 60–180일 성과는 낮아지는가?
- **Q2:** 반대로 초기 전환은 느려도 이후 60–180일 성과(구매율/매출)가 높은 패턴은 무엇인가?
- **Q3:** 그 차이는 “행동량”이 아니라 **방문 리듬/일관성(Consistency)** 으로 설명되는가?

---

# 2. 데이터 모델 (ERD)

본 프로젝트의 Raw 데이터는 **Synthetic** 으로 생성되며, 분석 가능하도록 현실적인 E-commerce 스키마를 구성했다.

## 2.1 Tables (v1.0 Scope)
- **Dimension**
  - `users` : 유저 프로필/속성
  - `products` : 상품 마스터
- **Raw Logs (행동 로그)**
  - `sessions` : 방문/세션 단위 로그
  - `events` : 세션 내 이벤트 로그 (**funnel 5-step**)
- **Transaction**
  - `orders` : 주문 헤더 (purchase 이벤트에서 파생)
  - `order_items` : 주문 상세

## 2.2 Integrity Rules (Frozen Specs)
- Funnel 이벤트는 **5단계 고정**: `view → click → add_to_cart → checkout → purchase`
- `order_id`는 **purchase 이벤트에서만 존재**
- **purchase 이벤트 1건 = orders 1건** (정합성 유지)
- Raw 로그(`sessions/events`)는 원형을 유지하고, 리텐션/퍼널/KPI/Consistency 같은 파생 지표는 **BigQuery Data Mart(SQL)** 에서 계산

<details>
  <summary><b>(클릭) Detailed Schema (대표 컬럼) — v1.0</b></summary>

> 상세 스키마는 추후 `docs/schema.md` 형태로 보강 예정

### users
- `user_id`(PK), `signup_date`, `device`, `region`, `marketing_source`, `anomaly_flag`
- `user_type`은 Raw에 존재할 수 있으나 v1.0 분석에서는 **직접 사용하지 않음**  
  (누수 방지 목적) → Python에서 행동 기반으로 재현한 그룹과의 **검증용 비교**로만 활용 예정

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

이 프로젝트는 “분석 가능한 문제”를 직접 만들기 위해, Python으로 **재현 가능한(same seed)** synthetic dataset을 생성한다.

## 3.1 Generation Principles (설계 원칙)
- **Raw 로그 보존:** `sessions/events`는 원시 로그 형태로 유지  
  → revisit/retention/funnel conversion/consistency 같은 파생 지표는 **BigQuery Data Mart(SQL)** 에서 계산
- **Funnel 5-step 고정:** `view → click → add_to_cart → checkout → purchase`
- **정합성 규칙:** `order_id`는 purchase 이벤트에서만 생성되며, **purchase 이벤트 1건 = orders 1건**

## 3.2 Dataset Scale (현재 빌드 기준: 대략)
생성 파라미터에 따라 달라질 수 있다.
- users ≈ **30,000** (버전/파라미터에 따라 50K로 확장 가능)
- sessions ≈ **0.7–0.8M**
- events ≈ **~1.8M**
- orders ≈ **~15K**
- products = **300**

## 3.3 Reproducibility (재현성)
- random seed 고정
- 생성 후 PK/Join 정합성 및 row count sanity check 수행
- 검증 통과 후 BigQuery 적재

📁 경로: `src/data_generation/`
```text
src/data_generation/
├── generate_users.py
├── generate_products.py
├── generate_orders.py
├── generate_order_items.py
└── generate_events.py
