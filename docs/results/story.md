# Story — Activation × Consistency → LTV/Retention (v1.0)

> 핵심 메시지: **초기 14일 Activation만으로는 장기 성과를 설명하기 부족**하며,  
> **180일 Consistency(재방문 리듬)** 가 장기 LTV/Retention을 강하게 분리한다.

---

## 0) TL;DR

- **Consistency는 장기 성과(LTV/Retention)를 크게 갈라놓는 핵심 변수다.**
- 특히 **낮은 Activation(A0/A1/A2)** 구간에서 Consistency uplift가 폭발적으로 커진다.
- 이 uplift는 단순히 “구매자 1회당 객단가”보다는, **구매확률(purchase_rate) + 반복구매/주문수**에서 크게 발생한다.
- Funnel 병목은 윈도우에 따라 달라진다.
  - **14일(초기):** `view → click` 구간이 주 병목
  - **30일(중기):** `click → add_to_cart`(=click_to_cart) 구간이 주 병목

---

## 1) Data & Metric Setup

### Data (v1.0)
- users / sessions / events / orders / order_items (+ promo)
- **Subscription 결과 분석은 v1.0에서 제외** (scope out)

### Definitions
- **Activation (14d):** 가입 후 14일 내 도달한 최고 퍼널 단계
  - `A0_no_activity / A1_view / A2_click / A3_add_to_cart / A4_checkout / A5_purchase`
- **Consistency (180d):** 재방문 리듬/불규칙성 기반 지표
  - `C1(낮음) ~ C5(높음)`
- **Outcome (180d):**
  - `purchase_rate_180d`
  - `avg_revenue_180d`
  - `retention_last_week` (180일 후반부 잔존)

> 참고: Figure 02의 `*_lift_ratio_x`는 “배수”가 아니라 **(C5/C1 − 1)** 형태의 상대증가율이다.  
> - **multiple(배수)** = `C5/C1`  
> - **lift_ratio(상대증가율)** = `(C5/C1 − 1)`

---

## 2) Finding #1 — Consistency lift is real (Figure 01 & 02)

> 같은 Activation이어도 **Consistency가 높으면** LTV/Retention이 크게 상승한다.  
> 특히 **낮은 Activation 구간(A0~A2)** 에서 uplift가 가장 극단적으로 나타난다.

![Figure 01A](./figures/01_figure_a.png)

![Figure 01B](./figures/01_figure_b.png)

### C1(낮음) vs C5(높음) 비교 (대표 예시)
- **A0_no_activity**
  - purchase_rate_180d: **1.5% → 35.9%** (약 **24.1x**)
  - avg_revenue_180d: **3.5k → 110.7k** (약 **31.2x**)
  - retention_last_week: **0.23 → 0.48** (약 **2.09x**)
- **A1_view**
  - purchase_rate_180d: **6.0% → 69.8%** (약 **11.7x**)
  - avg_revenue_180d: **11.2k → 246.8k** (약 **22.0x**)
  - retention_last_week: **0.26 → 0.81** (약 **3.12x**)
- **A4_checkout**
  - purchase_rate_180d: **29.3% → 84.0%** (약 **2.86x**)
  - avg_revenue_180d: **65.8k → 320.8k** (약 **4.87x**)

✅ 결론: **Activation이 낮을수록 “Consistency가 성패를 가르는 변수”로 작동한다.**

### (요약) Activation 단계별 uplift 패턴 (Figure 02)
> Figure 02는 C1 vs C5를 “요약 테이블”로 정리한 것이다.  
> 특히 **낮은 Activation일수록 avg_revenue uplift가 매우 커지고**, Activation이 높아질수록 uplift가 줄어든다.

![Figure 02](./figures/02_figure.png)

- avg_revenue 상대증가율(lift_ratio_x = C5/C1−1)
  - A0: **+3025%** (≈ **31.25x**)
  - A1: **+2097%** (≈ **21.97x**)
  - A2: **+745%** (≈ **8.45x**)
  - A3: **+749%** (≈ **8.49x**)
  - A4: **+387%** (≈ **4.87x**)
  - A5: **+137%** (≈ **2.37x**)

