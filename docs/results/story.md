# [Story] Activation × Consistency → Future LTV/Retention

## 0) 분석 핵심 요약 (TL;DR)

**한 줄 결론:** 단기 전환(Activation)만으로는 장기 성과를 충분히 설명하기 어려웠고,  
Time-split(0–60일 관측 → 60–180일 성과) 기준에서도 **방문 리듬(Consistency)** 이 이후 성과를 더 선명하게 분리했다.

### Key insights
- **Insight 1:** Consistency가 높을수록 60–180일 성과가 뚜렷하게 상승했다.  
  구매율은 **C1 4.9% → C5 46.7%**, 리텐션은 **25.7% → 76.7%**로 벌어졌다.
- **Insight 2:** 초기 구매가 없던 **C_Steady(14d 구매율 0.0%)**가 오히려 **A_Burst(69.1%)**보다  
  60–180일 구매율(**32.6% vs 13.8%**)과 평균매출(**88,489 vs 41,280**)이 더 높았다.  
  즉, 초기 반응이 더 좋아 보여도 이후 성과는 Consistency에 따라 달라질 수 있었다.
- **Insight 3:** 같은 Activation 수준 안에서도 Consistency 차이에 따라 장기 성과가 크게 갈렸다.  
  따라서 운영 단위는 Activation 단독보다 **Activation × Consistency persona**로 보는 편이 더 합리적이었다.

### Supporting validation
- Python 분포/추세/Bootstrap CI와 2×2 A/B 설계에서도,  
  **Consistency 축이 장기 KPI를 더 강하게 분리하는 방향성**이 반복 확인됐다.

### So what
- 장기 KPI 해석과 액션 설계는 Activation만이 아니라  
  **Activation × Consistency** 기준으로 보는 편이 더 적절하다.
- Funnel/action diagnostic은 main result와 같은 급의 검증 결과라기보다,  
  이를 바탕으로 한 **operational hypothesis**로 해석하는 것이 맞다.


## 1) Problem

초기 전환(Activation) 지표는 서비스 초반 성과를 빠르게 확인하는 데 유용하다.  
하지만 **초기 전환이 높다고 해서 장기 리텐션이나 장기 매출까지 자동으로 보장되지는 않는다.**  
실무에서는 비슷한 수준의 초기 반응을 보인 사용자라도, 이후 얼마나 **규칙적으로 다시 방문하는지**에 따라 장기 성과가 크게 달라질 수 있다.

이 프로젝트는 이 지점에 주목했다. 핵심 질문은 다음과 같다.  
**“초기 전환만으로 장기 성과를 설명할 수 있는가, 아니면 방문 리듬(Consistency)이 추가적인 설명력을 가지는가?”**

만약 Activation만 보고 사용자를 해석하면, 단기 성과가 좋아 보이는 세그먼트에 과도하게 집중하고, 반대로 **초기 전환은 낮더라도 장기 가치가 높은 사용자군**을 놓칠 수 있다.  
이 경우 액션도 전사 공통 개선에 머물고, 실제로는 **어떤 세그먼트를 먼저 개선해야 하는지**를 놓치게 된다.

그래서 본 프로젝트에서는 **Activation**, **Consistency**, **장기 성과(구매·리텐션·매출)** 를 분리해서 보았고,  
동기간 지표 해석의 한계를 줄이기 위해 **0–60일은 관측 구간, 60–180일은 성과 구간**으로 나누는 **Time-split 기준**을 적용했다.  
이를 통해 Consistency가 장기 성과를 설명하는 선행 신호로 해석될 수 있는지 재검증하고자 했다.

## 2) Key Definitions

### 2.1 Activation stage (첫 14일)
Activation은 가입 후 첫 14일 동안 사용자가 퍼널의 어느 단계까지 도달했는지를 기준으로 본 초기 전환 신호다.  
본 프로젝트에서는 14일 내 이벤트 발생 여부(reach)를 만든 뒤, 단계 우선순위에 따라 A0~A5로 라벨링했다.

- A0: no activity
- A1: view
- A2: click
- A3: add_to_cart
- A4: checkout
- A5: purchase

### 2.2 Consistency (관측 0–60일)
Consistency는 가입 후 관측 구간 동안 사용자가 얼마나 규칙적인 리듬으로 다시 방문했는지를 나타내는 지표다.  
세션 기반 지표를 바탕으로 score를 만들고, 이를 **C1(하위) ~ C5(상위)** 로 구간화했다.

