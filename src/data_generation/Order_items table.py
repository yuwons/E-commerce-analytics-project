#!/usr/bin/env python
# coding: utf-8

# In[1]:


import pandas as pd
import numpy as np
import random
from datetime import datetime


# In[1]:


import pandas as pd
import numpy as np
import random
from datetime import datetime

# -------------------------------
# CONFIG
# -------------------------------

# 주문당 item 수 분포
ITEM_COUNT_DIST = {
    1: 0.65,
    2: 0.25,
    3: 0.08,
    4: 0.02
}

# qty 분포
QTY_DIST = {
    1: 0.75,
    2: 0.20,
    3: 0.05
}

# Subscription Type별 카테고리 선택 가중치
CATEGORY_WEIGHTS = {
    "Free": {
        "Furniture": 0.06,
        "Appliances": 0.10,
        "Cleaning": 0.20,
        "Kitchenware": 0.20,
        "Fabric": 0.14,
        "Organizers": 0.20,
        "Deco": 0.10,
    },
    "Plus": {
        "Furniture": 0.08,
        "Appliances": 0.12,
        "Cleaning": 0.18,
        "Kitchenware": 0.18,
        "Fabric": 0.14,
        "Organizers": 0.18,
        "Deco": 0.12,
    },
    "Premium": {
        "Furniture": 0.12,
        "Appliances": 0.16,
        "Cleaning": 0.14,
        "Kitchenware": 0.14,
        "Fabric": 0.16,
        "Organizers": 0.14,
        "Deco": 0.14,
    }
}

# -------------------------------
# LOAD TABLES
# -------------------------------

def load_orders(path="orders.csv"):
    df = pd.read_csv(path, parse_dates=["order_date"])
    return df

def load_users(path="users.csv"):
    df = pd.read_csv(path)
    return df

def load_products(path="products.csv"):
    df = pd.read_csv(path)
    return df

# -------------------------------
# HELPER FUNCTIONS
# -------------------------------

def sample_item_count(rng):
    """주문당 item 개수 선택"""
    options = list(ITEM_COUNT_DIST.keys())
    probs = list(ITEM_COUNT_DIST.values())
    return rng.choice(options, p=probs)

def sample_qty(rng):
    """qty 선택"""
    options = list(QTY_DIST.keys())
    probs = list(QTY_DIST.values())
    return rng.choice(options, p=probs)

def choose_category(subscription_type, rng):
    """Subscription Type 기반 category 선택"""
    weights = CATEGORY_WEIGHTS[subscription_type]
    categories = list(weights.keys())
    probs = list(weights.values())
    return rng.choice(categories, p=probs)

def choose_product(products_df, category, rng):
    """해당 카테고리의 product 중 하나 선택"""
    subset = products_df[products_df["category"] == category]
    return subset.sample(1, random_state=rng.integers(1e9)).iloc[0]

def is_discount_applied(order_date, discount_day):
    """할인 요일인지 판단"""
    weekday_map = {
        0: "Mon", 1: "Tue", 2: "Wed", 3: "Thu",
        4: "Fri", 5: "Sat", 6: "Sun"
    }
    order_day_str = weekday_map[order_date.weekday()]
    return order_day_str == discount_day

# -------------------------------
# MAIN GENERATION
# -------------------------------

def generate_order_items(
    orders_path="orders.csv",
    users_path="users.csv",
    products_path="products.csv",
    output_path="order_items.csv",
    random_seed=42,
):
    rng = np.random.default_rng(random_seed)

    # Load Datasets
    orders_df = load_orders(orders_path)
    users_df = load_users(users_path)
    products_df = load_products(products_path)

    # users와 orders join (subscription_type 활용위해)
    merged = orders_df.merge(users_df[["user_id", "subscription_type"]], on="user_id", how="left")

    order_items = []
    next_item_id = 1

    for _, row in merged.iterrows():

        order_id = int(row["order_id"])
        order_date = row["order_date"]
        subscription_type = row["subscription_type"]

        # 1) 주문당 item 수 결정
        item_count = sample_item_count(rng)

        for _ in range(item_count):

            # 2) 카테고리 선택 (sub type 반영)
            category = choose_category(subscription_type, rng)

            # 3) 해당 카테고리에서 product 선택
            product = choose_product(products_df, category, rng)
            product_id = int(product["product_id"])
            price = float(product["price"])
            discount_day = product["discount_day_of_week"]

            # 4) qty 선택
            qty = sample_qty(rng)

            # 5) line_amount 계산
            line_amount = price * qty

            # 6) 할인 적용 여부
            discounted = is_discount_applied(order_date, discount_day)

            # 7) 결과 append
            order_items.append([
                next_item_id,       # order_item_id
                order_id,           # order_id
                product_id,         # product_id
                category,           # category
                price,              # price snapshot
                qty,                # qty
                line_amount,        # line_amount
                discounted          # is_discounted
            ])

            next_item_id += 1

    # DataFrame 변환
    order_items_df = pd.DataFrame(order_items, columns=[
        "order_item_id",
        "order_id",
        "product_id",
        "category",
        "price",
        "qty",
        "line_amount",
        "is_discounted"
    ])

    # 저장
    order_items_df.to_csv(output_path, index=False, encoding="utf-8-sig")
    print(f"{output_path} 생성 완료! 총 {len(order_items_df):,} rows")

    return order_items_df


if __name__ == "__main__":
    generate_order_items()


# In[5]:





# In[ ]:




