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
