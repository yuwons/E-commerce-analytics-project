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


def generate_order_items(
    orders_path: Path,
    users_path: Path,
    products_path: Path,
    out_path: Path,
    seed: int = config.SEED,
) -> pd.DataFrame:
    rng = np.random.default_rng(seed)

    orders = _read_csv_safe(orders_path, date_cols=["order_ts"])
    users = _read_csv_safe(users_path, date_cols=["signup_date"])
    products = _read_csv_safe(products_path)

    if len(orders) == 0:
        _ensure_parent_dir(out_path)
        pd.DataFrame(
            columns=[
                "order_item_id",
                "order_id",
                "user_id",
                "product_id",
                "quantity",
                "unit_price",
                "is_promo",
                "discount_rate",
                "final_unit_price",
                "line_amount",
            ]
        ).to_csv(out_path, index=False)
        return pd.read_csv(out_path, nrows=5)

    # lookups
    utype = dict(zip(users["user_id"].astype(str), users["user_type"].astype(str)))

    # prices
    products["price"] = pd.to_numeric(products["price"], errors="coerce")
    product_ids = products["product_id"].astype(str).tolist()
    price_map = dict(zip(products["product_id"].astype(str), products["price"].fillna(0).astype(float)))

    rows = []
    oi = 0

    for o in orders.itertuples(index=False):
        oid = str(o.order_id)
        uid = str(o.user_id)
        ut = utype.get(uid, "B")

        is_promo = int(getattr(o, "is_promo", "0") or 0)
        disc = float(getattr(o, "discount_rate", "0") or 0.0)

        avg_items = float(config.AVG_ITEMS_PER_ORDER.get(ut, 1.4))
        n_items = int(max(1, min(5, rng.poisson(avg_items))))
        chosen = rng.choice(product_ids, size=n_items, replace=(n_items > len(product_ids)))

        for pid in chosen:
            pid = str(pid)
            unit_price = float(price_map.get(pid, 0.0))

            qty = 1 if rng.random() < 0.90 else 2
            final_unit = unit_price * (1.0 - disc) if is_promo else unit_price
            line_amount = final_unit * qty

            oi += 1
            rows.append(
                {
                    "order_item_id": f"OI_{oi}",
                    "order_id": oid,
                    "user_id": uid,
                    "product_id": pid,
                    "quantity": int(qty),
                    "unit_price": float(unit_price),
                    "is_promo": int(is_promo),
                    "discount_rate": float(disc if is_promo else 0.0),
                    "final_unit_price": float(final_unit),
                    "line_amount": float(line_amount),
                }
            )

    out = pd.DataFrame(rows)
    _ensure_parent_dir(out_path)
    out.to_csv(out_path, index=False)

    return out.head()
    

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--orders_path", type=str, required=True)
    ap.add_argument("--users_path", type=str, required=True)
    ap.add_argument("--products_path", type=str, required=True)
    ap.add_argument("--out_path", type=str, required=True)
    ap.add_argument("--seed", type=int, default=config.SEED)
    args = ap.parse_args()

    _ = generate_order_items(
        orders_path=Path(args.orders_path),
        users_path=Path(args.users_path),
        products_path=Path(args.products_path),
        out_path=Path(args.out_path),
        seed=args.seed,
    )
    print(f"[OK] order_items saved to {args.out_path}")


if __name__ == "__main__":
    main()
