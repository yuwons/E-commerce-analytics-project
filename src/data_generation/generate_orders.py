# -*- coding: utf-8 -*-
from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd


def _ensure_parent_dir(p: Path) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)


def generate_orders(
    events_path: Path,
    out_path: Path,
    chunksize: int = 500_000,
) -> pd.DataFrame:
    """
    orders는 events의 purchase에서만 생성 (1 purchase = 1 order)
    """
    _ensure_parent_dir(Path(out_path))

    first = True
    total = 0

    usecols = ["order_id", "user_id", "event_ts", "is_promo", "discount_rate", "promo_id", "event_type"]
    for chunk in pd.read_csv(events_path, usecols=usecols, chunksize=chunksize, dtype="string", low_memory=False):
        chunk = chunk[chunk["event_type"] == "purchase"].copy()
        if len(chunk) == 0:
            continue

        chunk.rename(columns={"event_ts": "order_ts"}, inplace=True)
        chunk = chunk[["order_id", "user_id", "order_ts", "is_promo", "discount_rate", "promo_id"]].copy()

        chunk.to_csv(out_path, index=False, mode="w" if first else "a", header=first)
        first = False
        total += len(chunk)

    if total == 0:
        # create empty file with header
        pd.DataFrame(columns=["order_id", "user_id", "order_ts", "is_promo", "discount_rate", "promo_id"]).to_csv(
            out_path, index=False
        )

    return pd.read_csv(out_path, nrows=5)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--events_path", type=str, required=True)
    ap.add_argument("--out_path", type=str, required=True)
    args = ap.parse_args()

    _ = generate_orders(Path(args.events_path), Path(args.out_path))
    print(f"[OK] orders saved to {args.out_path}")


if __name__ == "__main__":
    main()
