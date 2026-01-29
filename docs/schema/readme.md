# Schema 문서 안내 (docs/schema)

이 폴더는 **Python 노트북에서 사용하는 CSV export 데이터**의 컬럼/지표 정의를 빠르게 확인할 수 있도록 만든 **최소 스키마 문서**입니다.

> GitHub에는 용량 이슈로 `data/sample/`의 **샘플 CSV**만 포함했습니다.  
> 노트북은 샘플 CSV로도 **실행/재현 가능**하며, `docs/results/` 및 `docs/results/story.md`에 포함된 **최종 결과/그래프는 BigQuery DM에서 export한 전체 데이터(full export) 기준**으로 생성되었습니다.

---

## 포함 문서

- `timesplit_validation_schema.md`  
  v1.1 **Time-split 검증용 CSV export** 스키마  
  - Notebook: `src/python/Python (EDA + Visualisation).ipynb`  
  - Sample CSV: `data/sample/time_split_min_sample.csv`

- `ab_user_kpi_schema.md`  
  **A/B Experiment 유저 단위 KPI export** 스키마  
  - Notebook: `src/python/Python_(AB Experiment).ipynb`  
  - Sample CSV: `data/sample/dm_ab_dataset_sample.csv`

---

## 참고

- 본 문서들은 **DM 설계 문서**가 아니라, 노트북 입력용 CSV의 **컬럼 의미/윈도우 정의/지표 계산 기준**을 요약한 “사용자 가이드”입니다.
- 분석 해석/결론은 `docs/results/story.md`에 정리되어 있습니다.