### 2.3 Outcomes (성과 60–180일)
Outcomes는 가입 후 60–180일 구간에서 나타난 장기 성과를 의미한다.  
본 프로젝트에서는 구매율, 평균매출, 리텐션을 중심으로 비교했다.

## 3) Main Results — Time-split Validation

### 3.1 Result 01 — Persona snapshot (Activation × Consistency)

> Persona는 **Activation(초기 14d)** × **Consistency(0–60d 방문 리듬)** 조합으로 정의했다.  
> Legend(Activation): **A/D = early purchase(14d 구매 있음)**, **B/C = no early purchase(14d 구매 없음)**  
> Legend(Consistency): **Burst·Observer = low consistency**, **Steady·Loyal = high consistency**

**Key takeaway**
- Time-split(관측 0–60d → 성과 60–180d) 기준에서도 persona별 **매출·구매율·리텐션**이 뚜렷하게 갈렸다.
- 특히 **C_Steady(14d 구매율 0.0%)가 A_Burst(69.1%)보다도** 60–180d 구매율(**32.6% vs 13.8%**)과 평균매출(**88,489 vs 41,280**)이 높아, **Consistency가 장기 성과를 가르는 핵심 축**임을 보여준다.

**Evidence**
- **(Activation 통제: 14d 구매율 0.0% 내부 비교)** **B_Observer → C_Steady**
  - 구매율(60–180d): **17.0% → 32.6% (+15.6%p)**
  - 평균매출(60–180d): **41,882 → 88,489 (2.1×)**
  - 리텐션(마지막 주): **41.3% → 59.3% (+18.0%p)**
- **(Early purchase가 높아도 Consistency에 따라 장기 성과가 갈림)** **A_Burst(69.1%) vs D_Loyal(67.7%)**
  - 구매율(60–180d): **13.8% vs 34.3% (+20.5%p)**
  - 평균매출(60–180d): **41,280 vs 104,139 (2.5×)**
  - 리텐션(마지막 주): **54.3% vs 75.0% (+20.7%p)**
- **Persona 분포(샘플 비중):**
  - **B_Observer:** 50.9% (n=15,280)
  - **C_Steady:** 37.2% (n=11,171)
  - **A_Burst:** 6.0% (n=1,808)
  - **D_Loyal:** 5.8% (n=1,741)

**So what**
- 초기 구매 여부(Activation)만으로 장기 성과를 판단하면 놓치는 그룹이 생긴다.
- 따라서 KPI 해석과 액션 설계는 Activation뿐 아니라 **재방문 리듬(Consistency)** 까지 포함한 **persona 단위**로 보는 편이 더 합리적이다.

**Figure**
- `persona_result.png` — Persona snapshot (Activation × Consistency)

**Query**
- `src/sql/analysis/story_core_v1.1/Persona_Analysis.sql`

> **Note (limitation):** synthetic 생성 가정/노이즈로 인해 persona의 **절대 순위**는 달라질 수 있다.  
> 본 결과는 **Activation vs Consistency의 역할 분리(프레임)** 가 time-split에서도 재현되는지에 초점을 둔다.

### 3.2 Result 02 — Consistency → Outcomes

**Key takeaway**
- Time-split(관측 0–60d → 성과 60–180d) 기준에서도, **Consistency가 높을수록 장기 구매율·매출·리텐션이 함께 상승**했다.
- 즉, 초기 60일의 방문 리듬은 이후 60–180일 성과를 설명하는 **핵심 선행 신호**로 해석할 수 있다.

**Evidence**
- 구매율(60–180d): **C1 4.9% → C5 46.7% (+41.8%p)**
- 평균매출(60–180d): **10,247 → 142,561 (13.9×)**
- 리텐션(마지막 주, day 174–180): **25.7% → 76.7% (+51.0%p)**

**So what**
- 장기 성과를 해석할 때는 Activation만 볼 것이 아니라, **Consistency를 별도의 핵심 축으로 함께 봐야 한다.**
- 이후 액션 설계에서도 “초기 반응이 있었는가”뿐 아니라, **그 사용자가 얼마나 규칙적으로 다시 돌아오는가**를 함께 반영해야 한다.
- 다음 결과에서는 이를 한 단계 더 나아가, **같은 Activation 수준 안에서도 Consistency 차이가 장기 성과를 가르는지**를 확인한다.

