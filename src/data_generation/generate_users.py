#!/usr/bin/env python
# coding: utf-8

# In[ ]:


# src/data_generation/generate_users.py
"""
Generate users table.

Design intent:
- Signup dates are spread across a 3-year window (cohort diversity).
- Downstream behaviors are generated only within OBS_DAYS after signup.
- Each user is assigned a behavior type (A/B/C/D) which drives all later distributions.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd

from . import config  # ✅ package-safe import (IMPORTANT)


# ----------------------------
# Helpers
# ----------------------------
def _set_seed(seed: int) -> None:
    """Set global random seed for reproducibility."""
    np.random.seed(seed)


def _random_dates_uniform(start: pd.Timestamp, end: pd.Timestamp, n: int) -> pd.Series:
    """
    Generate n random timestamps uniformly between start and end (inclusive-ish).
    """
    start_u = start.value // 10**9  # seconds
    end_u = end.value // 10**9
    rand_u = np.random.randint(start_u, end_u + 1, size=n)
    return pd.to_datetime(rand_u, unit="s")


def _choice_with_probs(values: list[str], probs: list[float], n: int) -> np.ndarray:
    """Convenience wrapper for numpy choice with probabilities."""
    return np.random.choice(values, size=n, p=probs)


# ----------------------------
# Main generator
# ----------------------------
def generate_users(
    n_users: int = 50_000,
    start_date: str = "2022-01-01",
    end_date: str = "2024-12-31",
    out_path: Optional[str] = "data/generated/users.csv",
) -> pd.DataFrame:
    """
    Generate a users dataframe.

    Parameters
    ----------
    n_users : int
        Number of users to generate.
    start_date, end_date : str
        Signup window (3 years recommended).
    out_path : str | None
        Where to save CSV. If None, do not save.

    Returns
    -------
    pd.DataFrame
        Users table.
    """
    _set_seed(config.SEED)

    start = pd.Timestamp(start_date)
    end = pd.Timestamp(end_date)

    # 1) user_id
    user_ids = np.arange(1, n_users + 1)

    # 2) signup_date spread across 3-year window
    # DatetimeIndex는 .dt 없이 바로 floor 가능
    signup_dates = _random_dates_uniform(start, end, n_users).floor("D")


    # 3) user_type (A/B/C/D) based on config.TYPE_RATIOS
    type_labels = list(config.TYPE_RATIOS.keys())
    type_probs = [config.TYPE_RATIOS[t] for t in type_labels]
    user_types = _choice_with_probs(type_labels, type_probs, n_users)

    # 4) basic dimensions (keep realistic but not overcomplicated)
    # device
    devices = _choice_with_probs(
        ["iOS", "Android", "Web"],
        [0.40, 0.45, 0.15],
        n_users,
    )

    # region (Korea-ish distribution; simple)
    regions = _choice_with_probs(
        ["Seoul", "Gyeonggi", "Other"],
        [0.38, 0.32, 0.30],
        n_users,
    )

    # marketing_source
    marketing_sources = _choice_with_probs(
        ["Organic", "Paid", "Referral"],
        [0.60, 0.30, 0.10],
        n_users,
    )

    # 5) (Optional) anomaly flag: 1% intentionally odd (for "preprocessing" showcase later)
    anomaly_flag = (np.random.rand(n_users) < 0.01).astype(int)

    users = pd.DataFrame(
        {
            "user_id": user_ids,
            "signup_date": signup_dates,
            "user_type": user_types,
            "device": devices,
            "region": regions,
            "marketing_source": marketing_sources,
            "anomaly_flag": anomaly_flag,
        }
    )

    # Sort for readability (not required)
    users = users.sort_values(["signup_date", "user_id"]).reset_index(drop=True)

    # 6) Save if requested
    if out_path is not None:
        out = Path(out_path)
        out.parent.mkdir(parents=True, exist_ok=True)
        users.to_csv(out, index=False)

    return users


if __name__ == "__main__":
    # Allow running as a script:
    df = generate_users()
    print(df.head())
    print("✅ users generated:", len(df))

