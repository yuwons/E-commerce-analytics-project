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
