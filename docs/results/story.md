# Story — Activation × Consistency → LTV/Retention (v1.0)

> 핵심 메시지: **초기 14일 Activation만으로는 장기 성과를 설명하기 부족**하며,  
> **180일 Consistency(재방문 리듬)** 가 장기 LTV/Retention을 강하게 분리한다.

---

## 0) TL;DR

- **Consistency가 장기 성과를 크게 갈라놓는다.**
- 특히 **낮은 Activation(A0/A1/A2)** 구간에서 Consistency의 영향이 폭발적으로 크다.
- 병목은
  - **14일 윈도우:** `view → click` 구간이 주 병목
  - **30일 윈도우:** `click → add_to_cart` 구간이 주 병목

---

## 1) Data & Metric Setup

### Data (v1.0)
- users / sessions / events / orders / order_items (+ promo)
- Subscription 결과 분석은 v1.0에서 제외

### Definitions
- **Activation (14d):** 유저가 가입 후 14일 내 도달한 최고 퍼널 단계
  - A0_no_activity / A1_view / A2_click / A3_add_to_cart / A4_checkout / A5_purchase
- **Consistency (180d):** 방문 리듬/불규칙성(예: active_days, intervisit_cv, weekly regularity 등)
  - C1(낮음) ~ C5(높음)
- **Outcome (180d):**
  - purchase_rate_180d
  - avg_revenue_180d
  - retention_last_week (180일 후반 주차 잔존)

---

## 2) Finding #1 — Consistency lift is real (Figure 02)

> 같은 Activation이어도 Consistency가 높으면 LTV/Retention이 크게 상승한다.

![Figure02](docs/results/figures/02_figure_a.png)

**C1(낮음) vs C5(높음) 비교 (예시)**  
- **A0_no_activity**
  - purchase_rate_180d: **1.5% → 35.9%** (약 **24.1x**, lift +2312%)
  - avg_revenue_180d: **3.5k → 110.7k** (약 **31.0x**, lift +3025%)
  - retention_last_week: **23.5% → 48.5%** (약 **2.07x**)
- **A1_view**
  - purchase_rate_180d: **6.1% → 69.8%** (약 **11.4x**)
  - avg_revenue_180d: **11.2k → 246.7k** (약 **22.0x**)
  - retention_last_week: **25.8% → 80.6%** (약 **3.12x**)
- **A4_checkout**
  - purchase_rate_180d: **29.3% → 84.0%** (약 **2.86x**)
  - avg_revenue_180d: **104.3k → 417.0k** (약 **4.00x**)

✅ 결론: **Activation이 낮은 구간일수록 “Consistency가 성패를 갈라놓는 변수”** 로 작동한다.

---

## 3) Finding #2 — Activation × Consistency Matrix (Figure 03)

![Figure03](docs/results/figures/03_figure_a.png)

- Activation이 올라갈수록 평균 성과가 상승하는 건 자연스럽다.
- 하지만 **Activation이 같아도 Consistency(C1~C5)에 따라 장기 성과가 급격히 갈린다.**
- 즉, “초기 전환”만 보는 시각은 위험하고, **재방문 리듬(Consistency)까지 함께 봐야** 장기 성과를 예측할 수 있다.

---

## 4) Finding #3 — Funnel Drop-off (Figure 04)

![Figure04](docs/results/figures/04_figure_a.png)

- 윈도우별 퍼널 전환에서 세그먼트별 drop-off가 다르게 나타남
- 특히 낮은 Activation / 낮은 Consistency 세그먼트에서 초기 단계 이탈이 두드러짐

---

## 5) Finding #4 — Worst Bottleneck Segments (Figure 05)

![Figure05](docs/results/figures/05_figure_a.png)

**Top bottleneck patterns**
- **14일 윈도우:** worst segment의 병목은 주로 **view → click**
- **30일 윈도우:** worst segment의 병목은 주로 **click → add_to_cart**

해석:
- 단기(14일): “보긴 보는데 클릭을 안 한다” → **CTR/상세페이지 유도/추천 품질/콘텐츠** 이슈
- 중기(30일): “클릭은 하는데 담지를 않는다” → **가격/혜택/신뢰요소/장바구니 UX/배송정보** 이슈

---

## 6) What to do next (Product-thinking)

- **14일 개선:** view→click 개선 실험(추천/썸네일/리스트 정렬/상세 진입 유도)
- **30일 개선:** click→cart 개선 실험(혜택 노출, 배송/리뷰 정보, 장바구니 friction 제거)
- **세그먼트 전략:** 낮은 Activation(A0~A2)에서도 **Consistency가 높은 유저**는 장기 잠재력이 크므로
  - “초기 전환만 보고 버리지 말고”, 리텐션/리마인드 중심 전략으로 키울 수 있음

---

## 7) Appendix
- Result CSV: `docs/results/csv/`
- SQL: `src/sql/analysis/`
- DM SQL: `src/sql/datamart/`