---

## 3) Finding #2 — “왜” lift가 생기나? (Figure 03)

> Consistency uplift는 단순히 “구매자당 객단가” 차이만으로 설명되지 않는다.  
> **구매확률(purchase_rate)과 반복구매/주문수 차이가 핵심 드라이버**로 보인다.

![Figure 03A](./figures/03_figure_a.png)

![Figure 03B](./figures/03_figure_b.png)

### 관찰 포인트 (buyer_only 컬럼)
- `avg_revenue_180d`(전체 평균)는 C1→C5로 극적으로 상승하지만,
- `avg_revenue_180d_buyer_only`(구매자만)는 상승폭이 상대적으로 작다.

예시)
- A0: buyer_only revenue **~238k → ~309k** (약 **1.30x**)
- A1: buyer_only revenue **~189k → ~353k** (약 **1.88x**)

➡️ 해석:
- “고Consistency 유저가 사면 더 비싸게 산다”도 일부 있지만,
- 더 중요한 건 **(1) 구매할 확률이 훨씬 높고, (2) 180일 내 주문수도 늘어난다**는 점이다.

---

## 4) Finding #3 — Funnel Drop-off by Window (Figure 04)

> 동일한 퍼널이라도 **윈도우(14d vs 30d)** 에 따라 병목 위치가 달라진다.  
> 즉 “언제 보느냐”에 따라 제품/성장팀의 우선순위가 바뀐다.

![Figure 04A](./figures/04_figure_a.png)

![Figure 04B](./figures/04_figure_b.png)

- **14일:** `view_to_click`이 가장 강한 병목 신호
- **30일:** `click_to_cart`(=click→add_to_cart)이 상대적으로 더 강한 병목 신호

주의/해석:
- 14일 구간에서는 일부 스텝이 0으로 보이는 셀이 많다(표본/도달 조건 영향 가능).  
  그럼에도 **view→click이 “가장 일관된 병목”으로 확인**된다.

---

## 5) Finding #4 — Worst Bottleneck Segments (Top 10) (Figure 05)

> “어떤 세그먼트가” “어떤 스텝에서” 가장 크게 막히는지 Top 10으로 정리했다.

![Figure 05A](./figures/05_figure_a.png)

![Figure 05B](./figures/05_figure_b.png)

### Top bottleneck patterns
- **14일 윈도우:** worst segment 병목은 **view → click**
  - 특히 일부 세그먼트는 **conv_rate=0**인데 denom이 큼 → “보고도 클릭을 안 함”이 매우 강한 신호
- **30일 윈도우:** worst segment 병목은 **click → add_to_cart**(=click_to_cart)
  - 클릭 이후 장바구니로 이어지지 않는 세그먼트가 Top에 집중

---

## 6) What to do next (Product-thinking)

- **14일 개선 (view→click):**
  - 추천/정렬/썸네일/카피/상세 진입 CTA에 대한 A/B 테스트
  - 카테고리/가격대/프로모션 유무별 CTR 분해로 “클릭 막히는 조건” 찾기
- **30일 개선 (click→cart):**
  - 혜택/쿠폰 노출 타이밍, 배송·리뷰·반품 정보 가시성, 장바구니 UX friction 제거
  - “상세는 보는데 담지 않는” 상품군(가격, 배송비, 재고, 리뷰 신뢰 등) 진단
- **세그먼트 전략:**
  - 낮은 Activation(A0~A2)이라도 **Consistency가 높은 유저는 장기 잠재력이 크다**
  - 초기 전환만 보고 버리기보다 **리텐션/리마인드 중심으로 키울 가치가 있음**

---

## 7) Appendix
- Result CSV: `docs/results/csv/`
- Figures: `docs/results/figures/`
- SQL (analysis): `src/sql/analysis/`
- SQL (datamart): `src/sql/datamart/`
