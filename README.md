# 📦 E-commerce Analytics Project  
_End-to-End Data Modeling · Synthetic Dataset · SQL Data Mart · Python Behavioral Analysis · Funnel Analysis · Tableau Dashboard_

본 프로젝트는 실제 커머스 환경을 기반으로 한 **E-commerce 데이터 분석 End-to-End 파이프라인**을 구축하는 것을 목표로 합니다.  
Synthetic 데이터 생성 → 데이터 모델링 → BigQuery Data Mart → SQL 분석 → Python 행동 분석 → Tableau Dashboard까지  
실제 기업 데이터 분석 플로우를 그대로 재현한 프로젝트입니다.

---

# 1. 📌 프로젝트 목표 (Project Objective)

현실적인 커머스 환경을 가정하여 아래 분석 목표를 수행합니다:

### **1) 고객 행동 분석 (Customer Behavior Analysis)**  
- LTV, 재구매율, Time-to-First-Purchase  
- Subscription 유형(Free/Plus/Premium)별 행동 및 가치 분석  
- 신규 vs 기존 고객군의 초기 행동 차이

### **2) 카테고리 매출 & 할인 효과 분석 (Category Performance)**  
- 카테고리별 매출 기여도 / AOV / 구매 빈도  
- Discount Day(요일별 할인 이벤트)가 전환율에 미치는 영향  
- 시즌성(Seasonality) 기반 카테고리 소비 패턴

### **3) Funnel 분석 (User Journey · Log-based)**  
- view → add_to_cart → checkout_start → payment_attempt → purchase 단계별 전환  
- Drop-off 지점 및 원인 분석  
- 디바이스/구독/지역/마케팅 소스별 전환율 비교

🎯 **최종 목표:**  
Retention 개선, 전환율 최적화, 매출 성장 전략을 도출하는 실무형 분석 환경 구축.

---

# 2. 🔍 Analytical Questions (핵심 분석 질문)

본 프로젝트는 아래 주요 질문들에 답하는 것을 목표로 설계되었습니다.

## **Customer Behavior & LTV**
- 어떤 행동 패턴이 장기 LTV를 가장 잘 설명하는가?  
- Subscription 가입 고객과 Free 고객의 재구매율 차이는 왜 발생하는가?  
- 첫 구매 전환까지 걸리는 시간(Time-to-First-Purchase)은 LTV와 어떤 상관관계를 가지는가?  

## **Funnel & Drop-off Analysis**
- view → add_to_cart → checkout → payment → purchase 단계에서 가장 큰 이탈은 어디서 발생하는가?  
- 장바구니를 건너뛰고 바로 checkout/purchase하는 유저는 어떤 특성을 가지는가?  
- 신규/기존, 디바이스, 지역, 마케팅 채널에 따른 전환 패턴은 어떻게 다른가?  

## **Category & Discount Effect**
- 카테고리별 구매 빈도·AOV·재구매율은 어떻게 다른가?  
- Discount Day는 신규 고객 전환에 어떤 영향을 주는가?  
- 고가 제품군(high-tier) 구매 고객은 어떤 행동적 특징을 보이는가?  

## **Retention & Cohort**
- D1/D7/D30 Retention은 어떤 초기 행동 변수와 가장 큰 상관관계를 가지는가?  
- 초기 이탈 고객과 장기 잔존 고객의 차이는 무엇인가?  

---

# 3. 🗂 데이터 모델(ERD)

본 프로젝트는 실제 커머스 구조를 기반으로 **5개 테이블**로 구성됩니다.

1. **users** — 사용자 프로필(가입일, 디바이스, 지역, 마케팅 소스, 구독 정보)  
2. **products** — 상품 카테고리, 가격, 할인 요일  
3. **orders** — 주문 정보 (seasonality, 결제상태 포함)  
4. **order_items** — 주문 상세 정보 (denormalized category/price 포함)  
5. **user_events** — Log 기반 행동 이벤트 (세션 기반 Funnel)

