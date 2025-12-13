# generate_promo_calendar.py
from __future__ import annotations

import pandas as pd
import numpy as np
from datetime import timedelta

import config


def generate_promo_calendar(start_date: str = "2025-01-01") -> pd.DataFrame:
    """
    Company-wide promo calendar (global calendar).
    - Creates PROMO_EVENTS_PER_YEAR promo windows, each PROMO_LEN_DAYS long.
    - Outputs: promo_id, promo_name, start_date, end_date, uplift_level
    """
    rng = np.random.default_rng(config.SEED)

    start = pd.Timestamp(start_date).normalize()
    end = start + pd.Timedelta(days=config.OBS_DAYS - 1)

    # Heuristic "KR-like" seasonality windows within OBS_DAYS.
    # We keep it simple: choose fixed-ish anchors, then jitter a bit.
    anchors = [
        10,   # mid-Jan 느낌
        80,   # late-Mar 느낌
        170,  # late-Jun 느낌 (OBS_DAYS가 180이면 끝 근처)
        120,  # early-May / early-Sep 느낌 대체
        150,  # late-Nov 느낌 대체 (기간 짧을 때)
    ]
    # If OBS_DAYS < some anchors, we will filter them.
    anchors = [a for a in anchors if 0 <= a <= config.OBS_DAYS - config.PROMO_LEN_DAYS]
    if len(anchors) < config.PROMO_EVENTS_PER_YEAR:
        # fallback: evenly spaced
        anchors = list(np.linspace(5, config.OBS_DAYS - config.PROMO_LEN_DAYS - 1,
                                   num=config.PROMO_EVENTS_PER_YEAR, dtype=int))

    # pick K anchors (without replacement if possible)
    if len(anchors) >= config.PROMO_EVENTS_PER_YEAR:
        chosen = rng.choice(anchors, size=config.PROMO_EVENTS_PER_YEAR, replace=False)
    else:
        chosen = rng.choice(anchors, size=config.PROMO_EVENTS_PER_YEAR, replace=True)

    chosen = sorted(int(x) for x in chosen)

    rows = []
    for i, day_offset in enumerate(chosen, start=1):
        jitter = int(rng.integers(-2, 3))  # -2~+2일
        s = start + pd.Timedelta(days=max(0, min(config.OBS_DAYS - config.PROMO_LEN_DAYS, day_offset + jitter)))
        e = s + pd.Timedelta(days=config.PROMO_LEN_DAYS - 1)

        # uplift_level: High/Med/Low (임의, 분석용 태그)
        uplift_level = rng.choice(["High", "Med", "High", "Med", "Low"])

        rows.append({
            "promo_id": f"P{i:02d}",
            "promo_name": f"Promo_{i:02d}",
            "start_date": s.date().isoformat(),
            "end_date": e.date().isoformat(),
            "uplift_level": uplift_level,
        })

    promo = pd.DataFrame(rows).sort_values("start_date").reset_index(drop=True)

    # Also expand to daily flags for easy joining (optional but handy)
    # We'll keep both in one table by creating daily rows separately if needed later.
    return promo
