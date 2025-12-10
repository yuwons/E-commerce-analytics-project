# 📦 E-commerce Analytics Project  
_End-to-End Data Modeling · Synthetic Dataset · SQL Data Mart · Python Behavioral Analysis · Funnel Analysis · Airflow Automation · Tableau Dashboard

본 프로젝트는 실제 커머스 환경을 기반으로 한 **End-to-End 분석 파이프라인**을 구축하는 것을 목표로 합니다.  
Synthetic 데이터 생성 → ERD 설계 → BigQuery Data Mart → Airflow 자동화 → SQL 분석 → Python Behavioral Analysis → Tableau Dashboard까지  
기업 데이터 분석 환경을 그대로 재현한 실무형 프로젝트입니다.

---

# 1. 📌 프로젝트 목표 (Project Objective)

## "초기 Activation 이 장기 가치를 어떻게 결정하는가 ?"
본 프로젝트는 실제 E-commerce 환경을 기반으로,
**유저의 초기 행동(Initial Activation)**이 **장기적 가치(LTV)**, **잔존율(Retention)**, 구매 패턴에 어떤 영향을 미치는지를 규명하는 것을 핵심 목표로 했습니다.

이를 검증하기 위해 다음과 같은 **End-to-End 분석 파이프라인**을 구축하였습니다
- ERD 및 Schema 설계
- Synthetic Dataset 생성
- BigQuery 기반 Data Mart 구축
- Airflow 자동화 Workflow
- SQL 분석 + Python Behavioral Analysis
- Tableau Dashboard 시각화

### **프로젝트의 중심 질문**  
- 유저의 첫 7~30일간의 행동 패턴이 장기 Revenue를 예측하고 설명할 수 있는가?  
- Activation이 높은 유저는 왜 더 높은 가치를 만들어내는가? 

---

# 2. 🔍 Core Analytical Questions (핵심 분석 질문)

본 프로젝트는 아래 질문들에 답하기 위해 설계되었습니다.

## **2.1 초기 Activation 정의 & Behavior 분석**
(초기 행동은 어떻게 측정되며, 무엇이 Activation을 결정하는가?)
- 유저의 첫 7~30일 동안 어떤 이벤트(views, add_to_cart, checkout)가 Activation을 설명하는가?  
- Time-to-first-add_to_cart, Time-to-first-purchase는 LTV 차이를 만드는가? 
- Session 패턴(빈도, 길이, 행동 다양성)은 Activation과 어떤 상관이 있는가?
- 초기 Discount 노출 여부가 Activation을 높이는가?

## **2.2 Funnel Drop-off 요인 → Activation과의 연결**
(이탈 원인은 어떻게 Activation 레벨을 결정하는가?)
- Funnel 단계별 이탈 지점은 Activation 수준과 어떤 상관관계를 가지는가?  
- add_to_cart 없이 바로 checkout/purchase하는 유저는 어떤 행동적 특성을 갖는가?  
- 디바이스/지역/유입경로/구독 상태별로 Activation 패턴이 어떻게 달라지는가?

## **2.3 Retention & Cohort Analysis**
(Activation이 장기 잔존율을 얼마나 설명하는가?)
- Activation 수준별 D1/D7/D30 Retention 차이는?  
- 초기 Funnel 성공/실패가 Cohort별 이탈률을 변화시키는가?
- 신규 유저의 초기 행동 패턴이 재방문 여부를 예측할 수 있는가?

## **2.4 LTV & Revenue Impact**
(Activation이 Revenue 차이를 어떻게 만드는가?)
- Activation 수준이 높은 유저는 LTV가 얼마나 더 높은가?
- Time-to-first-purchase가 Revenue에 미치는 영향은?
- Activation을 기준으로 Revenue Segmentation(High/Mid/Low LTV)이 가능한가?

## **2.5 Category & Purchase Patterns**
(Activation이 어떤 구매 패턴을 만들어내는가?)
- Activation이 높은 유저는 어떤 카테고리를 구매하는가?
- High-tier 제품 구매 비중 차이가 LTV 격차를 설명하는가?
- 초기 할인 이벤트가 구매 행동 변화에 영향을 주는가?

## **2.6 Subscription 고객의 Activation 모델**
(Activation → Subscription → 더 높은 가치 구조 분석)
- Subscription 고객은 Activation 초기 단계에서 어떤 행동 차이를 보이는가?
- Activation을 통제한 상황에서도 Subscription 자체가 LTV 증가를 만들까?
- 구독형 고객의 Funnel·카테고리·재구매 패턴은 어떻게 다른가?

## **2.7 최종적으로 도출할 전략적 인사이트**
모든 분석은 다음 4가지 비즈니스 질문을 해결하기 위한 근거로 사용된다:  
**1. Activation을 높이는 핵심 행동 지표는 무엇인가?**  
**2. Activation이 높은 유저가 왜 더 높은 LTV/Retention을 가진다는 결론이 나오는가?**  
**3. 초기 행동 기반으로 어떤 Retention/LTV 개선 전략을 만들 수 있는가?**  
**4. 카테고리/할인/구독 전략을 Activation 모델과 어떻게 연결할 수 있는가?**  
 
