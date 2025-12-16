# 1. 📌 프로젝트 목표 (Project Objective)

## 한 줄 요약
**유저 행동 패턴의 차이가 ‘단기 전환(빠른 첫 구매)’과 ‘장기 가치(LTV/Retention)’ 사이의 trade-off를 어떻게 만들어내는가?**

---

## 배경
많은 E-commerce에서 “전환율을 올리면 매출도 같이 오른다”는 가정이 자주 쓰이지만,  
실제 운영에서는 **빠른 전환을 만드는 행동**과 **장기적으로 높은 가치를 만드는 행동**이 항상 일치하지 않는다.  
본 프로젝트는 이 **구조적 trade-off**가 어떤 행동 패턴에서 발생하며, 그 결과가 지표로 어떻게 나타나는지를 **데이터로 설명**하는 것을 목표로 한다.

> 이 프로젝트는 “전환율을 최대화하는 방법”을 제시하지 않는다.  
> 대신 trade-off를 해석의 기준 축으로 두고, 행동 → 전환 → 잔존 → LTV → 구독(결과 증거) 흐름으로 구조를 설명한다.

---

## 핵심 KPI 정의 (Window 고정)
- **Short-term Conversion (메인):** 가입 후 **14일 내 첫 구매**
- **보조 KPI:** 가입 후 **30일 내 첫 구매**
- **LTV window:** 가입 후 **180일 누적 매출**
- **Subscription:** trade-off의 “원인”이 아니라 **결과(outcome evidence)**로만 사용

---

## 이 프로젝트가 답하려는 핵심 질문
- 어떤 행동 패턴은 **14일 내 첫 구매(단기 전환)**를 빠르게 만들지만, 왜 **장기 잔존/180일 LTV**는 낮아지는가?
- 반대로, 초기 전환은 느리더라도 **더 오래 남고(잔존), 더 큰 180일 LTV를 만드는 패턴**은 무엇인가?
- 이 trade-off는 “행동의 양”이 아니라, **행동의 구조(조합/리듬/일관성)** 차이에서 발생하는가?

---

## 분석 접근 (High-level)
본 프로젝트는 아래 흐름으로 trade-off를 설명한다.
1) **User Behavior:** 행동 구조 기반 세그먼트 정의 (단일 activation KPI에 의존하지 않음)
2) **Short-term Conversion:** 퍼널/전환 속도/구조 비교
3) **Retention / Cohort:** 90일/180일 잔존 비교 (시간 효과 통제)
4) **LTV Distribution:** 평균이 아닌 **분포/상위 집중도(tail)** 중심 비교
5) **Subscription:** 결과 증거로 확인 (원인 축으로 쓰지 않음)
6) **Behavior Consistency (핵심 축):** 방문/구매 리듬의 ‘일관성’이 short-term conversion과 long-term value의 trade-off를 어떻게 설명하는가?

## 3. 🗂 데이터 모델 (ERD)

본 프로젝트의 Raw 데이터는 총 **8개 테이블**로 구성됩니다.

### ✅ Tables (8)

- **Dimension**
  - `users` : 유저 프로필/세그먼트
  - `products` : 상품 마스터
  - `promo_calendar` : 회사 공통 프로모션 캘린더

- **Raw Logs (행동 로그)**
  - `sessions` : 방문/세션 단위 로그
  - `events` : 세션 내 이벤트 로그 (funnel 5-step)

- **Transaction**
  - `orders` : 주문 헤더 (purchase 이벤트에서 파생)
  - `order_items` : 주문 상세

- **Business Outcome**
  - `subscriptions` : 구독/멤버십 결과

### 🔒 Integrity Rules (Frozen Specs)

- Funnel 이벤트는 **5단계 고정**: `view → click → add_to_cart → checkout → purchase`
- `order_id`는 **purchase 이벤트에서만 존재**
- **purchase 이벤트 1건 = orders 1건** (정합성 유지)
- Raw 로그 보존 원칙: `sessions/events`는 Raw로 유지하고, revisit/retention/funnel conversion 등 **파생 지표는 BigQuery Data Mart(SQL)에서 계산**

---

