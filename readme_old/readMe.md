# E-commerce Analytics Project (v1.0)
**Activation × Consistency → Future LTV/Retention (Time-split)**

> **핵심 메시지:** 초기 14일 Activation만으로는 장기 성과를 충분히 설명하기 어렵고,  
> **방문 리듬(Consistency)** 이 특히 저-Activation 유저의 미래 가치(LTV/Retention)를 강하게 가른다.

---

## 0) Current Status (Done vs Planned)
-  **Done:** Synthetic data 생성 → BigQuery Raw 적재 → Data Marts(7개, Time-split 포함) 구축 → SQL QA 스냅샷
-  **Planned:** Python 분석(라벨 재현/믹스이펙트/병목 교차) → 시각화(Tableau) → 자동화(Airflow)

---

## 1) 프로젝트 목표 (Project Objective)

### 1.1 한 줄 요약
유저 행동 패턴의 차이가 **단기 전환(14일 내 첫 구매)** 과 **장기 가치(60–180일 성과)** 사이의 trade-off를 어떻게 만드는가?

### 1.2 배경 (Why this matters)
많은 e-commerce 분석은 “초기 전환이 높으면 장기 매출도 높다”에서 출발하지만,
실제로는 **초반에 빠르게 구매하고 이탈하는 유저**와 **초반은 느리지만 꾸준히 돌아와 장기 가치가 커지는 유저**가 공존한다.  
이 프로젝트는 그 차이가 행동량(volume)만이 아니라 **행동의 구조(리듬/일관성 = Consistency)** 에서 올 수 있다는 관점에서 시작했다.

### 1.3 KPI / Window 고정
- **Short-term conversion (메인):** signup 후 **14일 내 첫 구매**
- (보조) **30일 내 첫 구매**
- **Observation window (features):** signup 후 **day 0–59 (총 60일)**  
- **Performance window (outcomes):** signup 후 **day 60–179 (총 120일)**

> 표기 원칙: 본 프로젝트의 윈도우는 “포함/미포함”을 명확히 하기 위해 반개구간(day index)로 표기한다.

### 1.4 가설 Hypotheses (H1–H3)
- **H1:** 초기 14일 전환이 높아도 방문 리듬이 불규칙(inter-visit CV↑)이면 이후(60–180) 성과가 낮다.
- **H2:** 초기 전환이 느려도 방문 리듬이 안정적(active days/weeks↑, CV↓)이면 이후(60–180) 성과가 높다.
- **H3:** Consistency는 행동량(세션/이벤트 수)과 독립적인 설명력을 가진다(통제 포함).

### 1.5 방법론 업그레이드 (Leakage/Tautology 방지 → Time-split)
초기 접근(naive)에서는 **동일 기간(0–180) 내 행동(Consistency)** 으로 **동일 기간(0–180) 성과(LTV/Retention)** 를 설명하는 구조가 가능하지만,  
이는 “오래 남아 자주 온 사람이 더 산다”라는 **자기증명(tautology) / 누수(leakage)** 로 해석될 위험이 있다.

따라서 v1.0에서는 **관측창(0–60)과 성과창(60–180)을 분리(Time-split)** 하여,
주장을 “장기 꾸준함 → 장기 매출”이 아니라  
“**초기 60일 리듬이 안정적인 유저는 이후 120일 성과가 더 높다**”로 강화한다.

---

## 2) 데이터 모델 (ERD)

### 2.1 Tables (v1.0 분석 스코프)
Synthetic dataset으로 “분석 가능한 문제”를 만들기 위해 현실적인 e-commerce 스키마를 구성했다.

- **Dimension**
  - `users`
  - `products`
- **Raw logs**
  - `sessions` (session-level)
  - `events` (event-level, funnel 5-step)
- **Transaction**
  - `orders` (purchase 이벤트에서 파생)
  - `order_items`

> `user_type(A/B/C/D)` 같은 라벨은 Raw/DM에 존재할 수 있으나, v1.0 분석에서는 직접 사용하지 않는다(누수 방지).  
>  **Planned:** Python에서 행동 기반으로 A/B/C/D를 재현하고, raw `user_type`은 검증용으로만 비교한다.

### 2.2 Integrity Rules (Frozen Specs)
- Funnel 이벤트는 **5단계 고정**: `view → click → add_to_cart → checkout → purchase`
- `order_id`는 **purchase 이벤트에서만 존재**
- **purchase 이벤트 1건 = orders 1건**
- Raw 로그(`sessions/events`)는 원형을 유지하고, 파생 지표는 **BigQuery Data Mart(SQL)** 에서 계산

### 2.3 ERD
> TODO: ERD 이미지 파일명 확정 후 링크 연결  
- `docs/results/figures/` 안에 ERD 이미지를 두고 README에서 참조

---

## 3) Synthetic Dataset Generation (Python)

이 프로젝트는 Python으로 **재현 가능한(same seed)** synthetic dataset을 생성한다.

### 3.1 Generation Principles
- Raw 로그 보존 + DM에서 파생지표 계산
- Funnel 5-step 고정 + order_id 정합성 유지

### 3.2 Dataset Scale (current build, approx.)
- users ≈ **30,000**
- sessions ≈ **0.7–0.8M**
- events ≈ **~1.8M**
- orders ≈ **~15K**
- products = **300**

### 3.3 Reproducibility (생성 재현성)
- random seed 고정
- 생성 후 PK/Join 정합성 + row count sanity check 수행 후 BigQuery 적재

📁 `src/data_generation/`
```text
src/data_generation/
├── generate_users.py
├── generate_products.py
├── generate_orders.py
├── generate_order_items.py
└── generate_events.py
