# generate_promo_calendar.py
# 목적: 회사 공통(Global) 프로모션 캘린더 생성
# - 유저 상대일이 아니라 "서비스 전체에 공통으로 적용되는 프로모션 주간"을 만든다.
# - 이후 events/orders 생성 시 "해당 날짜가 promo 기간인지"를 join해서 uplift/할인을 적용한다.

from __future__ import annotations

import pandas as pd
import numpy as np

import config


def generate_promo_calendar(start_date: str = "2025-01-01") -> pd.DataFrame:
    """
    Company-wide promo calendar generator.

    Returns a DataFrame with:
    - promo_id: 프로모션 ID
    - promo_name: 프로모션 이름
    - start_date / end_date: 프로모션 기간(연속 7일 등)
    - uplift_level: (분석/태그용) High/Med/Low
    """
    # 재현 가능한 난수(항상 같은 결과)
    rng = np.random.default_rng(config.SEED)

    # 프로젝트의 "관측 기간" 기준 시작일과 끝일
    start = pd.Timestamp(start_date).normalize()

    # KR 이커머스 시즌성 느낌을 주기 위한 "대략적 앵커(후보 day offset)"들
    # (OBS_DAYS=180이면 0~179 사이에서 프로모션 시작일 후보를 잡는다)
    anchors = [
        10,   # mid-Jan 느낌
        80,   # late-Mar 느낌
        120,  # early-May / early-Sep 대체 느낌
        150,  # late-Nov 대체 느낌 (기간 짧을 때)
        170,  # late-Jun 느낌 (OBS_DAYS가 180이면 끝 근처)
    ]

    # 프로모션 시작일이 관측기간을 넘어가지 않도록 필터링
    anchors = [a for a in anchors if 0 <= a <= config.OBS_DAYS - config.PROMO_LEN_DAYS]

    # 앵커가 부족하면 "균등 간격"으로 fallback
    if len(anchors) < config.PROMO_EVENTS_PER_YEAR:
        anchors = list(
            np.linspace(
                5,
                config.OBS_DAYS - config.PROMO_LEN_DAYS - 1,
                num=config.PROMO_EVENTS_PER_YEAR,
                dtype=int,
            )
        )

    # K개의 프로모션 시작일 후보를 선택(가능하면 중복 없이)
    if len(anchors) >= config.PROMO_EVENTS_PER_YEAR:
        chosen = rng.choice(anchors, size=config.PROMO_EVENTS_PER_YEAR, replace=False)
    else:
        chosen = rng.choice(anchors, size=config.PROMO_EVENTS_PER_YEAR, replace=True)

    chosen = sorted(int(x) for x in chosen)

    rows = []
    for i, day_offset in enumerate(chosen, start=1):
        # 너무 "딱딱한 고정 날짜" 느낌을 줄이기 위해 ±2일 정도 랜덤 jitter
        jitter = int(rng.integers(-2, 3))  # -2~+2

        # 시작일은 0~(OBS_DAYS-PROMO_LEN_DAYS) 범위를 벗어나지 않게 클램프
        start_offset = max(0, min(config.OBS_DAYS - config.PROMO_LEN_DAYS, day_offset + jitter))

        s = start + pd.Timedelta(days=start_offset)
        e = s + pd.Timedelta(days=config.PROMO_LEN_DAYS - 1)

        # uplift_level은 실제 로직엔 안 쓰고, "프로모션 강도" 태그로만 사용(선택)
        uplift_level = rng.choice(["High", "Med", "High", "Med", "Low"])

        rows.append(
            {
                "promo_id": f"P{i:02d}",
                "promo_name": f"Promo_{i:02d}",
                "start_date": s.date().isoformat(),
                "end_date": e.date().isoformat(),
                "uplift_level": uplift_level,
            }
        )

    # 프로모션 기간 오름차순 정렬
    promo = pd.DataFrame(rows).sort_values("start_date").reset_index(drop=True)
    return promo
