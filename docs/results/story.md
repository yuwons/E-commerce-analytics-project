# [Story] Activation × Consistency → Future LTV/Retention (v1.0 → v1.1)

> **핵심 메시지**  
> **초기 14일 Activation만으로는 장기 성과를 충분히 설명하기 어렵고**,  
> **“방문 리듬(Consistency)”이 특히 저Activation 유저의 미래 가치(LTV/Retention)를 강하게 가른다.**  
> 단, v1.0 결과는 같은 180일 창에서 Predictor/Outcome을 동시에 사용한 한계(tautology)가 존재하여,  
> v1.1에서 **Time-split(관측창/성과창 분리)**로 분석 프레임을 고도화한다.

---

## 0) Executive Summary

### 0.1 What we saw (v1.0)
- Activation stage(A0~A5)로 유저를 나누고, 각 stage 내부에서 Consistency(C1~C5)로 다시 나누면  
  **C1 → C5로 갈수록 180일 구매율/매출이 급격히 상승**한다.  
  특히 **A0/A1(저Activation)** 구간에서 lift가 매우 크다.  
  - 예: A0에서 purchase_rate_180d가 **1.5% → 35.9%**, avg_revenue_180d가 **3.5k → 110.7k**로 크게 증가
- 다만 “avg_revenue_180d lift(20~31x)”는 일부 **Mix effect(구매자 비중 증가)**가 크게 기여한다.  
  구매자만 놓고 보면 매출 차이는 훨씬 줄어들며(대략 1.3~1.6x 수준),  
  **핵심은 ‘한 번이라도 구매할 확률(purchase_rate)’이 Consistency에 의해 크게 갈린다는 점**이다.

### 0.2 Why we changed the plan (v1.1)
- v1.0은 **Consistency를 0~180일로 계산하고, Outcome도 0~180일 LTV/Retention을 사용**했다.  
  이 구조는 “오래 남아서 자주 온 사람이 돈을 많이 쓴다”는 **자기증명(tautology)** 리스크가 있다.
- 따라서 v1.1은 **Time-split**으로 전환한다.
  - **관측창(Observation): 0~60일** → Activation/Consistency를 “Predictor”로 정의
  - **성과창(Performance): 61~180일** → LTV/Retention을 “Outcome”으로 정의  
  → 결론을 “초기 60일 행동 패턴이 이후 120일 가치를 예측한다”로 바꾸어 분석 가치를 올린다.

---

## 1) Metric Definition

### 1.1 Activation Stage (0~14d)
가입 후 14일 내 도달한 최종 이벤트 기준.
- A0_no_activity, A1_view, A2_click, A3_add_to_cart, A4_checkout, A5_purchase

### 1.2 Consistency (v1.0: 0~180d)
세션 기반 “재방문 리듬”을 수치화.
- active_days_180d: 180일 내 세션이 있었던 일수
- intervisit_cv_180d: 방문 간격(day gap)의 변동계수(CV = std / mean)
- consistency_score_v1 = z(active_days_180d) - z(intervisit_cv_180d)  
  → 높을수록 “자주 & 규칙적”인 방문 리듬
- consistency_segment(C1~C5): consistency_score를 5분위로 구간화

> **중요 메모(결과 해석)**  
> v1.0에서 “Consistency↑ → 매출↑”가 강하게 나오더라도,  
> Predictor/Outcome이 같은 기간(0~180d)에 묶여있어서 과대평가 가능성이 존재한다.

### 1.3 Outcomes (v1.0: 0~180d)
- purchase_rate_180d: 180일 내 1회 이상 구매 비율
- avg_revenue_180d: 180일 총매출 평균(구매자+비구매자 포함)
- avg_revenue_buyer_only: 구매자만의 180일 총매출 평균
- retention_last_week_180d: 180일 마지막 7일 내 세션 존재 여부(또는 정의된 last-week active)

---

## 2) Core Findings (v1.0)

## 2.1 “Activation이 낮아도, Consistency가 높으면 장기 성과가 폭발한다”
Activation stage 내부에서 C1→C5로 갈수록 구매율/매출이 상승한다.
- 특히 A0/A1에서 lift가 가장 크다.
  - A0: purchase_rate_180d **1.5% → 35.9%**, avg_revenue_180d **3.5k → 110.7k**
  - A1: avg_revenue_180d도 큰 폭으로 상승(저Activation이라도 리듬이 있으면 성과가 커짐)

