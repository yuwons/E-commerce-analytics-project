# [Story] Activation × Consistency → Future LTV/Retention (v1.0 → v1.1)

초기 Activation만으로는 180일 성과를 설명하기 어렵고, **Consistency**가 추가로 성과를 갈라낸다. 이를 **Time-split(0–60d → 60–180d)** 로 재검증했다.

---

## 0) Executive Summary

## 0.1 What we saw (v1.0)

- 유저를 Activation stage(A0-A5)로 나눈 뒤, 각 stage 내부에서 Consistency(C1-C5)로 다시 나누면 **C1 → C5로 갈수록 180일 구매율/매출이 뚜렷하게 상승**하는 패턴이 반복적으로 관찰된다.
- 특히 **낮은 Activation(A0-A2)** 구간에서 Consistency에 따른 성과 격차(lift)가 더 크게 나타난다. 즉, 초기 전환이 낮아 보여도 **리듬(Consistency)**이 안정적이면 장기 성과에서 회복/역전 가능성이 있다.
- 단, v1.0은 동일한 0-180일 창에서 “신호(Activation/Consistency)”와 “성과(구매/매출)”가 함께 움직일 수 있어(누수/tautology 가능성), 이후 v1.1에서 **관측창(0-60d) vs 성과창(60-180d) time-split**으로 재검증이 필요하다.


### 0.2 What we saw (v1.1)

- v1.0의 한계(동일 0–180d 창에서 predictor/outcome이 함께 움직일 수 있음)를 줄이기 위해, **관측창(0–60d)** 과 **성과창(60–180d)** 을 분리(Time-split)해 재검증했다.  
- Time-split 후에도 **초기 리듬(Consistency)** 이 이후 성과(60–180d 구매율/매출/리텐션)와 **단조롭게 연결되는 패턴이 유지**됐다.  
- 특히 **Activation 수준이 같아도**(Activation bucket 고정), Consistency가 높은 그룹이 **구매율/매출/리텐션이 더 높아** Consistency의 **추가 설명력**이 확인됐다.  
- 이를 바탕으로 Activation×Consistency 조합으로 만든 **Persona(예: Loyal/Steady/Burst/Observer)** 시:** (1) 14d `view→click` 전사 UX 개선 + (2) 30d `click→cart` 저일관성 세그먼트 대상 타깃 실험/개입으로 우선순위 분리.

### Figure 05 — Worst segments Top10 (strict w14/w30)
- Query: `src/sql/analysis/00_story_core/03_bottleneck_worst_segments_top10_strict_w14_w30.sql`

![](./figures/05_figure_a.png)
![](./figures/05_figure_b.png)

---

## 6) v1.1 — Time-split으로 “관측(0–60d) → 성과(60–180d)”를 분리해 재검증

v1.0 결과는 “Activation만으로는 부족하고 Consistency가 성과와 함께 움직인다”는 패턴을 보여줬다.  
다만 v1.0은 일부 지표가 **동기간(같은 0–180d 창)**에서 계산돼 상관(tautology) 우려가 남는다.

그래서 v1.1에서는 **관측(0–60d)**에서 early behavior/consistency를 정의하고,  
**성과(60–180d)**에서 purchase/revenue/retention을 측정해 같은 패턴이 유지되는지 확인한다.

---

## 6.1) Result 01 — Persona snapshot (Activation × Consistency)

- Query: `src/sql/analysis/story_core_v1.1/Persona_Analysis.sql`

![Persona snapshot (Activation × Consistency)](./figures_v1.1/persona_result.png)

Persona 간 성과가 뚜렷하게 갈린다.  
특히 **D_Loyal**은 60–180d 매출/구매율/리텐션이 모두 가장 높고, **B_Observer**는 전반적으로 낮다.

- 핵심: “초기 구매(Activation)만이 아니라, 이후 리듬/재방문 성향이 장기 성과를 좌우”하는 그림이 나온다.
- 활용: Tableau에서 persona별 KPI 카드/트렌드로 보여주기 좋다.

> **Note (limitation):** 이 결과는 synthetic 데이터 설정(시뮬레이션 가정)에 영향을 받으므로, **절대 수치보다 ‘방향성/프레임(해석 구조)’** 에 초점을 둔다.

---

## 6.2) Result 02 — Consistency (0–60d) → Outcomes (60–180d)

- Query: `src/sql/analysis/story_core_v1.1/04_timesplit__consistency_0_60_segment__outcomes_60_180.sql`

![Time-split: Consistency (0–60d) → Outcomes (60–180d)](./figures_v1.1/Consistency_outcome.png)

0–60d Consistency가 높아질수록(C1→C5) 60–180d 성과가 **단조 증가**한다.  
매출/구매율/리텐션이 모두 같은 방향으로 움직여, “Consistency가 미래 성과를 가른다”를 time-split으로 재확인한다.

- C1→C5로 갈수록 avg_revenue_60_180, purchase_rate_60_180, retention_last_week_180d_rate가 모두 상승
- 메시지: “초기 60일의 리듬(Consistency)은 이후 120일 성과를 예측/설명하는 신호다.”

> **Note (limitation):** time-split으로 동기간 상관은 줄였지만, 여전히 **생성 로직/가정에 의해 효과 크기(lift)가 커 보일 수 있어** 과도한 일반화는 피한다.

---

## 6.3) Result 03 — Activation × Consistency → Outcomes (time-split)

- Query: `src/sql/analysis/story_core_v1.1/05_activation14d_x_consistency0_60d_summary.sql`
  
![Time-split: Activation (0–14d) × Consistency (0–60d) → Outcomes (60–180d)](./figures_v1.1/Activation_x_consistency_outcome.png)

Activation 구간이 같아도, Consistency(C1→C5)에 따라 60–180d 성과가 크게 달라진다.  
즉, Activation만으로는 설명이 끝나지 않고 Consistency가 추가 설명력을 갖는다.

- 같은 activation_bucket_14d 안에서 C1→C5로 갈수록 purchase_rate_60_180 / avg_revenue_60_180 / retention이 상승
- 특히 Act_Low/Act_Mid에서도 C5가 의미 있게 높은 성과를 보이며 “초기 전환이 낮아도 리듬이 좋으면 회복 가능” 시그널이 나온다.

> **Note (limitation):** 본 프로젝트는 인과추론이 목적이 아니라 “분석 프레임/SQL+DM 설계 역량”을 보여주기 위한 synthetic 시뮬레이션이므로, **관계(패턴) 제시**를 핵심으로 한다.

---

## Appendix) Used Data Marts (v1.0)
- `ecommerce_dm.DM_user_window`
- `ecommerce_dm.DM_consistency_180d`
- `ecommerce_dm.DM_ltv_180d`
- `ecommerce_dm.DM_retention_cohort`
- `ecommerce_dm.DM_funnel_kpi_window`
- `ecommerce_dm.DM_funnel_session`

## Appendix) Used Data Marts (v1.1)
- `ecommerce_dm.DM_timesplit_60_180_final`
---
