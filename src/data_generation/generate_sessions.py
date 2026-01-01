#!/usr/bin/env python
# coding: utf-8

# In[ ]:


# -*- coding: utf-8 -*-
from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd

from data_generation import config


def _read_csv_safe(path: Path, date_cols: list[str] | None = None) -> pd.DataFrame:
    df = pd.read_csv(
        path,
        dtype="string",
        keep_default_na=True,
        na_values=["", "NA", "NaN", "null", "None"],
        low_memory=False,
    )
    if date_cols:
        for c in date_cols:
            if c in df.columns:
                df[c] = pd.to_datetime(df[c], errors="coerce")
    return df


def _ensure_parent_dir(p: Path) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)


def _decay_factor(user_type: str, day_idx: int) -> float:
    schedules = {
        "A": config.A_DECAY,
        "B": config.B_DECAY,
        "C": config.C_DECAY,
        "D": config.D_DECAY,
    }
    for start, end, mult in schedules[user_type]:
        if start <= day_idx <= end:
            return float(mult)
    return 1.0


def _is_weekend(ts: pd.Timestamp) -> bool:
    # 5=Sat, 6=Sun
    return ts.weekday() >= 5


@dataclass
class PromoHit:
    is_promo: bool
    promo_id: str | None
    discount_rate: float


def _build_promo_index(promo: pd.DataFrame) -> list[tuple[pd.Timestamp, pd.Timestamp, str, float]]:
    # promo_calendar: promo_id, start_date, end_date, discount_rate ...
    out: list[tuple[pd.Timestamp, pd.Timestamp, str, float]] = []
    if promo is None or len(promo) == 0:
        return out

    p = promo.copy()
    if "start_date" in p.columns:
        p["start_date"] = pd.to_datetime(p["start_date"], errors="coerce")
    if "end_date" in p.columns:
        p["end_date"] = pd.to_datetime(p["end_date"], errors="coerce")
    if "discount_rate" in p.columns:
        p["discount_rate"] = pd.to_numeric(p["discount_rate"], errors="coerce").fillna(0.0)

    for r in p.itertuples(index=False):
        out.append((r.start_date.normalize(), r.end_date.normalize(), str(r.promo_id), float(r.discount_rate)))
    return out


def _promo_hit_for_date(promo_idx: list[tuple[pd.Timestamp, pd.Timestamp, str, float]], d: pd.Timestamp) -> PromoHit:
    if not promo_idx:
        return PromoHit(False, None, 0.0)
    dn = d.normalize()
    for s, e, pid, dr in promo_idx:
        if pd.notna(s) and pd.notna(e) and s <= dn <= e:
            return PromoHit(True, pid, dr)
    return PromoHit(False, None, 0.0)