> 해석: **초기 14일에 ‘구매’까지 못 간 유저라도**,  
> 이후 180일 동안 “꾸준히 돌아오는 리듬”을 보이면 장기 구매/매출로 연결될 가능성이 커진다.

---

## 2.2 “20~31배 매출 격차”의 대부분은 ‘구매자 비중(Mix effect)’이다
avg_revenue_180d는 **비구매자(매출=0)**를 포함한 평균이라,
purchase_rate가 크게 갈리면 평균 매출 격차가 매우 커진다.

그래서 구매자만 분리해서 보면:
- avg_revenue_buyer_only의 차이는 **상대적으로 작아지고(대략 1.3~1.6x)**,
- 진짜 핵심은 **구매 확률(purchase_rate_180d)이 C1→C5에서 크게 벌어진다는 점**이다.

> 결론적으로 v1.0의 “큰 매출 lift”는  
> (1) **구매자 비중 증가** + (2) **구매자당 매출 증가**가 합쳐진 결과이며,  
> 그중 (1)의 기여가 매우 크다.

---

## 3) Funnel Bottleneck Findings (v1.0)

### 3.1 14일 병목: View → Click
- 14일 윈도우에서는 **view_to_click**이 가장 큰 병목으로 나타난다.
- 중앙값 기준 0에 가까운 segment가 많아 “초기 탐색→클릭” 전환이 막히는 유저군이 큼.

### 3.2 30일 병목: Click → Add-to-cart
- 30일 윈도우로 확장하면 **click_to_cart**가 가장 큰 병목으로 이동한다.
- 즉 “클릭은 하는데 장바구니로 안 넘어가는 문제”가 더 뚜렷해진다.

> 해석(현상 → 액션 가설):  
> - 14d view→click: 첫 방문 UI/추천/썸네일/카피 등 “클릭 유도” 품질 문제 가능  
> - 30d click→cart: 상세 페이지 신뢰/가격/리뷰/배송/혜택 등 “설득 요소” 부족 가능

---

## 4) v1.0의 한계와 v1.1 고도화 계획

### 4.1 Limitation: Tautology Risk
- v1.0은 Consistency(0~180d)와 Outcome(LTV/Retention 0~180d)이 같은 창에 있어  
  “오래 남고 자주 온 사람이 돈을 많이 쓴다”라는 **당연한 결론**이 될 위험이 있다.

### 4.2 Fix: Time-split (Predictive Analysis Framework)
v1.1은 아래처럼 시간축을 분리한다.
- **Observation window (0~60d)**  
  - Activation_obs_14d(또는 30d)  
  - Consistency_obs_60d (active_days / intervisit_cv / weekly regularity 등)
- **Performance window (61~180d)**  
  - revenue_61_180d, orders_61_180d, purchase_flag_61_180d  
  - retention_61_180d (ex: last-week active in days 174~180 등)

> v1.1 메시지 전환 예시  
> X) “180일 내내 꾸준한 유저가 돈을 많이 쓴다”  
> O) “가입 초기 60일 동안 방문 리듬이 안정적인 유저는, 이후 120일 동안 더 높은 LTV/Retention을 만든다”

### 4.3 Python 확장: “유저군 × 병목 step” 교차 분석
SQL로 전체 병목을 본 뒤, Python에서 유저 세그먼트(A/B/C/D 등)를 **행동 기반으로 재현**해
- 유저군별로 병목이 “어디서” “왜” 다른지 해석 깊이를 올린다.
- 면접 스토리: “SQL로 1차 인사이트 → 한계 발견 → Python에서 세그먼트 교차로 2차 심화” 흐름이 가능.

> 참고: raw users 테이블에 있는 `user_type`은 **모델/분석에 직접 노출하지 않고**,  
> Python에서 행동 기준으로 라벨링을 재현한 뒤 **내부 검증용으로만 비교**하는 방향이 더 자연스럽다.

---

## Appendix) Used Data Marts (v1.0)
- `ecommerce_dm.DM_user_window`
- `ecommerce_dm.DM_consistency_180d`
- `ecommerce_dm.DM_ltv_180d`
- `ecommerce_dm.DM_retention_cohort`
- `ecommerce_dm.DM_funnel_kpi_window`
- `ecommerce_dm.DM_funnel_session`

## Appendix) Planned Mart (v1.1)
- `ecommerce_dm.DM_timesplit_60_180_final`
  - predictors: obs_0_60d
  - outcomes: perf_61_180d

---
