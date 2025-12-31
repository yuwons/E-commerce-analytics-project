# E-commerce Analytics (Personal Project)

> 목표: **초기 Activation만으로는 장기 성과(LTV/Retention)를 충분히 설명하기 어렵다.**
> 초기 **방문 리듬(Consistency)** 이 이후 성과를 어떻게 분리하는지, **Time-split(관측/성과 창 분리)** 방식으로 검증한다.

- **Stack:** BigQuery (SQL) / Python (Pandas, NumPy) / Tableau / GitHub
- **Repo:** (GitHub 링크)

---

## 1) Project Objective (v1.0)

### One-liner
**Early activation is not enough — early visit-rhythm consistency predicts long-term value.**

### Core problem
- “180일 Consistency로 180일 LTV를 설명”하면 **동어반복(tautology)/누수(leakage)** 위험이 큼.
- 그래서 본 프로젝트는 **관측(Behavior feature)과 성과(Outcome) 기간을 분리**해 “예측형 분석”으로 전환.

### Method: Time-split evaluation
- **Observation window:** 가입 후 **0–60일**
  - Activation(14d) + Consistency(방문 리듬) 피처 계산
- **Performance window:** 가입 후 **60–180일**
  - Purchase rate / Orders / Revenue / (간단 Retention proxy) 등 outcome

### Hypotheses
- **H1:** 초기 14일 전환이 높아도 방문 리듬이 불규칙하면(예: inter-visit CV↑) 이후 60–180일 성과가 낮다.
- **H2:** 초기 전환이 느려도 방문 리듬이 안정적이면(active days/weeks↑, CV↓) 이후 60–180일 성과가 높다.
- **H3:** Consistency는 행동량(세션/이벤트 수)과 독립적으로 성과를 설명한다(통제 변수 고려).

---

## 2) Dataset (Synthetic) & Data Model

### Data type
- **Synthetic dataset** (Python으로 설계/생성, 재현 가능 seed 기반)

### Tables (Scope 기준)
- **Dimension**
  - `users`, `products`
- **Raw logs**
  - `sessions`, `events`  (5-step funnel: `view → click → add_to_cart → checkout → purchase`)
- **Transactions**
  - `orders`, `order_items`
- *(참고)* `promo_calendar`는 Raw에 존재할 수 있으나 **분석 스코프에서 제외**(비중 매우 작음).

### Integrity rules (Frozen specs)
- Funnel event는 **5단계 고정**: `view → click → add_to_cart → checkout → purchase`
- `order_id`는 **purchase 이벤트에서만 존재**
- **purchase 1건 = orders 1건** (정합성 유지)
- Raw 로그(`sessions/events`)는 그대로 보존하고, 파생 지표(리텐션/퍼널 KPI/Consistency 등)는 **BigQuery Data Mart에서 계산**

---

## 3) BigQuery Pipeline (Raw → Data Mart)

### BigQuery setup
- Project: `eternal-argon-479503-e8`
- Raw dataset: `ecommerce`
- DM dataset: `ecommerce_dm`
- Location: `US`

### Data Mart map (현재 구축 완료)
**User-level**
- `DM_user_window`
  - 유저 특성 + 14/30일 퍼널 reach 요약 + 180d 성과 요약(outcome용)
- `DM_consistency_180d`
  - 방문 리듬 지표(inter-visit mean/std/cv, weekly regularity 등)
- `DM_ltv_180d`
  - 180일 LTV(outcome) 집계
- ✅ `DM_timesplit_60_180_final` (핵심)
  - **0–60일:** activation + consistency features + consistency segment(C1~C5)
  - **60–180일:** purchase_rate / orders / revenue / retention proxy 등 outcome

**Session-level**
- `DM_funnel_session`
  - 세션 단위 funnel 재구성 (reach/strict 플래그 포함)

**Cohort-level**
- `DM_retention_cohort`
  - cohort_month × day_index(0..180) retention curve
- `DM_funnel_kpi_window`
  - window_days(14/30) × metric_type(reach/strict) 퍼널 KPI 요약

---

## 4) SQL Analysis (Completed)

> 목적: “추가 분석”이 아니라, **QA + 핵심 집계 결과 고정(재현 가능)** + Python으로 넘길 기반 테이블 준비

### SQL#1 — Activation stage distribution QA
- activation_stage_14d 분포 합이 전체 유저수로 정확히 일치(누락/중복 없음)

### SQL#2 — Activation × Consistency(0–60) → Outcome(60–180)
- 동일 activation 단계 내에서도 **Consistency segment(C1→C5)** 가 높아질수록
  - purchase_rate_60_180 / avg_orders / avg_revenue가 **단조 증가** 패턴

### SQL#3 — Funnel bottleneck summary (14d vs 30d)
- `window_days(14/30)` + `metric_type(reach/strict)` + `bottleneck_step` 결과 테이블 생성
- 다음 단계(Python)에서 **유저군 × 병목 step 교차 분석**으로 확장 예정

📁 SQL: `src/sql/analysis/`

---

## 5) Current Status
- ✅ Synthetic dataset 설계/생성
- ✅ BigQuery Raw 적재 + DM 구축(핵심 DM 포함)
- ✅ SQL 기반 QA 및 핵심 집계(Analysis #1~#3) 완료
- ⏳ Python 분석/시각화(다음 단계)
  - 행동 기반 유저군(A/B/C/D) 재현(라벨 누수 방지)
  - 유저군 × 병목 step 교차 분석
  - Time-split 결과 시각화 + mix effect(구매자 비중 vs 구매자당 매출) 분해

---

## 6) Out of Scope (v1.0)
- **Subscription 분석 제외**
- **Promo 효과 분석 제외** (희소성/비중이 매우 작아 해석 가치 낮음)

---

## 7) Next (Planned)
- Python notebook: feature validation / segmentation / visualization
- Tableau dashboard: KPI overview / cohort / funnel bottleneck / segment comparison