**Figure**
- `Consistency_outcome.png` — Time-split: Consistency (0–60d) → Outcomes (60–180d)

**Query**
- `src/sql/analysis/story_core_v1.1/04_timesplit__consistency_0_60_segment__outcomes_60_180.sql`

> **Note (limitation):** synthetic 생성 가정에 따라 효과 크기(lift)는 과장될 수 있다.  
> 본 결과는 인과 주장이라기보다 **방향성과 분석 프레임 검증**에 초점을 둔다.

### 3.3 Result 03 — Activation × Consistency → Outcomes

**Key takeaway**
- Time-split(관측 0–60d → 성과 60–180d)에서도 **같은 Activation 수준 안에서 Consistency(C1→C5)에 따라 장기 성과가 크게 갈렸다.**
- 즉, 초기 전환만으로는 장기 가치를 충분히 설명할 수 없었고, **같은 출발선 안에서도 방문 리듬 차이가 이후 성과를 갈랐다.**

**Evidence**
- **Act_Low (A0–A1)** 내부 비교
  - 구매율(60–180d): **1.6% → 42.6% (+41.0%p)**
  - 리텐션(마지막 주): **20.2% → 68.8% (+48.6%p)**
  - (C1→C5)
- **Act_High (A4–A5)** 내부 비교
  - 구매율(60–180d): **6.8% → 41.8% (+35.0%p)**
  - 리텐션(마지막 주): **41.4% → 82.9% (+41.5%p)**
  - (C1→C5)
- 동일 Activation bucket 내부에서도 **Consistency가 높아질수록 구매율·리텐션이 단조 상승**했다.

**So what**
- Activation만으로 타깃팅하면 **초기 전환은 낮지만 리듬이 좋은 high-consistency 유저**를 과소평가할 수 있다.
- 따라서 운영/개입 단위는 Activation 단독이 아니라 **Activation × Consistency persona**로 보는 편이 더 합리적이다.

**Figure**
- `Activation_x_consistency_outcome.png` — Activation (0–14d) × Consistency (0–60d) → Outcomes (60–180d)

**Query**
- `src/sql/analysis/story_core_v1.1/05_activation14d_x_consistency0_60d_summary.sql`

> **Note (limitation):** synthetic 데이터 특성상 효과 크기(lift)는 가정에 좌우될 수 있다.  
> 본 결과는 인과추정보다 **관계/프레임 검증**에 초점을 둔다.

## 4) Python Validation

SQL 기반 time-split 결과를 Python에서 다시 확인해,  
**분포·추세·불확실성 관점에서도 동일한 방향성이 유지되는지** 점검했다.

### 4.1 Validation focus
- **Retention trend:** Consistency(C1–C5)와 장기 리텐션의 단조 관계가 유지되는지 확인
- **Revenue distribution:** 평균 왜곡(outlier) 가능성을 줄이고, 분포/중앙값 기준에서도 동일 패턴이 보이는지 확인
- **Bootstrap CI:** 핵심 차이(C5 − C1)가 표본 변동성을 고려해도 일관적인지 확인

### 4.2 Key takeaway
- Python 시각화와 bootstrap CI에서도, **Consistency가 높을수록 장기 성과가 우상향하는 패턴**이 동일하게 재현됐다.
- 즉, SQL 집계 결과는 단순 평균치만의 산물이 아니라, **분포와 불확실성을 함께 보더라도 유지되는 방향성**으로 해석할 수 있다.

### 4.3 Evidence

#### (1) Retention trend (day 174–180)
> **Purpose:** Consistency(C1–C5)와 장기 리텐션의 단조 관계를 Python에서 재확인한다.  
> **Result:** **C1→C5 리텐션 우상향 패턴이 동일하게 재현**된다.

![](<figures(python)/fig_line_retention_174_180_by_consistency_segment_v1_1.png>)

#### (2) Revenue distribution (buyers-only, log1p revenue)
> **Purpose:** 평균 왜곡(outlier) 가능성을 줄이기 위해 구매자만 대상으로 `log1p(revenue_60_180)` 분포를 세그먼트별로 비교한다.  
> **Result:** 중앙값/분포에서도 **C1→C5 우상향 경향이 유지**되어 평균 기반 결론을 보강한다.

