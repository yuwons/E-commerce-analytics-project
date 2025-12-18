# 01) Activation(초기 14일) → Long-term Outcomes (LTV / Retention)

## 목적 (Purpose)
- **가입 후 초기 14일(Activation)** 동안 유저가 퍼널을 어디까지 진행했는지(깊이)를 기준으로,
  **장기 성과(180일 LTV/Retention)** 가 실제로 달라지는지 확인한다.
- 프로젝트 메인 스토리의 1단계:  
  **“초기 전환(Activation)이 장기 성과를 어느 정도 설명하는가?”**

## 사용 데이터 (Inputs / Source of Truth)
- `ecommerce_dm.DM_user_window`  
  - 14d 퍼널 reach flag + 180d 성과 지표(orders/revenue/session/event)
- `ecommerce.sessions`  
  - 유저별 방문일(day_index) 기반 retention checkpoint 계산용

## 핵심 정의 (Key Definitions)
- **Activation stage (14d)**: 초기 14일 내 퍼널 도달 단계(최대 단계 기준)
  - `A0_no_activity → A1_view → A2_click → A3_add_to_cart → A4_checkout → A5_purchase`
- **Near-180 Retention (D180 proxy)** *(중요)*  
  - 현재 synthetic sessions는 최대 `day_index=179`까지만 존재 (day 180 없음)
  - 따라서 “D180 retention”은 아래 proxy로 정의:
  - **D180 proxy = 가입 후 day 173~179 구간 중 하루라도 세션이 있으면 retained(=1)**

## 쿼리 목록 (Queries)
- `02_activation_vs_ltv.sql`
  - Activation stage별로 **180d 구매율/주문수/매출(LTV)** 및 volume(session/event)을 비교
- `03_activation_vs_retention_summary_proxy180.sql`
  - Activation stage별 **Retention checkpoints** 산출  
  - D7/D30/D90 + **Near-180(D173~179 proxy)** 포함

## 산출물 (Outputs)
- Activation stage 단위 요약표 2개
  1) **Activation → 180d LTV**
  2) **Activation → Retention (D7/D30/D90 + D180 proxy)**

> Note: 폴더별 README는 “메모/인덱스용(빠른 복기)”이며,  
> 최종 결과 해석/시각화/스토리는 별도 분석 문서(1개)로 정리 예정.
