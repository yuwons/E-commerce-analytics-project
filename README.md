# 📦 E-commerce Analytics Project  
_End-to-End Data Modeling · Synthetic Dataset · SQL Data Mart · Python Behavioral Analysis · Funnel Analysis · Airflow Automation · Tableau Dashboard_

본 프로젝트는 실제 커머스 환경을 기반으로 한 **End-to-End 분석 파이프라인**을 구축하는 것을 목표로 합니다.  
Synthetic 데이터 생성 → ERD 설계 → BigQuery Data Mart → Airflow 자동화 → SQL 분석 → Python Behavioral Analysis → Tableau Dashboard까지  
기업 데이터 분석 환경을 그대로 재현한 실무형 프로젝트입니다.

---

# 1. 📌 프로젝트 목표 (Project Objective)

현실적인 커머스 환경을 가정하여 아래 분석 목표를 수행합니다:

### **1) 고객 행동 분석 (Customer Behavior Analysis)**  
- LTV, 재구매율, Time-to-First-Purchase  
- Subscription(Free/Plus/Premium)별 행동 · 가치 분석  
- 신규 vs 기존 고객의 초기 구매 패턴 비교

### **2) 카테고리 매출 & 할인 효과 분석 (Category Performance)**  
- 카테고리별 매출 기여도, AOV, 구매 빈도  
- Discount Day(요일별 할인) 효과 분석  
- 시즌성(Seasonality) 반영 패턴 분석

### **3) Funnel 분석 (User Journey · Log-based)**  
- view → add_to_cart → checkout → payment → purchase  
- 단계별 이탈(drop-off) 탐지 및 원인 분석  
- 기기/지역/구독 상태/채널별 전환율 비교

🎯 **최종 목표:**  
Retention 개선, Funnel 최적화, 매출 성장 전략 도출

---

# 2. 🔍 Analytical Questions (핵심 분석 질문)

본 프로젝트는 아래 질문들에 답하기 위해 설계되었습니다.

## **Customer Behavior & LTV**
- 어떤 행동 변수들이 장기 LTV를 결정하는가?  
- Subscription 가입 고객과 Free 고객의 재구매율 차이는 왜 발생하는가?  
- Time-to-First-Purchase는 장기 잔존율에 어떤 영향을 미치는가?

## **Funnel & Drop-off Analysis**
- Funnel 단계별 가장 큰 이탈은 어디에서 발생하는가?  
- add_to_cart 없이 바로 checkout/purchase 하는 고객의 특징은?  
- 유입 채널/디바이스/Subscription에 따라 전환율이 어떻게 달라지는가?

## **Category & Discount Effect**
- 카테고리별 구매 패턴(빈도, AOV, 재구매율)은 어떻게 다른가?  
- Discount Day는 신규 고객 전환율을 얼마나 높이는가?  
- high-tier 제품을 구매하는 고객군의 행동적 특징은?

## **Retention & Cohort**
- D1/D7/D30 Retention을 결정하는 초기 행동 지표는 무엇인가?  
- 초기 Activation이 장기 잔존율을 어떻게 설명하는가?  

---

# 3. 🗂 데이터 모델 (ERD)

본 프로젝트의 데이터 구조는 실제 E-commerce 환경을 최대한 현실적으로 재현하기 위해
5개의 핵심 테이블(users, products, orders, order_items, user_events) 로 구성되었습니다.

이 구조는 고객 분석(LTV, Retention), 구매 분석(Category KPI), Funnel 분석(Log 기반)을 모두 수행할 수 있도록 설계되었습니다.

### 3.1 Users Table

| column                 | description               |
| ---------------------- | ------------------------- |
| user_id                | PK                        |
| signup_date            | 가입일                       |
| device                 | iOS / Android / Web       |
| region                 | Seoul / Gyeonggi / Others |
| marketing_source       | Organic / Paid / Referral |
| subscription_type      | Free / Plus / Premium     |
| subscription_join_date | 유료가입 시점                   |
| is_new_user            | 신규 유저 여부 (30일 기준)         |

### 설계 포인트
- 최근 유입 증가 패턴 반영
- Subscription 분석 가능하도록 구조를 설계

### 3.2 Products Table 

| column     | description      |
| ---------- | ---------------- |
| product_id | PK               |
| category   | 7개 카테고리          |
| price      | 카테고리별 가격대 기반 생성  |
| price_tier | Low / Mid / High |
| brand      | 국내 브랜드명 랜덤 생성    |

### 설계 포인트
- category 가격 분포 + price_tier 조합으로 KPI 분석 가능
- brand 컬럼 추가로 브랜드별 성과 분석도 가능 (AOV, 매출 기여도 등)


### 3.3 Orders Table

| column            | description               |
| ----------------- | ------------------------- |
| order_id          | PK                        |
| user_id           | FK                        |
| order_date        | 주문 날짜                     |
| payment_attempted | 결제 시도 여부                  |
| payment_status    | 결제 성공 여부                  |
| total_amount      | 주문 총액 (order_items 집계 기반) |

### 3.4 Order Items Table

| column        | description |
| ------------- | ----------- |
| order_item_id | PK          |
| order_id      | FK          |
| product_id    | FK          |
| category      | snapshot    |
| price         | snapshot    |
| price_tier    | snapshot    |
| quantity      | 수량          |

### 3.5 User Events Table

| column     | description                                                |
| ---------- | ---------------------------------------------------------- |
| event_id   | PK                                                         |
| user_id    | FK                                                         |
| event_type | view / add_to_cart / checkout / payment_attempt / purchase |
| product_id | 이벤트 발생 제품                                                  |
| event_time | 타임스탬프                                                      |
| referrer   | direct / search / ads / push                               |
| session_id | session 구분용                                                |


### ERD 구조

![ERD](docs/erd.png)

---

# 4. 🛠 Synthetic Dataset Generation (Python)

Python을 활용해 현실성 높은 Synthetic Dataset을 생성했습니다.

### ✔ Users
- 최근 36개월 가입 분포 (최근 18개월 70%)  
- device / region / marketing_source  
- Subscription (Free/Plus/Premium) + realistic join date  
- anomaly 의도적 삽입 (1%)

### ✔ Products
- 7개 카테고리  
- normal/log-normal 가격 분포  
- price_tier (low/mid/high)  
- discount_day_of_week (요일 할인 정책)

### ✔ Orders / Order Items
- Seasonality 반영  
- 사용자 타입별 구매 빈도 분포  
- order_items에 category, price denormalization  
- anomaly 포함

### ✔ User Events (Funnel Log)
- view → add_to_cart → checkout → payment → purchase  
- Medium volume (15~25 events/user)  
- session 기반 timestamp  
- realistic branching + anomaly 2%

📁 경로: `src/data_generation/`

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



