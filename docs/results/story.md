# [Story] Activation × Consistency → Future LTV/Retention (v1.0 → v1.1)

> **핵심 메시지**  
> 초기 14일의 Activation(퍼널 도달)만으로는 유저의 180일 성과를 “완전히” 설명하기 어렵고,  
> 같은 Activation 안에서도 **방문 리듬(Consistency)**에 따라 **장기 구매/매출/리텐션이 꽤 다르게 나타난다.**  
>  
> 다만 v1.0은 predictor와 outcome을 같은 0~180일 창에서 본 한계가 있어,  
> 다음 단계(v1.1)에서는 **관측창(0~60d) / 성과창(60~180d) 분리(Time-split)**로 더 안전하게 검증한다.

---

## 0) Executive Summary

### 0.1 What we saw (v1.0)
- 유저를 **Activation stage(A0-A5)**로 나눈 뒤, 각 stage 내부에서 **Consistency(C1-C5)**로 다시 나누면  
  **C1 → C5로 갈수록 180일 구매율/매출이 뚜렷하게 상승**하는 패턴이 반복적으로 관찰된다.
- 특히 **낮은 Activation(A0~A2)** 구간에서 **Consistency에 따른 성과 격차(lift)가 더 크게** 나타나는 경향이 있었다.
- 퍼널 관점에서는 **구간별 병목이 “어디서 자주 발생하는지(빈도)”**와  
  **“어떤 세그먼트가 특히 약한지(최약 세그먼트)”**를 분리해 보면,  
  개선 포인트를 더 구체적으로 잡을 수 있다.

### 0.2 What we do next (v1.1)
- v1.0 결과를 "힌트"로 삼되, 해석을 더 안전하게 만들기 위해  
  **Time-split(0~60d -> 60~180d)** 기반 DM(`DM_timesplit_60_180_final`)로 재현/검증한다.
- 추가로, device/region/marketing_source 등 **통제 변수를 포함한 모델링(예: 회귀/로지스틱)**으로  
  “Consistency의 독립적 설명력”도 확인한다.

---

## 1) Definitions (v1.0 기준)

### 1.1 Activation stage (첫 14일)
- A0: no activity  
- A1: view  
- A2: click  
- A3: add_to_cart  
- A4: checkout  
- A5: purchase

> 사용 DM: `DM_user_window` (has_view_14d ~ has_purchase_14d)

### 1.2 Consistency (0~180일, v1.0)
- 세션 기반 지표(예: active_days, intervisit_cv 등)로 Consistency score를 만들고,
- score를 **퀸타일로 C1(하위) - C5(상위)**로 구간화

> 사용 DM: `DM_consistency_180d`

### 1.3 Long-term outcomes (0~180일, v1.0)
- 구매/매출: `DM_ltv_180d`
- 리텐션: `DM_retention_cohort` (day 180 정의 포함)

---

## 2) Finding #1 — Activation만으로는 부족하고, 같은 Activation 안에서도 Consistency 차이가 크게 보인다 (v1.0)

Activation stage가 높을수록 평균적으로 성과가 좋아지는 건 자연스러운 흐름이지만,  
**같은 Activation stage 내부에서도 Consistency(C1~C5)에 따라 180일 성과가 꽤 다르게 나타났다.**

- “초기 퍼널 도달”은 분명 중요한 신호지만,
- 그 이후 **얼마나 규칙적으로 다시 방문/활동했는지(Consistency)**가 함께 보일 때  
  유저의 180일 성과를 더 입체적으로 설명할 수 있었다.

### Figure 01 — Activation × Consistency × (LTV / Retention)
- Query: `src/sql/analysis/00_story_core/01_final_activation_x_consistency_ltv180d_retention_point.sql`

![](./figures/01_figure_a.png)
![](./figures/01_figure_b.png)

### Figure 03 — Activation × Consistency × LTV (slim)
- Query: `src/sql/analysis/00_story_core/01_activation_x_consistency_x_ltv_slim.sql`

![](./figures/03_figure_a.png)
![](./figures/03_figure_b.png)

> **주의(해석 한계, v1.0):**  
> Consistency 지표와 180일 성과가 같은 기간(0~180d) 안에서 같이 계산되기 때문에,  
> “예측”이라기보다 “동기간 상관 패턴”이 강하게 섞여 있을 수 있다.  
> 그래서 다음 단계(v1.1)에서 Time-split으로 분리 검증한다.

