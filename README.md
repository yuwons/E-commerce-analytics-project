# E-commerce-analytics-project

📦 E-commerce Analytics Project
End-to-End Data Modeling · Synthetic Dataset · SQL Data Mart · Python EDA · Funnel Analysis · Tableau Dashboard

본 프로젝트는 실제 커머스 환경을 모델링하여,

데이터 생성 → 데이터 모델링 → SQL 기반 Data Mart → Python 통계/EDA → Funnel 분석 → Tableau Dashboard까지

엔드투엔드(End-to-End) 분석 전 과정을 구현한 사이드 프로젝트입니다.

## 1. 프로젝트 목표 (Project Objective)

현실적인 커머스 환경을 가정하여 아래 분석 목표를 수행합니다:

1. **Customer Behavior Analysis**
   - LTV, 재구매율, RFM 기반 고객군 분석

2. **Category Performance Analysis**
   - 카테고리/상품 매출 기여도, 성장률, AOV 분석

3. **Funnel Analysis (Log-based)**
   - view → cart → order → purchase 단계별 전환 및 이탈(drop-off) 분석

최종적으로 Retention 개선, 전환율 최적화, 매출 성장 전략을 도출합니다.


## 2. 데이터 모델(ERD)
본 프로젝트는 실제 커머스 기업 구조를 기반으로 다음 5개 테이블로 구성됩니다.

1. **users**
   - 사용자 정보
   - 가입일, 디바이스, 지역, 유입 채널 등
2. **orders**
   - 주문 단위 데이터
   - 주문일, 주문 금액, 결제 여부
3. **order_items**
   - 주문 내 상품 상세 정보
   - 단가, 수량, product_id
4. **product**
   - 상품 정보
   - 카테고리, 가격, 브랜드 등
5. **user_events**
   - Log 기반 사용자 행동 데이터
   - view, cart, order 이벤트 포함 (세션 기반)

### ERD 구조

```
users (1) ---- (N) orders ---- (N) order_items ---- (1) products
users (1) ---- (N) user_events
```
![ERD](docs/erd.png)

## 3. Dataset Generation (Python)

Python을 활용해 실제 환경을 모방한 Synthetic Dataset을 생성합니다:

### 생성 데이터
1. User 생성 (가입일, 디바이스, 지역, 마케팅 소스 포함)
2. Product 생성 (카테고리별 가격 분포 설계)
3. Orders / Order Items 생성 (구매 빈도 및 금액 분포 반영)
4. Funnel 이벤트 기반 User Events (view → cart → order 흐름 모델링)

### 사용 기술
- Pandas
- NumPy
- Faker
- Random sampling

#### Code Directory: src/data_generation/


## 4. Data Mart (BigQuery)
SQL 기반 분석 효율을 높이기 위해 Data Mart를 설계했습니다.

### Data Mart 구성
1. dm_user_purchase_summary
   - 사용자별 LTV, 구매 패턴, 재구매 여부
2. dm_category_performance
   - 카테고리별 매출, 전환율, 성과 요약
3. dm_funnel_events
   - view → cart → purchase funnel 단계별 전환/이탈

### BigQuery Optimization:
- Partition: order_date
- Clustering: user_events (user_id, event_type)
- Funnel 분석에서 user_id 기반 필터링 성능 개선

#### Code: src/sql/*

## 5. Airflow Automation
Airflow로 Synthetic Dataset 생성 및 Data Mart 업데이트 작업을 자동화합니다.

### DAG 구성
- Synthetic Dataset Daily 생성 DAG
- Data Mart Refresh DAG
- Task Dependencies 구성

Airflow Directory: airflow/dags/

#### Code: airflow/dags/*

## 6. SQL-based Analysis
BigQuery SQL을 활용하여 주요 분석을 수행합니다:

### 분석 항목
1. Cohort & Retention 분석
2. LTV & 재구매율 분석
3. RFM 세그멘테이션 (SQL 버전)
4. 카테고리 성과 분석 (AOV, 매출 기여도, 성장률)
5. Funnel 단계별 Drop-off 분석

#### SQL 분석 Notebook: src/sql/

## 7. Python EDA & Statistical Analysis
SQL 결과를 기반으로 Python에서 심화 분석을 수행합니다:

### 분석 항목
1. EDA (분포, 상관관계 분석)
2. 고객군 AOV 비교 (t-test / Mann-Whitney U test)
3. Bootstrap 기반 A/B Test
4. RFM 분석 (Python 버전)
5. Retention Heatmap 시각화
6. Funnel 이벤트 상세 분석

#### Python Notebooks: src/python/

## 8. Tableau Dashboard
최종 분석 결과를 Tableau Dashboard로 구성합니다.

### Dashboard 구성 (4 pages)
1. KPI Overview
2. Category Performance
3. Cohort / Retention
4. Funnel Analysis (Log-based)

### 데이터 자동 업데이트
- Tableau Desktop ↔ BigQuery Live Connection
- BigQuery Data Mart 업데이트 시 Tableau가 자동 반영

#### Directory: tableau/

## 9. Final Insights
분석을 통해 다음과 같은 핵심 인사이트를 도출합니다:
1. LTV가 높은 핵심 고객군의 행동적 특징
2. Funnel 단계별 이탈 원인 및 개선 우선순위
3. 고성장/저효율 카테고리 식별 및 최적화 방안
4. Retention 개선을 위한 actionable 전략

## Tech Stack
- Python: Pandas, NumPy, Faker, Matplotlib
- SQL: BigQuery
- Airflow: DAG Scheduling
- Visualization: Tableau
- Version Control: GitHub