<details>
  <summary><b>📌 (클릭) Detailed Schema (Columns)</b></summary>

### users
| column | description |
|---|---|
| user_id | PK |
| signup_date | 가입일 |
| user_type | 행동 타입(A/B/C/D) |
| device | iOS/Android/Web |
| region | 지역 |
| marketing_source | Organic/Paid/Referral |
| anomaly_flag | QA용 플래그 |

### products
| column | description |
|---|---|
| product_id | PK |
| product_name | 상품명 |
| category | 카테고리 |
| brand | 브랜드 |
| price | 가격 |
| rating_avg | 평균 평점 |
| is_new_arrival | 신상품 여부 |

### promo_calendar
| column | description |
|---|---|
| promo_id | PK |
| promo_name | 프로모션명 |
| start_date | 시작일 |
| end_date | 종료일 |
| uplift_level | uplift 강도 레벨 |
| discount_rate | 할인율 |

### sessions
| column | description |
|---|---|
| session_id | PK |
| user_id | FK → users.user_id |
| session_start_ts | 세션 시작 시각 |
| user_type | 행동 타입 스냅샷 |
| device | 디바이스 스냅샷 |
| is_promo | 프로모션 여부 |
| discount_rate | 적용 할인율 |
| promo_id | FK → promo_calendar.promo_id (해당 시) |

### events
| column | description |
|---|---|
| event_id | PK |
| user_id | FK → users.user_id |
| event_ts | 이벤트 시각 |
| event_type | view/click/add_to_cart/checkout/purchase |
| session_id | FK → sessions.session_id |
| device | 디바이스 스냅샷 |
| order_id | purchase 이벤트에서만 존재 |
| product_id | FK → products.product_id |
| is_promo | 프로모션 여부 |
| discount_rate | 적용 할인율 |
| promo_id | FK → promo_calendar.promo_id (해당 시) |

### orders
| column | description |
|---|---|
| order_id | PK (purchase 이벤트와 1:1) |
| user_id | FK → users.user_id |
| order_ts | 주문 시각 |
| is_promo | 프로모션 여부 |
| discount_rate | 적용 할인율 |
| promo_id | FK → promo_calendar.promo_id (해당 시) |

### order_items
| column | description |
|---|---|
| order_item_id | PK |
| order_id | FK → orders.order_id |
| user_id | FK → users.user_id |
| product_id | FK → products.product_id |
| quantity | 수량 |
| unit_price | 정가 |
| is_promo | 프로모션 여부 |
| discount_rate | 적용 할인율 |
| final_unit_price | 할인 적용 단가 |
| line_amount | final_unit_price * quantity |

### subscriptions
| column | description |
|---|---|
| subscription_id | PK (Free 포함 항상 존재: SUB_{user_id}) |
| user_id | FK → users.user_id |
| plan | Free/Plus/Premium |
| start_date | 시작일 |
| end_date | 종료일(없으면 null 가능) |
| status | Active/Cancelled/Expired 등 |
| monthly_fee | 월 요금 |

</details>


# 4. 🛠 Synthetic Dataset Generation (Python)

본 프로젝트는 E-commerce 환경을 재현하기 위해, Python 기반으로 **재현 가능한(Same seed)** synthetic dataset을 생성합니다.

### 4.1 Generation Principles (설계 원칙)
- **Raw 로그 보존:** `sessions/events`는 원시 로그 형태로 유지하고,  
  revisit/retention/funnel conversion/consistency 같은 파생 지표는 **BigQuery Data Mart(SQL)**에서 계산합니다.
- **Funnel 5-step 고정:** `view → click → add_to_cart → checkout → purchase`
- **정합성 규칙:** `order_id`는 purchase 이벤트에서만 생성되며,  
  **purchase 이벤트 1건 = orders 1건**으로 매칭됩니다.
- **Promo 반영:** `promo_calendar` 기간에 `sessions/events/orders`에 프로모션 속성이 일관되게 반영됩니다.
- **Subscription 반영:** 유저별 멤버십 결과(`subscriptions`)를 생성해 장기 가치 비교 분석에 활용합니다.

### 4.2 Dataset Scale (예시)
(생성 시점/파라미터에 따라 달라질 수 있음)