---

## 3) Finding #2 — Consistency의 격차는 낮은 Activation 구간에서 더 크게 보이는 편이다 (v1.0)

C5(상위 Consistency)와 C1(하위 Consistency)을 비교했을 때,  
Activation stage별로 성과 격차(lift)가 동일하게 나타나진 않았다.

정리하면:

- 높은 Activation(A4~A5)에서도 Consistency 차이는 보이지만,
- **낮은 Activation(A0~A2)에서 C1 ↔ C5 격차가 더 크게 관찰되는 경향**이 있었다.

이 말은 “초기 전환이 낮아 보이는 유저” 안에서도  
**방문 리듬이 안정적인 그룹이 이후 성과에서 더 나은 흐름을 보일 수 있다**는 정도로 해석할 수 있다.  
(단, v1.0에서는 동기간 지표 한계가 있으니, v1.1에서 분리 검증 예정)

### Figure 02 — Headline lift (C5 vs C1) by Activation
- Query: `src/sql/analysis/00_story_core/02_headline_lift_c5_vs_c1_by_activation.sql`

![](./figures/02_figure.png)

---

## 4) Finding #3 — 퍼널 병목은 “어디서 자주 막히는지”와 “어느 세그먼트가 특히 약한지”를 나눠보면 더 명확하다 (v1.0)

퍼널 분석을 할 때, 단순히 “전환율이 낮다”에서 끝내면 액션으로 이어지기 어렵다.  
그래서 v1.0에서는 두 가지 관점으로 나눠 봤다.

- **(A) 빈도 관점:** 병목이 “자주 발생하는 구간”은 어디인가?  
- **(B) 세그먼트 관점:** “특히 약한 세그먼트”는 어떤 조합인가?

### Figure 04 — Bottleneck frequency (reach-based, strict w14/w30)
- Query: `src/sql/analysis/00_story_core/02_bottleneck_frequency_reach_strict_w14_w30.sql`

![](./figures/04_figure_a.png)
![](./figures/04_figure_b.png)

---

## 5) Finding #4 — 최약 세그먼트 Top10을 보면 “개선 우선순위”가 더 구체적으로 잡힌다 (v1.0)

“전체 평균”만 보면 병목이 흐릿해질 때가 많다.  
그래서 v1.0에서는 조건을 엄격하게 둔 뒤(w14/w30 strict),  
**가장 성과가 낮은 세그먼트 Top10**을 뽑아 “어떤 조합이 특히 약한지”를 확인했다.

이 방식의 장점은,
- “어디를 고쳐야 효과가 큰지”를 더 빠르게 좁힐 수 있고,
- 실무적으로는 캠페인/UX/추천/리마인드 같은 액션을 **세그먼트 단위로 설계**하기 쉬워진다는 점이다.

### Figure 05 — Worst segments Top10 (strict w14/w30)
- Query: `src/sql/analysis/00_story_core/03_bottleneck_worst_segments_top10_strict_w14_w30.sql`

![](./figures/05_figure_a.png)
![](./figures/05_figure_b.png)

---

## 6) Next Step — Time-split으로 “관측(0~60d) → 성과(60~180d)”를 분리해 다시 본다 (v1.1)

v1.0에서 보인 패턴(Activation만으로 부족, Consistency가 성과와 같이 움직임)을  
좀 더 안전하게 확인하기 위해, v1.1에서는 시간축을 분리한다.

- 관측창(0~60d): early behavior / consistency
- 성과창(60~180d): purchase, revenue, retention

### Planned DM (v1.1)
- `ecommerce_dm.DM_timesplit_60_180_final`
  - predictors: obs_0_60d
  - outcomes: perf_60_180d (purchase/revenue) + retention_last_week_180d

> **목표:**  
> “동기간 상관” 가능성을 줄이고,  
> 초반 리듬(Consistency)이 이후 성과(60~180d)와도 연결되는지 확인한다.

---

## Appendix) Used Data Marts (v1.0)
- `ecommerce_dm.DM_user_window`
- `ecommerce_dm.DM_consistency_180d`
- `ecommerce_dm.DM_ltv_180d`
- `ecommerce_dm.DM_retention_cohort`
- `ecommerce_dm.DM_funnel_kpi_window`
- `ecommerce_dm.DM_funnel_session`

---
