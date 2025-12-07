# E-commerce-analytics-project
이커머스 데이터 모델링·데이터 생성·SQL 분석·파이썬 EDA·퍼널 분석·Tableau 대시보드 프로젝트입니다. 전체 데이터셋 설계 문서는 README에서 확인해주세요.

📦 E-commerce Analytics Project
이 프로젝트는 실제 이커머스 환경을 모델링한 **Synthetic Dataset(가상 데이터셋)**을 기반으로
데이터 모델링 → 데이터 생성 → SQL(Big Query) 분석 → Python EDA → Funnel 분석 → Tableau 대시보드 제작까지
전 과정을 수행하는 엔드투엔드 데이터 분석 프로젝트입니다.

📘 프로젝트 목적
사용자 행동 분석
구독(subscription) 등급에 따른 LTV 분석
카테고리 성과 분석
퍼널(drop-off) 분석 및 전환 최적화
Discount Day 전환율 상승 효과 분석
Retention / Cohort 분석
전체 데이터셋은 오늘의집·쿠팡·요기요 등 실제 커머스 기업의 구조를 참고하여 설계했습니다.

🏗 데이터 모델(ERD)
본 프로젝트는 아래 5개의 테이블로 구성됩니다:
users
products
orders
order_items
user_events (funnel logs)

자세한 데이터셋 구조와 설계 의도는 /docs/dataset_spec_kr.md에서 확인할 수 있습니다.

🧱 프로젝트 구성
ecommerce-analytics-project/
│
├── README.md
├── docs/
│   ├── dataset_spec_kr.md     # 한국어 데이터셋 설계 문서
│   └── dataset_spec_en.md     # English specification
│
├── src/
│   ├── data_generation/       # 데이터 생성 Python 스크립트
│   ├── sql/                   # SQL 분석 코드
│   └── python/                # Python 분석/EDA 코드
│
└── tableau/
    └── dashboard/             # Tableau 대시보드 이미지 및 설명

🔧 Data Pipeline & Automation
본 프로젝트에서는 SQL 기반 Data Mart를 설계하고,
Airflow를 활용하여 데이터 생성 및 업데이트 작업을 자동화하는 구조를 일부 구현하였습니다.

구성 요소:
Data Mart (BigQuery)
 - dm_user_purchase_summary
 - dm_category_performance
 - dm_funnel_events

Airflow DAG
 - 데이터 생성 스케줄링 (daily)
 - Data Mart 리프레시 자동화
 - Dependency 구성


🧪 분석 예정 항목
Subscription 등급별 LTV & AOV 분석
Funnel 단계별 Drop-off 및 전환율 분석
Discount Day 전환 uplift 분석
주문 패턴, Basket Size 분석
카테고리별 매출/수량/전환 성과
Cohort 기반 Retention 분석

🛠 기술 스택
SQL
Python (Pandas, NumPy, Matplotlib)
BigQuery
Tableau
GitHub
    