- users ≈ 30,000 / products = 300 / promo = 5  
- sessions ≈ 0.75M / events ≈ 1.8M  
- orders ≈ 15k / order_items ≈ 25k / subscriptions = 30,000

### 4.3 Reproducibility (재현성)
- random seed를 고정해 동일 환경에서 동일한 데이터 생성이 가능하도록 설계했습니다.
- 생성 및 정합성 검증(sanity check) 이후 BigQuery 적재를 진행합니다.

> Detailed generation rules (probabilities / decay / caps / schedules) are documented separately.  
> - `docs/generation_rules.md` (예정)

📁 경로: `src/data_generation/`
```text
src/data_generation/
├── generate_users.py
├── generate_products.py
├── generate_orders.py
├── generate_order_items.py
└── generate_events.py
```
---

# 5. 🧱 BigQuery Data Mart

분석 효율을 위해 BigQuery 기반 Data Mart를 구성했습니다.

### Data Mart 테이블

#### **1) dm_user_purchase_summary**
- LTV  
- 구매 횟수 / 첫 구매일  
- Subscription별 KPI  

#### **2) dm_category_performance**
- 카테고리 매출  
- AOV  
- 성장률 & 시즌성  

#### **3) dm_funnel_events**
- 단계별 전환율  
- Drop-off 위치  
- session 단위 정규화 이벤트

### BigQuery 쿼리 최적화
- **Partition**: `orders.order_date`  
- **Clustering**: `user_events(user_id, event_type)`  

📁 SQL 코드: `src/sql/`

---

# 6. ⚙️ Airflow Workflow Automation

본 프로젝트는 데이터 생성과 Data Mart 업데이트 작업을 자동화하기 위해 **Apache Airflow**를 활용했습니다.

### 구성 DAG

| DAG 이름 | 설명 |
|---------|------|
| **generate_synthetic_data_daily** | Python으로 Users/Products/Orders/Events 생성 후 BigQuery 적재 |
| **refresh_data_mart** | Data Mart(SQL View/Materialized Table) 정기 업데이트 |
| **funnel_preprocessing_dag** | user_events 테이블을 session 단위로 전처리한 후 dm_funnel_events로 반영 |

### Workflow 구조

### 사용된 Operators
- PythonOperator  
- BigQueryInsertJobOperator  
- Task dependency (`>>`)  
- Daily scheduling (`@daily`)

📁 DAG 파일: `airflow/dags/`

---

# 7. 📊 SQL-Based Analysis

### 분석 항목
- Cohort & Retention  
- LTV & 재구매 패턴  
- Subscription 효과  
- Category 성과 분석  
- Funnel Drop-off 분석  
- Behavior-based segmentation  

📁 SQL Notebook: `src/sql/`

---

# 8. 🐍 Python EDA & Statistical Analysis

### 분석 항목
- 분포/상관관계 EDA  
- Subscription 군 간 AOV 비교 (t-test, Mann-Whitney U)  
- Bootstrap 기반 A/B Test  
- Retention Heatmap  
- Funnel 이벤트 상세 분석  

📁 Notebook: `src/python/`

---

# 9. 📈 Tableau Dashboard

### Dashboard 구성 (총 4 pages)
1. KPI Overview  
2. Category Performance  
3. Cohort & Retention  
4. Funnel & Drop-off  

### Tableau 자동 업데이트
- BigQuery Live Connection  
- Data Mart → Tableau 실시간 반영  

📁 Tableau 파일: `tableau/`

---

# 10. 🔍 Final Insights

분석 결과 핵심 인사이트는 다음과 같습니다:

1. 높은 LTV 고객군의 행동적 특징 도출  
2. Funnel 단계별 주요 이탈 요인 및 개선 전략  
3. Discount Day의 신규 고객 전환 효과  
4. 성장 vs 비효율 카테고리 식별  
5. Retention 개선을 위한 Activation 지표 발굴  

---

# 🧰 Tech Stack

- **Python**: pandas, numpy, faker, matplotlib  
- **SQL**: BigQuery  
- **Airflow**: DAG Scheduling  
- **Visualization**: Tableau  
- **Infra**: GitHub  

---



