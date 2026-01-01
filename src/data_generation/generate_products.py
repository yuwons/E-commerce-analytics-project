#!/usr/bin/env python
# coding: utf-8

# In[ ]:


# src/data_generation/generate_products.py
"""
Generate products table.

Design intent:
- 300 SKUs across 7 categories
- Category mix controlled by config.CATEGORY_WEIGHTS
- Price is sampled from category-level lognormal distribution (median/sigma)
- Category-level PRICE_CAP is applied to avoid unrealistic outliers
"""

from __future__ import annotations

from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd

from . import config  # ✅ package-safe import


def _sample_lognormal_with_median(
    rng: np.random.Generator,
    n: int,
    median: float,
    sigma: float,
) -> np.ndarray:
    """
    Sample lognormal prices given median & sigma.

    For lognormal distribution:
    - median = exp(mu) => mu = log(median)
    """
    mu = np.log(float(median))
    return rng.lognormal(mean=mu, sigma=float(sigma), size=int(n))


def generate_products(
    n_products: Optional[int] = None,
    out_path: str = "data/generated/products.csv",
) -> pd.DataFrame:
    """
    Generate products dataframe and save as CSV.

    Columns:
    - product_id: PR00001 ...
    - product_name: Product_00001 ...
    - category
    - brand
    - price (KRW, rounded to 1,000)
    - rating_avg (1.0~5.0)
    - is_new_arrival (0/1)
    """
    rng = np.random.default_rng(config.SEED)

    n = int(n_products or config.PRODUCTS_N)

    # 1) Category sampling (ensure weights normalized)
    categories = list(config.CATEGORIES)
    weights = np.array([config.CATEGORY_WEIGHTS[c] for c in categories], dtype=float)
    weights = weights / weights.sum()

    cat = rng.choice(categories, size=n, replace=True, p=weights)

    # 2) Price sampling (category-wise lognormal + cap)
    price = np.zeros(n, dtype=int)

    for c in categories:
        idx = np.where(cat == c)[0]
        if len(idx) == 0:
            continue

        params = config.PRICE_LN_PARAMS[c]
        raw = _sample_lognormal_with_median(
            rng=rng,
            n=len(idx),
            median=params["median"],
            sigma=params["sigma"],
        )

        # Round to nearest 1,000 KRW to feel realistic
        raw = np.round(raw / 1000) * 1000

        # Apply category cap to avoid insane outliers
        cap = config.PRICE_CAP.get(c, None)
        if cap is not None:
            raw = np.minimum(raw, cap)

        # Enforce minimum price (>= 1,000 KRW)
        raw = np.maximum(raw, 1000)

        price[idx] = raw.astype(int)

    # 3) Brand pools (simple but realistic)
    #    - Keep it small so analysis isn't overly noisy.
    brand_pool = {
        "Furniture":   ["Hans", "Roomie", "Wood&Co", "Casa", "UrbanNest", "Oakline"],
        "Appliances":  ["NeoTech", "HomeLab", "AirPlus", "Volt", "Zenith", "CleanPro"],
        "Kitchenware": ["Kitchi", "ChefMate", "SteelWorks", "DailyPan", "Cook&Go"],
        "Fabric":      ["SoftDays", "LinenLab", "Cottony", "Warm&Co", "CozyHome"],
        "Organizers":  ["StackIt", "Boxy", "SpaceUp", "TidyLab", "Roomie"],
        "Deco":        ["Glow", "Moodify", "FrameIt", "Artline", "UrbanNest"],
        "Cleaning":    ["Freshy", "Sparkle", "PureHome", "MopMop", "SodaLab"],
    }

    brand = np.empty(n, dtype=object)
    for c in categories:
        idx = np.where(cat == c)[0]
        if len(idx) == 0:
            continue
        brand[idx] = rng.choice(brand_pool[c], size=len(idx), replace=True)

    # 4) Rating / new arrival
    rating = rng.normal(loc=config.RATING_MEAN, scale=config.RATING_STD, size=n)
    rating = np.clip(rating, 1.0, 5.0)
    rating = np.round(rating, 2)

    is_new_arrival = (rng.random(n) < float(config.NEW_ARRIVAL_RATE)).astype(int)

    # 5) Build dataframe
    df = pd.DataFrame({
        "product_id": [f"PR{str(i+1).zfill(5)}" for i in range(n)],
        "product_name": [f"Product_{str(i+1).zfill(5)}" for i in range(n)],
        "category": cat,
        "brand": brand,
        "price": price,
        "rating_avg": rating,
        "is_new_arrival": is_new_arrival,
    })

    # 6) Save
    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(out, index=False, encoding="utf-8-sig")

    return df


if __name__ == "__main__":
    products = generate_products()
    print(products.head())
    print("✅ products generated:", len(products))

