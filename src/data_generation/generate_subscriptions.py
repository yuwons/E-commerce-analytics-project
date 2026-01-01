# -*- coding: utf-8 -*-
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

from data_generation import config


def _read_csv_safe(path: Path, date_cols: list[str] | None = None) -> pd.DataFrame:
    df = pd.read_csv(path, dtype="string", low_memory=False)
    if date_cols:
        for c in date_cols:
            if c in df.columns:
                df[c] = pd.to_datetime(df[c], errors="coerce")
    return df


def _ensure_parent_dir(p: Path) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)


def generate_subscriptions(
    users_path: Path,
    sessions_path: Path,
    orders_path: Path,
    order_items_path: Path,
    out_path: Path,
    seed: int = config.SEED,
) -> pd.DataFrame:
    rng = np.random.default_rng(seed)

    users = _read_csv_safe(users_path, date_cols=["signup_date"])
    sessions = _read_csv_safe(sessions_path, date_cols=["session_start_ts"])
    orders = _read_csv_safe(orders_path, date_cols=["order_ts"])
    items = _read_csv_safe(order_items_path)

    # ---- ref_ts / cutoff (최근 60일 기준) ----
    candidates = []
    if len(orders):
        candidates.append(pd.to_datetime(orders["order_ts"], errors="coerce").max())
    if len(sessions):
        candidates.append(pd.to_datetime(sessions["session_start_ts"], errors="coerce").max())
    ref_ts = pd.to_datetime(max([c for c in candidates if pd.notna(c)])) if candidates else pd.Timestamp.today()
    cutoff = ref_ts - pd.Timedelta(days=60)

    # ---- lookup ----
    users["user_id"] = users["user_id"].astype(str)
    if "user_type" not in users.columns:
        users["user_type"] = "B"
    utype = dict(zip(users["user_id"], users["user_type"].astype(str)))

    # ---- sessions_60d ----
    if len(sessions):
        sessions["user_id"] = sessions["user_id"].astype(str)
        sessions["session_start_ts"] = pd.to_datetime(sessions["session_start_ts"], errors="coerce")
        s60 = sessions[sessions["session_start_ts"] >= cutoff].copy()

        sess_cnt = s60.groupby("user_id")["session_id"].nunique()
        active_days = s60.assign(d=s60["session_start_ts"].dt.date).groupby("user_id")["d"].nunique()
    else:
        sess_cnt = pd.Series(dtype="int64")
        active_days = pd.Series(dtype="int64")

    # ---- orders_60d ----
    if len(orders):
        orders["user_id"] = orders["user_id"].astype(str)
        orders["order_ts"] = pd.to_datetime(orders["order_ts"], errors="coerce")
        o60 = orders[orders["order_ts"] >= cutoff].copy()

        ord_cnt = o60.groupby("user_id")["order_id"].nunique()
        first_order = orders.groupby("user_id")["order_ts"].min()
    else:
        ord_cnt = pd.Series(dtype="int64")
        first_order = pd.Series(dtype="datetime64[ns]")

    # ---- revenue_60d (order_items + orders join) ----
    # KeyError 방지: merge 후 user_id가 user_id_x/user_id_y로 바뀔 수 있음
    if len(items) and len(orders):
        items = items.copy()
        if "order_id" not in items.columns:
            raise ValueError("order_items.csv must contain order_id")

        o_map = orders[["order_id", "user_id", "order_ts"]].copy()
        o_map["order_ts"] = pd.to_datetime(o_map["order_ts"], errors="coerce")

        items2 = items.merge(o_map, on="order_id", how="left", suffixes=("_item", "_order"))

        # ✅ 여기서 user_id 컬럼 복구(핵심)
        if "user_id" not in items2.columns:
            if "user_id_item" in items2.columns and "user_id_order" in items2.columns:
                items2["user_id"] = items2["user_id_item"].fillna(items2["user_id_order"])
            elif "user_id_item" in items2.columns:
                items2["user_id"] = items2["user_id_item"]
            elif "user_id_order" in items2.columns:
                items2["user_id"] = items2["user_id_order"]

        if "user_id" not in items2.columns:
            raise ValueError("After merging, cannot find any user_id column in order_items join result.")

        items2["user_id"] = items2["user_id"].astype(str)
        items2 = items2[pd.to_datetime(items2["order_ts"], errors="coerce") >= cutoff].copy()

        items2["line_amount"] = pd.to_numeric(items2.get("line_amount"), errors="coerce").fillna(0.0)
        rev60 = items2.groupby("user_id")["line_amount"].sum()
    else:
        rev60 = pd.Series(dtype="float64")

    # ---- base output (1 row per user) ----
    out = pd.DataFrame({"user_id": users["user_id"]})
    out["subscription_id"] = ("SUB_" + out["user_id"]).astype("string")

    out["user_type"] = out["user_id"].map(lambda x: utype.get(str(x), "B")).astype("string")
    out["sessions_60d"] = out["user_id"].map(sess_cnt).fillna(0).astype(int)
    out["active_days_60d"] = out["user_id"].map(active_days).fillna(0).astype(int)
    out["orders_60d"] = out["user_id"].map(ord_cnt).fillna(0).astype(int)
    out["revenue_60d"] = out["user_id"].map(rev60).fillna(0.0).astype(float)

    # eligibility (문서 룰 유지)
    out["eligible"] = (out["orders_60d"] >= int(config.ELIG_ORDERS)) | (out["sessions_60d"] >= int(config.ELIG_SESSIONS))

    # consistency proxy
    consistent = out["active_days_60d"] >= 8

    base_prob = out["user_type"].map(lambda t: float(config.SUB_BASE_PROB.get(str(t), 0.05))).astype(float)
    prob = base_prob.copy()
    prob.loc[consistent] = prob.loc[consistent] * float(config.CONSISTENCY_MULT)
    prob = prob.clip(0, float(config.SUB_PROB_CAP))

    u = rng.random(len(out))
    subscribed = out["eligible"] & (u < prob)

    out["plan"] = "Free"
    out.loc[subscribed, "plan"] = "Plus"

    # premium rule: orders>=threshold OR revenue top pct among subscribed
    if subscribed.any():
        sub_df = out.loc[subscribed].copy()
        thr = np.quantile(sub_df["revenue_60d"].to_numpy(), 1.0 - float(config.PREMIUM_REVENUE_TOP_PCT))
        premium_mask = (sub_df["orders_60d"] >= int(config.PREMIUM_MIN_ORDERS_60D)) | (sub_df["revenue_60d"] >= thr)
        out.loc[sub_df.index[premium_mask], "plan"] = "Premium"

    fee_map = {"Free": 0, "Plus": 7900, "Premium": 14900}
    out["monthly_fee"] = out["plan"].map(fee_map).astype(int)

    # start/end/status
    out["start_date"] = pd.to_datetime(pd.NaT)
    out["end_date"] = pd.to_datetime(pd.NaT)
    out["status"] = "free"

    paid = out["plan"].isin(["Plus", "Premium"])
    if paid.any():
        # base anchor = first_order else signup_date
        signup_map = dict(zip(users["user_id"], pd.to_datetime(users["signup_date"], errors="coerce")))
        base = out["user_id"].map(first_order)
        base = pd.to_datetime(base, errors="coerce")
        base = base.fillna(out["user_id"].map(lambda x: signup_map.get(str(x), pd.NaT)))
        base = base.fillna(ref_ts - pd.Timedelta(days=120))

        # offsets by user_type
        offsets = []
        for uid, ut in out.loc[paid, ["user_id", "user_type"]].itertuples(index=False):
            off = config.SUB_OFFSET.get(str(ut))
            if off is None:
                delta = int(rng.integers(60, 120))
            else:
                delta = int(rng.integers(off[0], off[1] + 1))
            offsets.append(delta)

        start = pd.to_datetime(base.loc[paid].to_numpy()) + pd.to_timedelta(np.array(offsets), unit="D")
        out.loc[paid, "start_date"] = start

        # end/status (간단 버전)
        n_paid = int(paid.sum())
        cancel = rng.random(n_paid) < 0.20
        dur_months = rng.integers(1, 13, size=n_paid)
        end = pd.to_datetime(start) + pd.to_timedelta(dur_months * 30, unit="D")

        if cancel.any():
            early = rng.integers(7, 120, size=int(cancel.sum()))
            end_arr = end.to_numpy(dtype="datetime64[ns]")
            start_arr = pd.to_datetime(start).to_numpy(dtype="datetime64[ns]")
            end_arr[cancel] = start_arr[cancel] + early.astype("timedelta64[D]")
            end = pd.to_datetime(end_arr)

        out.loc[paid, "end_date"] = end.to_numpy()
        status = np.where(end >= ref_ts, "active", "expired")
        status = np.where(cancel & (end < ref_ts), "canceled", status)
        out.loc[paid, "status"] = status

    final = out[["subscription_id", "user_id", "plan", "start_date", "end_date", "status", "monthly_fee"]].copy()

    # integrity
    if final["subscription_id"].isna().any():
        raise ValueError("subscription_id has NULLs")
    if final["subscription_id"].duplicated().any():
        raise ValueError("subscription_id duplicates")
    if final["user_id"].duplicated().any():
        raise ValueError("subscriptions must be 1 row per user")

    _ensure_parent_dir(Path(out_path))
    final.to_csv(out_path, index=False)
    return final.head()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--users_path", type=str, required=True)
    ap.add_argument("--sessions_path", type=str, required=True)
    ap.add_argument("--orders_path", type=str, required=True)
    ap.add_argument("--order_items_path", type=str, required=True)
    ap.add_argument("--out_path", type=str, required=True)
    ap.add_argument("--seed", type=int, default=config.SEED)
    args = ap.parse_args()

    _ = generate_subscriptions(
        users_path=Path(args.users_path),
        sessions_path=Path(args.sessions_path),
        orders_path=Path(args.orders_path),
        order_items_path=Path(args.order_items_path),
        out_path=Path(args.out_path),
        seed=args.seed,
    )
    print(f"[OK] subscriptions saved to {args.out_path}")


if __name__ == "__main__":
    main()
