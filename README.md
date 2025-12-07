# E-commerce-analytics-project

📦 E-commerce Analytics Project
End-to-End Data Modeling · Synthetic Dataset · SQL Data Mart · Python EDA · Funnel Analysis · Tableau Dashboard
본 프로젝트는 실제 커머스 기업의 데이터 환경을 모델링하여,
데이터 생성 → 데이터 모델링 → SQL 기반 분석 → Python 통계/EDA → Funnel 분석 → 대시보드 제작까지
엔드투엔드(End-to-End) 분석 전 과정을 구현한 사이드 프로젝트입니다.

🎯 프로젝트 목표 (Project Objective)

현실적인 커머스 환경을 가정하여 다음 분석 목표를 달성합니다:
고객군 행동 차이 분석
LTV, 재구매율, RFM 기반 세그먼트별 행동 패턴 파악
카테고리 성과 및 성장 분석
카테고리/상품별 매출 기여도, AOV, 트렌드 분석
로그 기반 Funnel 분석
view → cart → order → purchase 단계별 전환율 및 drop-off 인사이트 도출
전체 분석 결과는 사용자 유지율(Retention) 개선,
전환율 최적화, 매출 성장 전략을 설계하는 데 목적을 둡니다.


🏗 데이터 모델(ERD)
본 프로젝트는 실제 커머스 기업 구조를 기반으로 다음 5개 테이블로 구성됩니다.

users : 사용자 정보
orders : 주문 정보
order_items : 주문 상세 정보
products : 상품 정보
user_events : 로그 기반 행동 데이터 (view, cart, order 등)

users (1) ─── (N) orders ─── (N) order_items ─── (1) products
users (1) ─── (N) user_events (funnel log)

🧪 Dataset Generation (Python)

프로젝트에서는 Python을 활용해 실제 서비스 환경을 모방한 Synthetic Dataset을 생성합니다:

User 생성 (가입일, 기기, 지역, 마케팅 유입경로 반영)
Product 생성 (카테고리별 가격/속성 분포 설계)
Orders / Order Items 생성 (구매 빈도, 금액, 장바구니 메커니즘 반영)
User Events 로그 생성 (session 기반 view → cart → order 흐름 모델링)
Code: src/data_generation/*

🗄 Data Mart (BigQuery)

SQL 기반 분석 효율을 높이기 위해 Data Mart를 설계했습니다.

📂 Data Mart 구성
Data Mart	                                설명
dm_user_purchase_summary	    사용자별 LTV, 구매 패턴, 재구매 여부
dm_category_performance	        카테고리별 매출, 전환율, 성과 요약
dm_funnel_events	            view → cart → purchase funnel 단계별 전환/이탈

Code: src/sql/*

🔁 Airflow Automation

본 프로젝트에서는 Data Mart 및 데이터 생성 프로세스를 자동화하기 위해 Airflow를 활용합니다.

📌 DAG 구성
Synthetic Dataset Daily 생성 DAG
Data Mart Refresh DAG
작업 간 Dependency 정의
→ 실제 회사 환경의 ETL 구조를 단순화해 구현

Code: airflow/dags/*

📊 SQL 기반 주요 분석

Cohort 분석 & Retention 분석
LTV & 재구매율 분석
RFM 세그멘테이션 (SQL 버전)
카테고리 성과 분석 (AOV, 매출 기여도)
Funnel 단계별 Drop-off 분석
SQL Notebook 및 쿼리: src/sql/*

🧠 Python EDA & Statistical Analysis

Python을 활용하여 SQL 결과를 기반으로 심화 분석을 수행합니다.

EDA(분포/상관관계)
사용자군 AOV 비교 (t-test / Mann-Whitney U test)
Bootstrap 기반 A/B Test
RFM 분석 (Python 버전)
Retention Heatmap 시각화
Funnel 단계별 이탈 패턴 탐색
Notebook: src/python/*

📈 Tableau Dashboard

최종 분석 결과는 Tableau로 시각화하여 대시보드를 구성합니다.

📌 Dashboard 구성 (4개 페이지)
KPI Overview
Category Performance
Cohort / Retention
Funnel Analysis (로그 기반)

🔄 데이터 자동 업데이트
Tableau Desktop ↔ BigQuery Live Connection
BigQuery Data Mart가 업데이트되면 대시보드도 자동 반영
Dashboard 이미지: tableau/*

🧩 Final Insights

프로젝트에서 도출할 최종 인사이트 예시:
핵심 고객군의 LTV 상승 요인
Funnel 단계별 주요 이탈 포인트
고성장/저효율 카테고리 식별
Retention 개선을 위한 actionable 전략 제안

🛠 Tech Stack
Python: Pandas, NumPy, Faker, Matplotlib

SQL: BigQuery

Airflow: DAG Scheduling

Visualization: Tableau

Version Control: GitHub