![](<figures(python)/fig_violin_log1p_revenue_60_180_buyers_only_by_consistency_segment_v1_1.png>)

#### (3) Bootstrap CI — C5 minus C1 (purchase_rate_60_180)
> **Purpose:** C5와 C1의 구매율 차이를 bootstrap으로 추정해 95% CI로 불확실성을 함께 제시한다.  
> **Result:** 구매율 차이(**+41.8%p**)가 **95% CI에서도 일관**하게 나타나 방향성 결론을 보강한다.

![](<figures(python)/fig_bootstrap_ci_c5_minus_c1_purchase_rate_60_180_v1_1.png>)

### 4.4 So what
- SQL 결과에서 확인한 **Consistency → 장기 성과** 패턴은, Python 기준으로도 **추세·분포·불확실성** 관점에서 같은 방향으로 확인됐다.
- 따라서 본 프로젝트의 핵심 해석은 단순 집계치 하나에 의존한 결론이 아니라,  
  **여러 관점에서 반복 확인된 방향성**으로 볼 수 있다.

**Notebook**
- `src/python/Python (EDA + Visualisation).ipynb`

**Figures**
- `docs/results/figures(python)/`

> **Note:** synthetic 데이터 기반이므로 절대 수치 자체보다,  
> **Consistency가 장기 성과를 반복적으로 분리하는 구조가 유지되는지**에 초점을 두고 해석했다.

## 5) A/B Test — Supporting validation & intervention thinking

관찰 데이터 기반 분석만으로는, Consistency가 장기 성과와 함께 움직인다는 패턴은 확인할 수 있어도  
**어떤 개입이 실제로 더 효과적인지**까지 직접 판단하기는 어렵다.  
그래서 본 프로젝트에서는 Activation과 Consistency를 각각 개입 축으로 두고,  
**2×2 factorial A/B test** 형태로 실험 설계를 추가했다.

### 5.1 Why this was added
- 관찰 결과만으로는 **Consistency가 장기 성과의 선행 신호인지**, 혹은 단순 동반 지표인지 완전히 분리하기 어렵다.
- 따라서 “초기 전환을 더 올리는 개입”과 “방문 리듬을 더 안정화하는 개입”을 분리해서 보려 했다.
- 이를 통해 **Activation uplift**와 **Consistency uplift**가 각각 어떤 KPI에 더 가까운 영향을 주는지 비교하고자 했다.

### 5.2 Experiment design
- **Design:** 2×2 factorial A/B
- **Factor 1:** Activation uplift
- **Factor 2:** Consistency uplift
- **Goal:** 각 축의 main effect와 interaction을 분리해서 확인

### 5.3 Metrics
- **Primary:** 60–180d revenue (LTV proxy)
- **Secondary:** purchase rate, retention
- **Short-term check:** 0–13d early conversion
- **Method:** bootstrap CI

### 5.4 Headline result
- **Consistency uplift**는 장기 KPI(60–180d revenue / retention) 개선 쪽에서 더 의미 있는 신호를 보였다.
- 반면 **Activation uplift**는 초기 전환(0–13d) 개선에 더 가까운 패턴을 보였다.
- 두 개입의 **interaction은 0을 포함**해, 결합 효과는 보수적으로 해석했다.

### 5.5 So what
- Activation 개선은 초반 반응을 빠르게 올리는 데 유리하지만,  
  장기 가치 관점에서는 **Consistency를 높이는 개입이 더 중요한 레버**일 가능성을 시사한다.
- 따라서 실제 서비스에서는 Activation KPI만 빠르게 올리는 실험보다,  
  **재방문 리듬을 안정화하는 개입을 별도 축으로 설계**하는 것이 더 유의미할 수 있다.

**Notebook**
- `src/python/Python_(AB Experiment).ipynb`


## 6) Action Implications

> **Note:** 아래 액션 제안은 v1.1 time-split main result를 바탕으로 한 해석에,  
> **v1.0의 14d/30d funnel diagnostic**을 운영 관점에서 결합해 정리한 operational hypothesis다.

핵심 결과를 종합하면, 퍼널 개선은 하나의 공통 액션으로 해결되기보다  
**전사 공통 마찰**과 **세그먼트별 취약 마찰**을 나눠서 접근하는 편이 더 합리적이다.

