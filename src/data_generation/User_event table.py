#!/usr/bin/env python
# coding: utf-8

# In[1]:


import numpy as np
import pandas as pd
from datetime import timedelta
import uuid


# In[2]:


# -------------------------
# Load Data
# -------------------------
orders = pd.read_csv("orders.csv")
products = pd.read_csv("products.csv")
users = pd.read_csv("users.csv")

product_ids = products["product_id"].tolist()

# -------------------------
# Helper functions
# -------------------------

def random_ts_near(date, hours=48):
    """주어진 날짜 주변에서 random timestamp 생성"""
    delta = np.random.randint(-hours, hours)
    return pd.Timestamp(date) + timedelta(hours=int(delta))

def event_probabilities():
    """Funnel 전환 확률"""
    return {
        "add_cart": 0.25,
        "checkout": 0.13,
        "payment_attempt": 0.10,
        "purchase": 0.06
    }

referrers = ["direct", "search", "ads", "push"]
ref_probs = [0.55, 0.25, 0.10, 0.10]

# -------------------------
# Event generation
# -------------------------

events = []
event_id = 1

for _, u in users.iterrows():

    # 1) 기본적으로 모든 유저는 view 이벤트 포함
    n_views = np.random.randint(3, 15) if u.subscription_type != "Free" else np.random.randint(2, 8)

    for _ in range(n_views):
        events.append([
            event_id,
            u.user_id,
            "view",
            np.random.choice(product_ids),
            random_ts_near(u.signup_date, 2000),
            np.random.choice(referrers, p=ref_probs),
            str(uuid.uuid4())[:8]
        ])
        event_id += 1

    # 2) 구매 있는 유저만 funnel 이벤트 생성
    user_orders = orders[orders["user_id"] == u.user_id]

    for _, o in user_orders.iterrows():
        base_time = pd.Timestamp(o["order_date"])

        # Product 선택
        p = np.random.choice(product_ids)

        # Funnel 확률
        probs = event_probabilities()

        # --- add_to_cart ---
        if np.random.rand() < probs["add_cart"]:
            add_ts = random_ts_near(base_time, 48)
            events.append([event_id, u.user_id, "add_to_cart", p, add_ts,
                           np.random.choice(referrers, p=ref_probs),
                           str(uuid.uuid4())[:8]])
            event_id += 1

            # --- checkout ---
            if np.random.rand() < probs["checkout"]:
                checkout_ts = add_ts + timedelta(hours=np.random.randint(1, 24))
                events.append([event_id, u.user_id, "checkout", p, checkout_ts,
                               np.random.choice(referrers, p=ref_probs),
                               str(uuid.uuid4())[:8]])
                event_id += 1

                # --- payment attempt ---
                if np.random.rand() < probs["payment_attempt"]:
                    pay_ts = checkout_ts + timedelta(hours=np.random.randint(1, 10))
                    events.append([event_id, u.user_id, "payment_attempt", p, pay_ts,
                                   np.random.choice(referrers, p=ref_probs),
                                   str(uuid.uuid4())[:8]])
                    event_id += 1

                    # --- purchase ---
                    if np.random.rand() < probs["purchase"]:
                        pur_ts = pay_ts + timedelta(hours=np.random.randint(1, 5))
                        events.append([event_id, u.user_id, "purchase", p, pur_ts,
                                       np.random.choice(referrers, p=ref_probs),
                                       str(uuid.uuid4())[:8]])
                        event_id += 1



events_df = pd.DataFrame(events, columns=[
    "event_id", "user_id", "event_type", "product_id", "event_time", "referrer", "session_id"
])

events_df.head()


# In[3]:


# -------------------------
# Save
# -------------------------
events_df.to_csv("user_events.csv", index=False)


# In[ ]:




