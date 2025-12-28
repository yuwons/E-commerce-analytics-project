# [Analysis Report] Activation × Consistency: 고가치 유저 선행 지표 발굴 (v1.0)

> **핵심 요약**: 초기 14일의 전환(Activation)은 유저의 시작일 뿐입니다. 본 분석은 **'재방문 리듬(Consistency)'**이 장기 LTV와 리텐션을 결정짓는 실질적인 변수임을 증명하며, 분석의 논리적 한계를 스스로 비판하고 고도화 방향(Time-split)을 제시합니다.

---

## 0. Executive Summary
- **문제 제기**: 초기 14일의 액션만으로 유저를 판단하는 것은 '성급한 일반화'의 오류를 범할 수 있음.
- **가설**: 낮은 단계의 Activation 유저라도 방문 리듬이 일정하다면, 장기적으로 고관여 유저(A4-A5) 수준의 가치를 창출할 것이다.
- **분석 범위**: v1.0에서는 핵심 서비스 가치 검증을 위해 Subscription 및 소수 비중의 Promo 분석은 제외함.

---

## 1. Metric Definition
### 1.1 Activation Stage (Window: 0~14d)
가입 후 14일 내 도달한 최종 퍼널 단계에 따라 유저를 6단계(`A0`~`A5`)로 정의합니다.

### 1.2 Consistency Segment (Window: 0~180d)
세션 로그 기반의 방문 빈도와 방문 간격 변동계수(CV)를 결합하여 '재방문 규칙성'을 5개 그룹으로 분류합니다. (`C1`: 낮음 ~ `C5`: 높음)

> ⚠️ **Self-Critical Review (v1.0의 한계)**: 현재 결과는 Consistency와 Outcome의 측정 기간(0~180d)이 겹쳐 있어 '사후 확신 편향'의 위험이 있습니다. 이는 차기 단계인 **Time-split(60d vs 120d) 분석**을 통해 인과관계를 재검증할 예정입니다.

---

## 2. Finding 1: Consistency Lift의 실체 (특히 저관여 유저에서 폭발적)
같은 Activation 단계 내에서도 Consistency(C1→C5)에 따라 장기 성과 지표가 급격히 갈립니다. 특히 초기 액션이 미비했던 유저군에서 리듬의 중요성이 더 크게 나타납니다.

![Figure 01-a](./figures/01_figure_a.png)
![Figure 01-b](./figures/01_figure_b.png)

- **Low Activation의 반전**: 초기 14일에 구매가 없었던 `A0`, `A1` 유저라도 **C5(높은 리듬)**에 해당하면, 180일 내 구매율(Purchase Rate)이 **C1 대비 10~20배 이상** 높게 나타남.
- **High Activation의 가치 확장**: 이미 구매를 경험한 `A5` 유저 또한 Consistency가 높을수록 추가 주문 및 매출 기여도가 선형적으로 상승함.

---

## 3. Finding 2: "20~30배의 격차"에 대한 산술적 검증 (Mix Effect)
평균 매출(Avg Revenue)이 수십 배 차이나는 현상은 구매자 비중의 차이와 구매자당 매출 상승이 결합된 결과입니다.

![Figure 03-a](./figures/03_figure_a.png)
![Figure 03-b](./figures/03_figure_b.png)

- **평균의 착시**: 대다수 미구매자가 포진한 C1~C3와 달리, C5는 구매자 비중이 압도적으로 높아 전체 평균이 크게 튐.
- **Buyer-only 분석**: 실제 구매가 일어난 유저들만 보면 C1 대비 C5의 매출 차이는 **1.3~2.4배** 수준으로 좁혀짐. 
- **결론**: Consistency는 '객단가'를 높이는 효과보다, **'구매를 하게 만드는 확률'**을 비약적으로 높이는 데 더 큰 기여를 함.

---

## 4. Finding 3: Funnel Bottleneck의 가변성 (14d vs 30d)
윈도우 설정에 따라 우리가 집중해야 할 병목 지점이 변화함을 확인했습니다.

![Figure 04-a](./figures/04_figure_a.png)
![Figure 04-b](./figures/04_figure_b.png)

- **초기 14일 병목**: 주로 **View → Click** 단계에서 발생. 신규 유저의 첫인상 및 상품 탐색 UX 개선이 시급함.
- **중기 30일 병목**: 주로 **Click → Add to Cart** 단계로 전이. 상세 페이지의 설득력(리뷰, 혜택) 및 장바구니 유도 장치가 핵심 변수로 작용.

---

## 5. Finding 4: 최악의 병목 세그먼트 (Worst 10)
어떤 그룹이 어떤 단계에서 가장 크게 이탈하는지 정밀 타겟팅 분석을 수행했습니다.

![Figure 05-a](./figures/05_figure_a.png)
![Figure 05-b](./figures/05_figure_b.png)

- **A1_view 유저의 침묵**: 14일 이내 View에 머문 유저 중 상당수가 클릭으로 넘어가지 못함. 이는 **추천 엔진의 개인화 수준**이나 **썸네일 매력도**에 심각한 결함이 있음을 시사.
- **데이터 기반 액션**: 30일 시점의 병목인 `click_to_cart` 전환율을 높이기 위해, 해당 세그먼트를 대상으로 한 리마인드 쿠폰이나 리뷰 노출 전략이 유효할 것으로 판단됨.

---

## 6. Limitations & Next Step (The Roadmap)
현재의 기술적(Descriptive) 분석을 넘어, 비즈니스 예측(Predictive) 모델로 고도화하기 위해 다음 과정을 수행합니다.

1. **Predictive Mart 구축 (Time-split)**:
   - 가입 후 **0~60일의 행동 지표(Predictor)**로 이후 **61~180일의 성과(Outcome)**를 예측하여 인과관계의 선후관계를 명확히 정립.
2. **Python 기반 유저 페르소나 재정의**:
   - 기존의 `user_type` 라벨을 배제하고, 순수 행동 데이터 기반의 Clustering/Labeling을 통해 세그먼트 로직을 파이썬에서 직접 재현.
3. **통계적 유의성 검증**:
   - 각 세그먼트별 LTV 상승폭이 우연이 아님을 증명하기 위해 Bootstrapping 기법을 적용한 신뢰구간 산출.

---
**Appendix. Used Data Marts (v1.0)**
- `ecommerce_dm.DM_user_window`
- `ecommerce_dm.DM_consistency_180d`
- `ecommerce_dm.DM_ltv_180d`
- `ecommerce_dm.DM_funnel_kpi_window`