### 6.1 전사 개선: view→click

**Key takeaway**
- 초기 14일 기준 funnel diagnostic에서는 **view→click 구간의 마찰이 전사적으로 넓게 나타났다.**
- 즉, 특정 세그먼트만의 문제가 아니라 여러 사용자군에서 공통적으로 **초기 클릭 유도 단계**가 약한 구간으로 해석할 수 있다.

**Evidence**
- 14일 Worst Top10 bottleneck 기준에서 **view→click** 이 가장 넓게 반복적으로 관찰됐다.
- 이는 상품을 보더라도 다음 행동(click)으로 넘어가지 못하는 사용자가 전반적으로 많다는 뜻이다.

**Recommended actions**
- 상품 진입 직후 핵심 혜택/가치 제안을 더 빨리 보이게 하는 **정보 구조 실험**
- 클릭 유도 CTA의 위치/문구/가시성을 바꾸는 **UI A/B 테스트**
- 첫 탐색 흐름에서 불필요한 선택지를 줄여 **초기 탐색 마찰을 낮추는 UX 개선**

**So what**
- 이 구간은 특정 persona만 타깃팅하기보다, **전사 공통 UX 개선 과제**로 다루는 편이 적절하다.
- 즉, 초기 퍼널에서는 **“더 많은 사용자가 다음 행동으로 넘어가게 만드는 것”** 이 우선 과제다.

### 6.2 세그먼트 타깃 개선: A2_click × low-consistency click→cart

**Key takeaway**
- 30일 기준 funnel diagnostic에서는 **click→cart 구간의 취약성이 특히 A2_click × low-consistency(C1/C2) 조합에서 두드러졌다.**
- 즉, 전체 사용자 공통 문제라기보다 **특정 세그먼트 조합에서 장바구니 진입 마찰이 더 크게 나타난다**는 신호로 해석할 수 있다.

**Evidence**
- 30일 Worst Top10 bottleneck 기준에서 **click→cart** 이 low-consistency 구간에 상대적으로 더 집중됐다.
- 특히 상품 클릭까지는 도달했지만 장바구니 진입으로 이어지지 못하는 사용자가 **A2_click × low-consistency(C1/C2)** 조합에서 두드러졌다.
- 이는 “관심은 보였지만 행동 리듬이 약한 사용자”에게서 cart 진입 마찰이 더 크게 작동할 가능성을 시사한다.

**Recommended actions**
- 최근 본 상품 재노출 / 장바구니 CTA 강조 / 옵션 선택 단계 단순화 같은 **세그먼트 타깃 UX 실험**
- 이탈 직후 다시 돌아오게 만드는 **리마인드 메시지 / CRM A/B 테스트**
- `A2_click × low-consistency` 유저를 대상으로 **click→cart 전환 전용 실험군**을 따로 구성해 개입 효과 측정

**So what**
- 이 구간은 전사 공통 개선보다 **세그먼트 타깃 실험**이 더 적합하다.
- 즉, 퍼널 액션은 하나로 묶기보다  
  **초기 클릭(view→click)은 전사 개선**,  
  **장바구니 진입(click→cart)은 특정 세그먼트 타깃 개선**으로 역할을 나누는 편이 더 실무적이다.


## 7) Limitations

### 7.1 Interpretation boundary

본 프로젝트는 **synthetic e-commerce dataset** 기반 분석이므로,  
구매율·리텐션·매출의 **절대 수치 자체**를 실제 서비스로 바로 일반화하기는 어렵다.  
따라서 핵심 해석은 특정 수치의 정확성보다,  
**Activation과 Consistency를 분리해 장기 성과를 해석하는 프레임**에 있다.

### 7.2 Main result vs action evidence

본 문서의 **main result**는 v1.1 Time-split 기준에서  
Consistency가 장기 구매율·리텐션·매출을 더 강하게 분리했다는 점이다.

반면 funnel/action 파트는  
v1.0의 14d/30d diagnostic을 운영 관점에서 확장한 **action hypothesis**에 가깝다.  
즉, main result와 action evidence는 **같은 레벨의 검증 결과가 아니라 역할이 다르다.**

### 7.3 What remains valuable

이 한계에도 불구하고, 본 프로젝트는 다음과 같은 점에서 의미가 있다.