### ERD 구조

![ERD](docs/erd.png)

---

# 4. 🛠 Synthetic Dataset Generation (Python)

Python을 활용해 현실적인 고객 행동·구매 패턴·Funnel 흐름을 반영한 Synthetic Dataset을 생성합니다.

### ✔ Users
- 최근 36개월 분포 (최근 18개월 70%)  
- device / region / marketing_source 기반 프로필  
- Subscription (Free / Plus / Premium) + 가입 시점 로직  
- anomaly 1% 포함

### ✔ Products
- 7개 카테고리  
- 카테고리별 normal/log-normal 가격 분포  
- price_tier (low/mid/high)  
- discount_day_of_week  

### ✔ Orders / Order Items
- 시즌성(Seasonality) 반영  
- 사용자 타입별 구매 빈도 차등  
- denormalized category/price  
- anomaly 포함  

### ✔ User Events (Funnel Log)
- view → add_to_cart → checkout_start → payment_attempt → purchase  
- Medium volume (15~25 events/user)  
- session_id 별 자연스러운 timestamp 흐름  
- 정상 branch + 실제 서비스 branch 포함  
- anomaly 2% 포함  

### 사용 라이브러리
`pandas`, `numpy`, `faker`, `random`, `datetime`

📁 코드 경로: `src/data_generation/`

---

# 5. 🧱 Data Mart (BigQuery)

분석 효율을 극대화하기 위해 SQL 기반 Data Mart를 구성합니다.

### Data Mart 구성
#### **1) dm_user_purchase_summary**
- LTV  
- 구매횟수 / 첫구매일 / 재구매 여부  
- Subscription별 지표 비교  

#### **2) dm_category_performance**
- 카테고리 매출  
- AOV  
- 성장률 / 시즌성  

#### **3) dm_funnel_events**
- 단계별 전환율  
- Drop-off 분석  
- session 기반 행동 데이터  

### BigQuery 성능 최적화
- **Partition**: `orders.order_date`  
- **Clustering**: `user_events(user_id, event_type)`  

📁 SQL 코드: `src/sql/`

---

# 6. 📊 SQL-Based Analysis

### 주요 분석 항목
1. Cohort & Retention  
2. LTV & 재구매 패턴  
3. Subscription 효과 분석  
4. 카테고리 성과 분석  
5. Funnel Drop-off & Behavior 기반 분석  

📁 Notebook: `src/sql/`

---

# 7. 🐍 Python EDA & Statistical Analysis

### 분석 항목
- 분포 분석  
- 사용자군 KPI 비교 (t-test, Mann-Whitney U)  
- Bootstrap 기반 통계 검정  
- Retention Heatmap  
- Funnel Visualization  
- Behavior Pattern Analysis  

📁 Notebook: `src/python/`

---

# 8. 📈 Tableau Dashboard

### Dashboard 구성 (4 pages)
1. KPI Overview  
2. Category Performance  
3. Cohort / Retention  
4. Funnel & Drop-off (Log 기반)

### 데이터 자동 업데이트
- BigQuery Live Connection  
- Data Mart 갱신 시 Tableau 자동 반영  

📁 Tableau 파일: `tableau/`

---

# 9. 🔍 Final Insights

최종 분석을 통해 아래와 같은 핵심 인사이트를 도출합니다:

1. 높은 LTV 고객군의 행동적 특징  
2. Funnel 단계별 주요 이탈 요인 및 개선 전략  
3. Discount Day가 신규 고객 전환에 미치는 영향  
4. 성장/저효율 카테고리 식별  
5. Retention 개선을 위한 초기 Activation Indicator 도출

---

# 🧰 Tech Stack
- **Python**: pandas, numpy, faker, matplotlib  
- **SQL**: BigQuery  
- **Airflow**: DAG Scheduling  
- **Visualization**: Tableau  
- **Infra**: GitHub  