def generate_sessions(
    users_path: Path,
    promo_path: Path | None = None,
    out_path: Path | None = None,
    seed: int = config.SEED,
    obs_days: int = config.OBS_DAYS,
    max_sessions_per_user: int | None = None,
    max_sessions_per_day: int | None = None,
) -> pd.DataFrame:
    """
    sessions: user 방문(재방문/retention의 raw)
    - signup_date 기준 obs_days 동안 day-level로 방문 여부 샘플링
    - decay + weekend boost + (A burst/gap) + (promo visit uplift) 반영
    - 상한(max_sessions_per_user/day)로 폭발 방지

    Output columns:
      session_id, user_id, session_start_ts, session_date, device, user_type,
      is_promo, promo_id, discount_rate
    """
    rng = np.random.default_rng(seed)

    users = _read_csv_safe(users_path, date_cols=["signup_date"])
    if promo_path is not None and Path(promo_path).exists():
        promo = _read_csv_safe(Path(promo_path), date_cols=["start_date", "end_date"])
    else:
        promo = pd.DataFrame()

    promo_idx = _build_promo_index(promo)

    max_sessions_per_user = int(max_sessions_per_user or getattr(config, "MAX_SESSIONS_PER_USER", 80))
    max_sessions_per_day = int(max_sessions_per_day or getattr(config, "MAX_SESSIONS_PER_DAY", 1))

    promo_visit_uplift = getattr(config, "PROMO_VISIT_UPLIFT", {"A": 2.0, "B": 1.05, "C": 1.0, "D": 1.05})

    rows = []
    sid_counter = 0

    for u in users.itertuples(index=False):
        user_id = str(u.user_id)
        signup = pd.to_datetime(u.signup_date, errors="coerce")
        if pd.isna(signup):
            continue

        utype = str(u.user_type) if "user_type" in users.columns else "B"
        device = str(u.device) if "device" in users.columns else "Web"

        # A burst/gap 파라미터
        gap_start = None
        gap_end = None
        if utype == "A":
            gap_start = int(rng.integers(config.A_GAP_START_RANGE[0], config.A_GAP_START_RANGE[1] + 1))
            gap_len = int(rng.integers(config.A_GAP_LEN_RANGE[0], config.A_GAP_LEN_RANGE[1] + 1))
            gap_end = gap_start + gap_len

        created_for_user = 0

        for day_idx in range(obs_days):
            if created_for_user >= max_sessions_per_user:
                break

            d = signup.normalize() + pd.Timedelta(days=day_idx)

            # base p
            p = float(config.BASE_P_VISIT.get(utype, 0.15))
            p *= _decay_factor(utype, day_idx)

            # weekend boost
            if _is_weekend(d):
                p *= (1.0 + float(config.WEEKEND_BOOST.get(utype, 0.0)))

            # A burst / gap
            if utype == "A":
                # burst: signup+1 ~ signup+5
                if config.A_BURST_DAYS[0] <= day_idx <= config.A_BURST_DAYS[1]:
                    p = max(p, float(config.A_BURST_P))
                # gap window
                if gap_start is not None and gap_end is not None and gap_start <= day_idx <= gap_end:
                    p = min(p, float(config.A_GAP_P))

            # promo visit uplift
            ph = _promo_hit_for_date(promo_idx, d)
            if ph.is_promo:
                p *= float(promo_visit_uplift.get(utype, 1.0))

            p = min(max(p, 0.0), 0.98)

            visited = rng.random() < p
            if not visited:
                continue

            # sessions per day (기본 1, 상한 적용)
            n_sessions = 1
            n_sessions = min(n_sessions, max_sessions_per_day)

            for s in range(n_sessions):
                if created_for_user >= max_sessions_per_user:
                    break

                sid_counter += 1
                created_for_user += 1

                # session time: 08:00~23:00 랜덤
                sec = int(rng.integers(8 * 3600, 23 * 3600))
                session_start = d + pd.Timedelta(seconds=sec)

                session_id = f"S_{user_id}_{d.strftime('%Y%m%d')}_{s+1}"

                rows.append(
                    {
                        "session_id": session_id,
                        "user_id": user_id,
                        "session_start_ts": session_start,
                        "session_date": d.date().isoformat(),
                        "device": device,
                        "user_type": utype,
                        "is_promo": int(ph.is_promo),
                        "promo_id": ph.promo_id,
                        "discount_rate": ph.discount_rate if ph.is_promo else 0.0,
                    }
                )

    sessions = pd.DataFrame(rows)
    if len(sessions):
        sessions["session_start_ts"] = pd.to_datetime(sessions["session_start_ts"], errors="coerce")
        sessions["discount_rate"] = pd.to_numeric(sessions["discount_rate"], errors="coerce").fillna(0.0)

    if out_path is not None:
        out_path = Path(out_path)
        _ensure_parent_dir(out_path)
        sessions.to_csv(out_path, index=False)

    return sessions


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--users_path", type=str, required=True)
    ap.add_argument("--promo_path", type=str, default=None)
    ap.add_argument("--out_path", type=str, required=True)
    ap.add_argument("--seed", type=int, default=config.SEED)
    ap.add_argument("--obs_days", type=int, default=config.OBS_DAYS)
    ap.add_argument("--max_sessions_per_user", type=int, default=getattr(config, "MAX_SESSIONS_PER_USER", 80))
    ap.add_argument("--max_sessions_per_day", type=int, default=getattr(config, "MAX_SESSIONS_PER_DAY", 1))
    args = ap.parse_args()

    df = generate_sessions(
        users_path=Path(args.users_path),
        promo_path=Path(args.promo_path) if args.promo_path else None,
        out_path=Path(args.out_path),
        seed=args.seed,
        obs_days=args.obs_days,
        max_sessions_per_user=args.max_sessions_per_user,
        max_sessions_per_day=args.max_sessions_per_day,
    )
    print(f"[OK] sessions rows={len(df):,} saved to {args.out_path}")


if __name__ == "__main__":
    main()