- Activation만으로는 장기 가치를 충분히 설명하기 어렵다는 문제를 구조화했다.
- Consistency를 별도 축으로 정의하고, Time-split과 Python validation으로 반복 확인했다.
- 분석 결과를 persona 해석, 실험 설계, 액션 방향까지 연결하는 end-to-end 흐름을 설계했다.
- Activation × Consistency 프레임은 이번 분석의 결론에 그치지 않고,  
  이후 퍼널·리텐션·실험 설계에서도 **어떤 사용자군을 더 세분화해 봐야 하는지**를 판단하는 기준점으로 기능한다.

즉, 본 프로젝트는 **실제 서비스 로그의 정답을 재현한 작업**이라기보다,  
**실서비스 환경에도 확장 가능한 사용자 해석 프레임과 세그먼트 발굴 구조**를 보여주는 분석 설계 사례로 보는 것이 적절하다.


## 8) Method Refinement

이 프로젝트는 처음부터 time-split 구조로 시작한 것이 아니라,  
**v1.0에서 핵심 패턴을 먼저 관찰하고, 이후 v1.1에서 더 엄격한 기준으로 재검증하는 방식**으로 발전했다.

### 8.1 Why time-split was added

v1.0에서는 0–180일 구간에서 Activation, Consistency, 장기 성과 사이의 핵심 패턴을 먼저 확인했다.  
이 단계에서 얻은 인사이트는 분명했다.

- Activation만으로는 장기 가치를 충분히 설명하기 어렵다.
- 같은 Activation stage 안에서도 Consistency에 따라 장기 성과가 크게 갈린다.
- 따라서 사용자 해석과 액션 설계는 Activation 단독이 아니라  
  **Activation × Consistency** 프레임으로 보는 편이 더 유용하다.

다만 v1.0의 일부 지표는 동일한 0–180일 구간 안에서 함께 계산되었기 때문에,  
패턴은 유의미했지만 해석을 더 엄격하게 만들 필요가 있었다.  
그래서 v1.1에서는 **0–60일은 관측, 60–180일은 성과**로 나누는 Time-split 기준을 도입했다.

### 8.2 Exploratory baseline (v1.0)

v1.0은 본 프로젝트의 최종 결론이라기보다,  
**어떤 패턴을 먼저 포착했고 어떤 질문을 더 엄격하게 검증해야 하는지 보여준 exploratory baseline**에 가깝다.

이 단계에서 확인한 핵심은 다음과 같다.

- Activation만으로는 장기 성과를 충분히 설명하기 어렵다는 패턴이 보였다.
- 같은 Activation stage 안에서도 Consistency에 따라 180일 성과 차이가 크게 나타났다.
- Funnel diagnostic에서는 전사 공통 병목과 세그먼트 취약 병목이 구분되어 보였다.

즉, v1.0은  
**“Activation만으로는 부족하고, Consistency를 함께 봐야 한다”**는 방향성을 먼저 보여준 단계였고,  
v1.1은 이 방향성이 더 엄격한 시간 분리 기준에서도 유지되는지를 확인한 단계였다.

### 8.3 v1.0 figures and queries

아래 Figure 01–05는 v1.0 exploratory analysis에서 사용한 결과물이다.  
이 결과들은 프로젝트의 초기 문제의식을 형성하고,  
이후 v1.1 time-split 재검증으로 이어지는 출발점 역할을 했다.

- **Figure 01** — Activation × Consistency × (Purchase / Revenue / Retention)  
  - Query: `src/sql/analysis/00_story_core/01_final_activation_x_consistency_ltv180d_retention_point.sql`

- **Figure 02** — Headline lift (C5 vs C1) by Activation  
  - Query: `src/sql/analysis/00_story_core/02_headline_lift_c5_vs_c1_by_activation.sql`

- **Figure 04** — Bottleneck frequency (strict, 14d vs 30d)  
  - Query: `src/sql/analysis/00_story_core/02_bottleneck_frequency_reach_strict_w14_w30.sql`

- **Figure 05** — Worst segments Top10 (strict, 14d vs 30d)  
  - Query: `src/sql/analysis/00_story_core/03_bottleneck_worst_segments_top10_strict_w14_w30.sql`

> **Interpretation note:** v1.0 결과는 exploratory baseline으로 해석해야 하며,  
> 본 문서의 main result는 **v1.1 Time-split validation** 기준으로 이해하는 것이 적절하다.
