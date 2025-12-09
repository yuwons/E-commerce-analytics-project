#!/usr/bin/env python
# coding: utf-8

# In[1]:


import pandas as pd
import numpy as np
import uuid
import random
from datetime import timedelta, datetime


# In[2]:


# ============================================================
# 1) Load upstream tables (users, products, orders, order_items)
# ============================================================

users = pd.read_csv("users.csv")
products = pd.read_csv("products.csv")
orders = pd.read_csv("orders_updated.csv")  # update된 최신 Orders
order_items = pd.read_csv("order_items.csv")

# Discount mapping (category → discount weekday)
discount_map = dict(zip(products["product_id"], products["discount_day_of_week"]))

# ============================================================
# 2) Helper functions
# ============================================================

def random_uuid():
    return str(uuid.uuid4())[:18]  # 짧은 UUID

def pick_referrer(event_type):
    """event_type 기반 자연스러운 referrer 추천"""
    if event_type == "view_product":
        return np.random.choice(["home", "category", "search", "external"], p=[0.45, 0.25, 0.20, 0.10])
    elif event_type == "add_to_cart":
        return "product"
    elif event_type == "checkout_start":
        return "cart"
    elif event_type == "payment_attempt":
        return "checkout"
    elif event_type == "purchase":
        return np.random.choice(["checkout", "payment"])
    return None

def next_ts(ts):
    """다음 이벤트 timestamp 증가: 5초 ~ 5분 랜덤"""
    return ts + timedelta(seconds=np.random.randint(5, 300))


def generate_funnel_branch():
    """
    Funnel 구조 (정상 + 현실적으로 존재하는 branch)
    * anomaly가 아닌 정상 branch만 포함됨
    """
    paths = [
        ["view_product", "add_to_cart", "checkout_start", "payment_attempt", "purchase"],
        ["view_product", "checkout_start", "payment_attempt", "purchase"],
        ["view_product", "add_to_cart", "checkout_start"],
        ["view_product", "add_to_cart"],
        ["view_product"],
    ]
    prob = [0.60, 0.15, 0.10, 0.10, 0.05]  # realistic
    return np.random.choice(range(len(paths)), p=prob), paths


def generate_anomaly_event(user_id):
    """
    진짜 anomaly event 생성 (2%에 해당)
    """
    anomaly_types = [
        "payment_without_checkout",
        "purchase_without_payment",
        "timestamp_reverse",
        "missing_session",
        "wrong_timestamp_vs_order_date",
        "missing_product_id",
    ]
    selected = np.random.choice(anomaly_types)
    
    return {
        "user_id": user_id,
        "session_id": None if selected == "missing_session" else random_uuid(),
        "event_type": "anomaly_event",
        "product_id": None,
        "device": None,
        "referrer": None,
        "event_timestamp": None,
        "is_discount_event": False,
        "anomaly_flag": True,
    }

# ============================================================
# 3) Generate Events for Each User
# ============================================================

events = []
event_id_counter = 1

print("Generating user events...")

for idx, user in users.iterrows():
    user_id = int(user["user_id"])
    subscription = user["subscription_type"]
    device = user["device"]

    # Subscription 기반 session 수 결정
    if subscription == "Free":
        num_sessions = np.random.randint(3, 7)
    elif subscription == "Plus":
        num_sessions = np.random.randint(5, 10)
    else:
        num_sessions = np.random.randint(7, 14)

    # 주문 중 purchase 이벤트 timestamp align을 위해 user orders load
    user_orders = orders[orders["user_id"] == user_id]

    last_session_end = user["signup_date"] + " 09:00:00"

    for s in range(num_sessions):
        session_id = random_uuid()

        # Session 시작 시간
        if isinstance(last_session_end, str):
            last_session_end = datetime.strptime(last_session_end, "%Y-%m-%d %H:%M:%S")
        session_start = last_session_end + timedelta(hours=np.random.randint(2, 48))
        last_session_end = session_start

        funnel_index, funnel_paths = generate_funnel_branch()
        funnel = funnel_paths[funnel_index]

        # 상품 선택 (view 기반)
        sampled_products = products.sample(1)
        product_id = int(sampled_products["product_id"].iloc[0])
        product_discount_day = sampled_products["discount_day_of_week"].iloc[0]

        ts = session_start

        for step in funnel:
            # timestamp 증가
            ts = next_ts(ts)

            # discount event 판단
            event_weekday = ts.strftime("%a")
            is_discount = (event_weekday == product_discount_day)

            events.append({
                "event_id": event_id_counter,
                "user_id": user_id,
                "session_id": session_id,
                "event_type": step,
                "event_timestamp": ts,
                "product_id": product_id if step in ["view_product", "add_to_cart"] else None,
                "device": device,
                "referrer": pick_referrer(step),
                "is_discount_event": is_discount,
                "anomaly_flag": False
            })
            event_id_counter += 1

        # PURCHASE ALIGN with order_date for realism
        if "purchase" in funnel and len(user_orders) > 0:
            sample_order = user_orders.sample(1).iloc[0]
            od = datetime.strptime(sample_order["order_date"], "%Y-%m-%d")
            purchase_ts = od + timedelta(hours=np.random.randint(10, 23))
            
            events.append({
                "event_id": event_id_counter,
                "user_id": user_id,
                "session_id": session_id,
                "event_type": "purchase",
                "event_timestamp": purchase_ts,
                "product_id": None,
                "device": device,
                "referrer": "checkout",
                "is_discount_event": (purchase_ts.strftime("%a") == product_discount_day),
                "anomaly_flag": False
            })
            event_id_counter += 1

    # Add anomaly events (2%)
    anomaly_count = int(np.random.binomial(10, 0.2))  # 평균 2개 정도
    for _ in range(anomaly_count):
        anomaly_ev = generate_anomaly_event(user_id)
        anomaly_ev["event_id"] = event_id_counter
        event_id_counter += 1
        events.append(anomaly_ev)


# ============================================================
# 4) Export user_events.csv
# ============================================================

events_df = pd.DataFrame(events)
events_df.to_csv("user_events.csv", index=False)

print(" user_events.csv 생성 완료!")
print(f"총 이벤트 수: {len(events_df):,}")


# In[3]:





# In[ ]:




