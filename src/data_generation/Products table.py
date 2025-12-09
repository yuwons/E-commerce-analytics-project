#!/usr/bin/env python
# coding: utf-8

# In[1]:


import numpy as np
import pandas as pd


# In[2]:


# -------------------------------
# CONFIG
# -------------------------------

# 총 생성할 상품 개수
NUM_PRODUCTS = 300

# 카테고리 목록 (순서는 균등 분포 생성에 사용)
CATEGORIES = [
    "Furniture", "Appliances", "Cleaning",
    "Kitchenware", "Fabric", "Organizers", "Deco"
]

# 카테고리별 가격 분포 설정
# - Normal 또는 Log-normal을 사용할 것이고
# - 아래는 각 카테고리의 typical range를 반영한 파라미터
PRICE_CONFIG = {
    "Furniture": {
        "dist": "normal",
        "mean": 200_000,
        "sd": 40_000,
        "min": 100_000,
        "max": 300_000,
    },
    "Appliances": {
        "dist": "normal",
        "mean": 160_000,
        "sd": 35_000,
        "min": 80_000,
        "max": 250_000,
    },
    "Cleaning": {
        "dist": "lognormal",
        "log_mean": np.log(50_000),
        "log_sigma": 0.6,
        "min": 15_000,
        "max": 120_000,
    },
    "Kitchenware": {
        "dist": "lognormal",
        "log_mean": np.log(30_000),
        "log_sigma": 0.5,
        "min": 10_000,
        "max": 70_000,
    },
    "Fabric": {
        "dist": "normal",
        "mean": 70_000,
        "sd": 20_000,
        "min": 20_000,
        "max": 120_000,
    },
    "Organizers": {
        "dist": "lognormal",
        "log_mean": np.log(20_000),
        "log_sigma": 0.5,
        "min": 8_000,
        "max": 50_000,
    },
    "Deco": {
        "dist": "lognormal",
        "log_mean": np.log(15_000),
        "log_sigma": 0.5,
        "min": 5_000,
        "max": 40_000,
    },
}

# discount_day_of_week: 카테고리 → 요일 고정 매핑
# - 월~목: 상대적으로 저가/중가
# - 금~일: 중고가/고가 중심 (토요일이 가장 비싼 Furniture)
DISCOUNT_DAY_MAP = {
    "Organizers": "Mon",
    "Cleaning": "Tue",
    "Kitchenware": "Wed",
    "Fabric": "Thu",
    "Appliances": "Fri",
    "Furniture": "Sat",
    "Deco": "Sun",
}


# -------------------------------
# Helper functions
# -------------------------------

def generate_category_list(num_products, categories):
    """
    product_id 1~NUM_PRODUCTS에 대해
    카테고리들이 최대한 균등하게 분포되도록 리스트 생성

    예: 300개, 7카테고리 → 대략 42~43개씩 할당
    """
    n_cat = len(categories)
    base = num_products // n_cat
    remainder = num_products % n_cat

    # 각 카테고리에 최소 base 개수씩 할당
    counts = [base] * n_cat
    # 나머지 remainder개는 앞에서부터 1개씩 추가
    for i in range(remainder):
        counts[i] += 1

    cat_list = []
    for cat, cnt in zip(categories, counts):
        cat_list.extend([cat] * cnt)

    # 혹시 길이가 맞지 않으면 슬라이스/추가로 정리
    cat_list = cat_list[:num_products]
    return cat_list


def generate_price_for_category(category):
    """
    카테고리별 PRICE_CONFIG를 참조하여
    해당 카테고리의 realistic price를 하나 생성
    """
    cfg = PRICE_CONFIG[category]

    if cfg["dist"] == "normal":
        price = np.random.normal(loc=cfg["mean"], scale=cfg["sd"])
    elif cfg["dist"] == "lognormal":
        price = np.random.lognormal(mean=cfg["log_mean"], sigma=cfg["log_sigma"])
    else:
        raise ValueError(f"Unknown distribution type for category {category}")

    # min/max 범위로 clamp
    price = max(cfg["min"], min(cfg["max"], price))
    return int(round(price))


def assign_price_tier(prices, low_ratio=0.30, high_ratio=0.20):
    """
    전체 상품 가격 리스트(prices)에 대해
    - 하위 low_ratio → "Low"
    - 중간 → "Mid"
    - 상위 high_ratio → "High"
    를 부여하는 price_tier 리스트를 반환

    여기서는:
    - Low: 하위 30%
    - Mid: 중간 50%
    - High: 상위 20%
    """
    series = pd.Series(prices)

    # 하위 30% 경계 (0.30 quantile)
    low_threshold = series.quantile(low_ratio)
    # 상위 20% 경계 → 하위 80% quantile (1 - high_ratio)
    high_threshold = series.quantile(1 - high_ratio)

    tiers = []
    for p in series:
        if p <= low_threshold:
            tiers.append("Low")
        elif p <= high_threshold:
            tiers.append("Mid")
        else:
            tiers.append("High")

    return tiers


# -------------------------------
# MAIN GENERATION
# -------------------------------

def generate_products(num_products=NUM_PRODUCTS):
    # product_id: 1 ~ num_products
    product_ids = list(range(1, num_products + 1))

    # category: 카테고리 균등 분포 리스트 생성
    categories = generate_category_list(num_products, CATEGORIES)

    prices = []
    discount_days = []

    # 각 product에 대해 price, discount_day 생성
    for cat in categories:
        # price: 카테고리별 분포에 맞게 생성
        price = generate_price_for_category(cat)
        prices.append(price)

        # discount_day_of_week: 카테고리 → 요일 고정 매핑
        discount_days.append(DISCOUNT_DAY_MAP[cat])

    # price_tier: 전체 가격 분포 기준으로 Low/Mid/High 구분
    # - Low: 하위 30%
    # - Mid: 중간 50%
    # - High: 상위 20%
    price_tiers = assign_price_tier(prices, low_ratio=0.30, high_ratio=0.20)

    # DataFrame 구성: Golden Schema v1.0 컬럼 순서 준수
    df = pd.DataFrame({
        # product_id: 상품 PK (1~300)
        "product_id": product_ids,
        # category: 7개 카테고리 (균등 분포)
        "category": categories,
        # price: 카테고리별 realistic price (Normal / Log-normal + clamp)
        "price": prices,
        # price_tier: Low(30%) / Mid(50%) / High(20%)
        "price_tier": price_tiers,
        # discount_day_of_week: 카테고리별 고정 할인 요일
        "discount_day_of_week": discount_days,
    })

    return df


if __name__ == "__main__":
    df = generate_products()
    df.to_csv("products.csv", index=False, encoding="utf-8-sig")
    print("products.csv 생성 완료!")


# In[3]:


df.head()


# In[ ]:




