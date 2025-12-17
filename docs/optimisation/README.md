# BigQuery Optimisation (Partitioning & Clustering)

이 프로젝트는 BigQuery 비용/성능 최적화를 위해 **파티셔닝(Partitioning)** 과 **클러스터링(Clustering)** 을 적용했다.  
특히 분석 질문이 **signup_date 기준 14/30/180일 윈도우** 형태이므로, 시간 필터와 유저 단위 집계가 자주 발생한다.

## What we optimised

- **Partitioning**
  - 목적: 날짜 필터 쿼리에서 스캔 바이트 감소 (Partition pruning 유도)
  - 대상 예: `events` → `DATE(event_ts)` 기준

- **Clustering**
  - 목적: user/session/event_type 조건이 자주 들어가는 쿼리에서 스캔/정렬 비용 절감
  - 대상 예: `events` → `CLUSTER BY user_id, session_id, event_type, product_id`

## Evidence (screenshots)
- Partitioning 효과 비교: `partition_effect.png` (before vs after)
- Clustering 효과 비교: `clustering_effect.png` (before vs after)

## Related docs
- DM 설계 인덱스: `../dm/README.md`
- Sanity checks: `../sanity_check/README.md`

