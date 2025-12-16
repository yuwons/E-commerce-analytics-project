# 1. 📌 프로젝트 목표 (Project Objective)

## "유저 행동 패턴은 왜 단기 전환율과 장기 LTV를 동시에 최적화하지 못하는가?"

본 프로젝트는 실제 E-commerce 환경을 기반으로,  
**유저의 행동 패턴 차이가 단기 전환율(Short-term Conversion)과  
장기 고객 가치(LTV) 사이의 trade-off를 어떻게 만들어내는지**를 설명하는 것을  
핵심 목표로 한다.

많은 서비스에서는 전환율을 높이는 전략이 곧 매출 성장으로 이어질 것이라 기대하지만,  
실제 운영 환경에서는 **빠른 전환을 만드는 행동과  
장기적으로 높은 가치를 만드는 행동이 반드시 일치하지 않는 경우**가 빈번하게 발생한다.

본 프로젝트는 이러한 **구조적 긴장(trade-off)**이  
어떤 유저 행동 패턴에서 발생하며,  
그 결과가 **구매 구조, 잔존율(Retention), LTV 분포,  
그리고 구독 전환(Subscription)**으로 어떻게 나타나는지를  
데이터 기반으로 설명하는 것을 목표로 한다.

---

### 🔍 프로젝트의 중심 관점

- 이 프로젝트는 “전환율을 최대화하는 방법”을 제시하지 않는다.
- 대신,
  - **단기 전환율이 높은 행동 패턴**
  - **장기 LTV를 만들어내는 행동 패턴**
  이 왜 서로 다른 결과를 만들어내는지를 구조적으로 분석한다.

즉, 본 분석의 목적은 **단일 KPI 최적화가 아닌**,  
**비즈니스 의사결정 과정에서 반드시 고려해야 할 trade-off를  
데이터로 명확히 드러내는 것**이다.

---

### 🧠 프로젝트의 핵심 질문

- **어떤 유저 행동 패턴은  
  왜 빠른 구매 전환을 만들지만  
  장기적으로는 낮은 LTV로 이어지는가?**

- **반대로, 초기 전환율은 낮지만  
  장기적으로 더 높은 가치를 만들어내는 행동은  
  어떤 특성을 가지는가?**

본 프로젝트는 위 질문에 답하기 위해  
**End-to-End 분석 파이프라인**을 설계하고 구현한다.

---

### 🛠 분석 접근 방식 (High-level)

이를 위해 다음과 같은 분석 단계를 거친다:

- ERD 및 데이터 구조 설계  
- 현실적인 E-commerce 세계관 기반 Synthetic Dataset 생성  
- BigQuery 기반 Data Mart 구축  
- SQL을 활용한 핵심 지표 산출 및 구조 분석  
- Python을 활용한 가설 검증 및 통계적 실험  
- Tableau를 통한 Trade-off 중심 스토리텔링  
- Airflow를 통한 최소한의 분석 파이프라인 자동화  

각 기술 스택은 **필요한 목적에 한해서만 사용**되며,  
기술 자체를 과시하기보다는  
**문제 정의 → 구조 설명 → 의사결정 관점 제시**에 집중한다.


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

Python을 활용해 현실성 높은 Synthetic Dataset을 생성했습니다.

### ✔ Users
고객 세그먼트 분석 / Retention / LTV 분석 / Subscription 효과 분석
- 최근 36개월 가입 분포 (최근 18개월 70%)  
- device (iOS 40%, Android 45%, Web 15%)
- region (Seoul 38%, Gyeonggi 32%, Other 30%)
- marketing_source (Oranic 60%, Paid 30%, Referral 10%)
- subscription_type (Free 65%, Plus 25%, Platinum 10%)
- subscription_join_date
  - Plus → signup + 30~180일
  - Premium → signup + 10~90일
- is_new_user_flag: 가입 후 45일 이내 True
- anomaly 1% (의도적 데이터 품질 이슈)

### ✔ Products
카테고리 분석 / 가격대 기반 AOV·LTV 분석 / Discount Day 효과
- 총 product_id: 300개
- Category: 7개
  - Furniture, Appliances, Cleaning, Kitchenware, Fabric, Organizers, Deco)
- price: 카테고리별 Normal 또는 Log-normal 분포  
- price_tier: Low 30%, Mid 50%, High 20%  
- discount_day_of_week (요일 할인 정책)
  - 월~목: low/mid 중심
  - 금~일: high price 중심 (토요일이 최고가 카테고리)

### ✔ Orders
구매 행동 분석 / LTV / Cohort / Seasonality / Discount 효과 분석
- 구매 횟수 분포
  - 0회 20%
  - 1~2회 35%
  - 3~5회 25%
  - 6~10회 12%
  - 10회 이상 8%
- signup_date가 오래된 사용자일수록 높은 구매 구간 선택
- order_date: signup 이후 날짜에서 선택
- seasonality 적용: Feb 0.8, Mar 0.9, Oct 1.1, Nov 1.2, Dec 1.5
- 주말 구매량: 평일 대비 약 1.3배
- is_discount_day: 구매 상품 중 discount day 해당 여부
- anomaly_flag: 1%

### ✔ Order_items
카테고리 매출 분석 / AOV 분석 / 제품 성과 분석
- item_count per order
  - 1개 65%
  - 2개 25%
  - 3개 8%
  - 4개 2%
- product 선택 가중치
  - Cleaning / Kitchenware / Organizers 중심 (~18%)
  - Furniture 등 고가 카테고리 약 8%
- Subscription type별 가중치 차등 반영
  - Free → 저가 제품 선호
  - Premium → 고가 비중 증가
- qty: 1개 75%, 2개 20%, 3개 5%
- category, price, price_tier denormalized 저장
- line_amount = price × qty
- is_discounted: order_date와 discount day 일치 시 True

### ✔ User Events (Funnel Log)
Funnel 기반 행동 로그 / Session 분석 / Drop-off 분석
- Funnel 단계: view → add_to_cart → checkout → payment_attempt → purchase 
- Medium volume: 유저당 15~25 events 
- session_id: UUID  
- session당 이벤트 2~6개
- timestamp 간격: 5초~20분
- session 간 간격: 1시간~3일
- add_to_cart 없이 checkout_start 가능 (정상 흐름으로 처리)
- 단계별 전환율
  - view → add_to_cart: 10~18%
  - add_to_cart → checkout: 40~60%
  - checkout → payment_attempt: 70~85%
  - payment_attempt → purchase: 85~95%
- referrer: home / category / search / product / cart / checkout
- anomaly 2%
  - checkout 없이 payment
  - payment 없이 purchase
  - timestamp 역전
  - session_id null
  - user_id mismatch

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



