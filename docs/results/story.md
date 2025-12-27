# Story — Activation × Consistency → LTV/Retention (v1.0)

> 핵심 메시지: **초기 14일 Activation만으로는 장기 성과를 설명하기 부족**하며,  
> **180일 Consistency(재방문 리듬)** 가 장기 LTV/Retention을 강하게 분리한다.

---

## 0) TL;DR

- **Consistency는 장기 성과(LTV/Retention)를 크게 갈라놓는 핵심 변수다.**
- 특히 **낮은 Activation(A0/A1/A2)** 구간에서 Consistency의 영향이 폭발적으로 커진다.
- Funnel 관점 병목은 윈도우에 따라 다르다.
  - **14일(초기):** `view → click` 구간이 주 병목
  - **30일(중기):** `click → add_to_cart` 구간이 주 병목

---

## 1) Data & Metric Setup

### Data (v1.0)
- users / sessions / events / orders / order_items (+ promo)
- Subscription 결과 분석은 v1.0에서 제외

### Definitions
- **Activation (14d):** 가입 후 14일 내 도달한 최고 퍼널 단계  
  - `A0_no_activity / A1_view / A2_click / A3_add_to_cart / A4_checkout / A5_purchase`
- **Consistency (180d):** 재방문 리듬/불규칙성 기반 지표(예: active_days, intervisit_cv, weekly regularity 등)  
  - `C1(낮음) ~ C5(높음)`
- **Outcome (180d):**
  - `purchase_rate_180d`
  - `avg_revenue_180d`
  - `retention_last_week` (180일 후반부 잔존)

---

## 2) Finding #1 — Consistency lift is real (Figure 01)

> 같은 Activation이어도 **Consistency가 높으면** LTV/Retention이 크게 상승한다.  
> 특히 **낮은 Activation 구간(A0~A2)** 에서 uplift가 가장 극단적으로 나타난다.

![Figure 01A](./figures/01_figure_a.png)

![Figure 01B](./figures/01_figure_b.png)

**C1(낮음) vs C5(높음) 비교 (예시)**  
- **A0_no_activity**
  - purchase_rate_180d: **1.5% → 35.9%** (약 **24.1x**)
  - avg_revenue_180d: **3.5k → 110.7k** (약 **31.0x**)
  - retention_last_week: **23.5% → 48.5%** (약 **2.07x**)
- **A1_view**
  - purchase_rate_180d: **6.1% → 69.8%** (약 **11.4x**)
  - avg_revenue_180d: **11.2k → 246.7k** (약 **22.0x**)
  - retention_last_week: **25.8% → 80.6%** (약 **3.12x**)
- **A4_checkout**
  - purchase_rate_180d: **29.3% → 84.0%** (약 **2.86x**)
  - avg_revenue_180d: **104.3k → 417.0k** (약 **4.00x**)

✅ 결론: **Activation이 낮을수록 “Consistency가 성패를 가르는 변수”로 작동한다.**

---

## 3) Finding #2 — Activation × Consistency Matrix (Figure 03)

> Activation이 올라갈수록 평균 성과가 상승하는 것은 자연스럽다.  
> 하지만 **Activation이 같아도 Consistency(C1~C5)에 따라 장기 성과가 급격히 갈린다.**  
> 즉, “초기 전환”만 보면 오판할 수 있고 **재방문 리듬(Consistency)까지 함께 봐야** 장기 성과를 예측할 수 있다.

![Figure 03A](./figures/03_figure_a.png)

![Figure 03B](./figures/03_figure_b.png)

---

## 4) Finding #3 — Funnel Drop-off by Window (Figure 04)

> 동일한 퍼널이라도 **윈도우(14d vs 30d)** 에 따라 병목 위치가 달라진다.  
> 또한 **낮은 Activation / 낮은 Consistency** 세그먼트에서 초기 이탈이 특히 두드러진다.

![Figure 04A](./figures/04_figure_a.png)

![Figure 04B](./figures/04_figure_b.png)

---

## 5) Finding #4 — Worst Bottleneck Segments (Top 10) (Figure 05)

> “어떤 세그먼트가” “어떤 스텝에서” 가장 크게 막히는지 Top 10으로 정리했다.

![Figure 05A](./figures/05_figure_a.png)

![Figure 05B](./figures/05_figure_b.png)

**Top bottleneck patterns**
- **14일 윈도우:** worst segment 병목은 주로 **view → click**
- **30일 윈도우:** worst segment 병목은 주로 **click → add_to_cart**

해석(가설):
- 단기(14일): “보긴 보는데 클릭을 안 한다”  
  → **CTR / 리스트→상세 진입 유도 / 추천 품질 / 콘텐츠(썸네일·카피)** 이슈 가능성
- 중기(30일): “클릭은 하는데 담지를 않는다”  
  → **가격/혜택/신뢰요소(리뷰·배송·반품) / 장바구니 UX friction** 이슈 가능성

---

## 6) What to do next (Product-thinking)

- **14일 개선 (view→click):**
  - 추천/정렬/썸네일/카피/상세 진입 CTA에 대한 A/B 테스트
- **30일 개선 (click→cart):**
  - 혜택/쿠폰 노출 타이밍, 배송·리뷰·반품 정보 가시성, 장바구니 진입 friction 제거
- **세그먼트 전략:**
  - 낮은 Activation(A0~A2)이라도 **Consistency가 높은 유저는 장기 잠재력이 크다**
  - “초기 전환만 보고 버리지 말고” **리텐션/리마인드 중심으로 키울 가치가 있음**

---

## 7) Appendix

- Result CSV: `docs/results/csv/`
- Figures: `docs/results/figures/`
- SQL (analysis): `src/sql/analysis/`
- SQL (datamart): `src/sql/datamart/`
