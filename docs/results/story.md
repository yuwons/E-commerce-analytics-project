# Story — Activation × Consistency → LTV / Retention (v1.0)

> **한줄 요약:** 초기 14일 Activation만으로는 장기 성과를 다 설명하기 어렵고, **Consistency(재방문 리듬)** 가 180일 LTV/Retention을 강하게 분리한다.

---

## 1) Context

이 프로젝트는 **유저 행동 패턴이 단기 전환(Short-term Conversion)과 장기 성과(LTV/Retention)의 trade-off를 어떻게 만드는지**를 확인하기 위한 분석이다.  
분석은 **Synthetic dataset** 기반이며, BigQuery Data Mart(SQL)에서 파생 지표를 계산했다.

> NOTE  
> - 초기 설계에는 subscription/promotion도 포함했지만, 이번 분석 스코프에서는 **유저 행동(Session/Event) 중심**으로 집중했다.  
> - 결과 및 시각화는 본 문서의 figure(스크린샷)로 요약하고, 재현 가능한 SQL은 repo에 포함했다.

---

## 2) Key Metrics (정의)

- **Activation (0~14d)**  
  가입 후 14일 동안 유저가 도달한 **최고 funnel 단계**로 Stage를 정의  
  `A0_no_activity → A1_view → A2_click → A3_add_to_cart → A4_checkout → A5_purchase`

- **Consistency (0~180d, v1.0)**  
  세션 기반 “재방문 리듬”을 점수화  
  예: `z(active_days) - z(intervisit_cv)` 형태의 score로 정의 후, **퀀타일로 C1~C5** 세그먼트화  
  (C1 = 낮은 Consistency, C5 = 높은 Consistency)

- **LTV (0~180d)**  
  가입 후 180일 내 매출 합(orders/order_items 기반)

- **Retention (Point, 180d)**  
  180일 윈도우 마지막 7일에 재방문(세션) 여부로 point retention 정의

---

## 3) Finding #1 — Activation만으로는 장기 성과를 설명하기 부족

Activation stage가 높을수록 LTV/Retention이 좋아지는 건 자연스럽다.  
그런데 같은 Activation stage 안에서도 **Consistency(C1~C5)** 에 따라 장기 성과가 크게 갈렸다.

- 특히 **낮은 Activation (A0~A2)** 구간에서  
  “초기 전환은 약했지만, 리듬 있게 돌아오는 유저(C5)”가 장기 성과에서 더 강하게 나타났다.

**Figure 01 — Activation × Consistency × (LTV / Retention point)**  
![Figure01a](figures/01_figure_a.png)
![Figure01b](figures/01_figure_b.png)

---

## 4) Finding #2 — Consistency의 Lift는 저(低) Activation 구간에서 더 크다

C5(상위 Consistency) vs C1(하위 Consistency)을 비교했을 때,  
Activation stage별로 **장기 성과 lift 패턴**이 달랐다.

- 고(高) Activation(A4~A5)에서도 Consistency 차이는 존재하지만,
- **저(低) Activation(A0~A2)에서 lift가 더 의미있게 관찰**된다  
  → “초기 전환만 보고 유저 가치를 과소평가할 수 있다”는 시사점

**Figure 02 — Headline lift (C5 vs C1) by Activation**  
![Figure02](figures/02_figure.png)

---

## 5) Finding #3 — (간소화 뷰) Activation × Consistency × LTV

핵심 패턴만 보이도록 간소화한 뷰에서도 동일한 흐름이 유지됐다.  
즉, **Activation은 “초기 강도”**, Consistency는 **“장기 리듬”**으로 역할이 분리되어 보인다.

**Figure 03 — Activation × Consistency × LTV (slim)**  
![Figure03a](figures/03_figure_a.png)
![Figure03b](figures/03_figure_b.png)

---

## 6) Finding #4 — Funnel 병목: 14일 vs 30일의 bottleneck이 다르다

유저가 funnel을 진행하는 과정에서, “어디서 막히는지”를 확인했다.  
(Reach/Frequency 기반)

- **14일 윈도우**에서는 `view → click` 구간이 상대적으로 큰 병목으로 관찰됨  
- **30일 윈도우**에서는 `click → add_to_cart` 구간의 마찰이 더 두드러짐

**Figure 04 — Bottleneck (Frequency / Reach) (w14 vs w30)**  
![Figure04a](figures/04_figure_a.png)
![Figure04b](figures/04_figure_b.png)

---

## 7) Finding #5 — “Worst segments” Top10 (병목이 큰 세그먼트)

특정 세그먼트는 상단 단계 reach는 있으나 다음 단계로 잘 이어지지 않는 패턴을 보였다.  
(= “왔는데 못 넘어가는” 유저군)

이 결과는 **개선 실험 우선순위를 정하는 근거**로 사용할 수 있다.

**Figure 05 — Worst segments Top10 (strict, w14/w30)**  
![Figure05a](figures/05_figure_a.png)
![Figure05b](figures/05_figure_b.png)

---

## 8) So What? (Product-thinking)

이 분석에서 얻을 수 있는 액션 힌트는 아래처럼 정리할 수 있다.

- **A0~A2(저 Activation) × C5(고 Consistency)**  
  - “초기 전환이 약해도 잠재력이 있는 유저”  
  - 단기 구매 유도보다 **리텐션/재방문 유지(리마인드, 탐색 경험 개선)** 가 더 합리적일 수 있음
- **Funnel 병목 대응**
  - 14일: `view → click` 마찰 완화(썸네일/리스트/추천/상세 진입 유도)
  - 30일: `click → add_to_cart` 마찰 완화(가격/혜택/배송/리뷰/장바구니 UX)

---

## 9) Reproducibility (SQL)

본 Story에서 사용한 핵심 쿼리는 아래에 있다.

- **Story core (used in this doc)**  
  `src/sql/analysis/00_story_core/`
  - `01_final_activation_x_consistency_ltv180d_retention_point.sql`
  - `01_activation_x_consistency_x_ltv_slim.sql`
  - `02_headline_lift_c5_vs_c1_by_activation.sql`
  - `02_bottleneck_frequency_reach_strict_w14_w30.sql`
  - `03_bottleneck_worst_segments_top10_strict_w14_w30.sql`

- **Supporting queries (full analysis set)**  
  `src/sql/analysis/01_supporting/`

---

## 10) Next Step (v1.1) — Time-split으로 “너무 뻔한 결과” 리스크 줄이기

v1.0에서는 Consistency/LTV/Retention이 같은 180일 윈도우에서 계산되기 때문에,  
결과가 “너무 잘 나오거나 뻔해 보이는” 인상을 줄 수 있다(해석상 leakage 우려).

이를 보완하기 위해 **Time-split Data Mart**를 추가로 설계했다.

- `DM_timesplit_60_180_final`
  - Observation: **0~60d** (Consistency 계산)
  - Outcome: **60~180d** (LTV/Retention 계산)

> 현재 repo에는 DM 생성 SQL까지 포함되어 있으며,  
> time-split 기반 추가 분석은 후속 작업(v1.1)으로 확장 가능하다.