---

# 3. 🗂 데이터 모델 (ERD)

본 프로젝트의 데이터 구조는 실제 E-commerce 환경을 최대한 현실적으로 재현하기 위해
5개의 핵심 테이블(users, products, orders, order_items, user_events) 로 구성되었습니다.

이 구조는 고객 분석(LTV, Retention), 구매 분석(Category KPI), Funnel 분석(Log 기반)을 모두 수행할 수 있도록 설계되었습니다.

## **3.1 Users Table**

| column                 | description                                   |
| ---------------------- | --------------------------------------------- |
| `user_id` (PK)         | 사용자 ID                                      |
| `signup_date`          | 가입일                                         |
| `device`               | iOS / Android / Web                            |
| `region`               | Seoul / Gyeonggi / Others                      |
| `marketing_source`     | Organic / Paid / Referral                      |
| `subscription_type`    | Free / Plus / Premium                          |
| `subscription_join_date` | 유료가입 시점 (가입 후 10~180일)             |
| `is_new_user_flag`     | 신규 유저 여부 (가입 후 45일 기준)             |
| `anomaly_flag`         | 1% intentional anomaly                         |

### **설계 포인트**
- 최근 36개월 가입 패턴 반영  
- 마케팅/디바이스 세그먼트 분석 가능  
- Subscription 기반 LTV 분석 지원  
---

## **3.2 Products Table**

| column               | description                                |
| -------------------- | ------------------------------------------ |
| `product_id` (PK)    | 상품 ID                                      |
| `category`           | 7개 카테고리                                 |
| `price`              | 카테고리별 가격 분포 기반 생성                |
| `price_tier`         | Low / Mid / High (하위 30 / 중간 50 / 상위 20) |
| `brand`              | 브랜드명 (랜덤 생성)                          |
| `discount_day_of_week` | 할인 요일 (0~6, 월~일)                       |

### **설계 포인트**
- Price Tier 기반 매출/전환율 분석 가능  
- Discount Day 효과 분석 가능  
- 브랜드/카테고리별 성과 분석 지원  
---

## **3.3 Orders Table**

| column             | description                                 |
| ------------------ | ------------------------------------------- |
| `order_id` (PK)    | 주문 ID                                      |
| `user_id` (FK)     | 유저 ID                                      |
| `order_date`       | 주문 날짜                                     |
| `total_amount`     | 주문 총액 (order_items 집계 기반)             |
| `payment_status`   | success / failed                              |
| `is_discount_day`  | 주문이 할인 요일에 해당하는지 여부             |
| `anomaly_flag`     | 1% 의도적 오류                                |

### **설계 포인트**
- Seasonality + 사용자 행동 기반 구매 빈도 생성  
- 일부 payment anomaly 포함 → 전처리 실습용  
---

## **3.4 Order_Items Table**

| column            | description                              |
| ----------------- | ---------------------------------------- |
| `order_item_id` (PK) | 주문 상세 ID                           |
| `order_id` (FK)   | 주문 ID                                   |
| `product_id` (FK) | 상품 ID                                   |
| `category`        | snapshot (분석 편의를 위해 중복 저장)        |
| `price`           | snapshot                                  |
| `price_tier`      | snapshot                                  |
| `qty`             | 수량 (1~3)                                 |
| `line_amount`     | price × qty                               |
| `is_discounted`   | 할인 이벤트 적용 여부                       |

### **설계 포인트**
- Category / Price snapshot으로 Join 비용 절감  
- Premium 유저는 고가 티어 구매 비중 ↑  
- 주문당 item 수: 1~4개 분포 기반 생성  
---

## **3.5 User_Events Table**

| column              | description                                                          |
| ------------------- | -------------------------------------------------------------------- |
| `event_id` (PK)     | 이벤트 ID                                                             |
| `user_id` (FK)      | 유저 ID                                                                |
| `session_id`        | 세션 구분 (UUID 기반)                                                  |
| `event_type`        | view_product / add_to_cart / checkout_start / payment_attempt / purchase |
| `event_timestamp`   | 이벤트 발생 시점                                                       |
| `product_id`        | 이벤트 대상 상품 ID (view/add 단계에서만 포함)                         |
| `device`            | snapshot of user's device                                            |
| `referrer`          | direct / search / ads / push                                         |
| `is_discount_event` | 할인 이벤트 여부                                                       |
| `anomaly_flag`      | 2% intentional anomaly 포함                                            |

### **설계 포인트**
- Medium Volume (15~25 events/user)  
- session 기반 realistic timestamp 흐름  
- view → purchase 전체 Funnel 분석 가능  
- add_to_cart 없이 checkout 같은 실제 branch 포함  
- anomaly 2%로 전처리 및 QA 실습 가능  
---
### ERD 구조

![ERD](docs/erd.png)

---

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



