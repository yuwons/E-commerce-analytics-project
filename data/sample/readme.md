# Sample Data

이 폴더는 GitHub에서 빠르게 구조를 확인할 수 있도록 **샘플(각 5,000 rows)** 만 제공합니다.

- `dm_ab_dataset_sample.csv`: A/B 분석용 user-level export 샘플 (`ecommerce_dm_ab.AB_user_kpi` 기반)
- `time_split_min_sample.csv`: v1.1 time-split 검증용 user-level export 샘플

> Note: 전체 데이터/원본 export CSV는 용량 및 공개 범위를 고려해 레포에 포함하지 않았습니다.  
> 재현을 원할 경우, BigQuery에서 동일 DM을 생성 후 CSV로 export하여 노트북 입력으로 사용합니다.

Schema 정의:
- `docs/schema/ab_user_kpi_schema.md`
- `docs/schema/timesplit_validation_schema.md`
