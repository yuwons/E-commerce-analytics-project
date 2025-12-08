#!/usr/bin/env python
# coding: utf-8

# In[1]:


import numpy as np
import pandas as pd


# In[5]:


# -------------------------
# Load Users
# -------------------------
users = pd.read_csv("users.csv")

# 구매 횟수 분포 (power-law 기반)
purchase_probs = [0.18, 0.40, 0.25, 0.17]
purchase_bins = [0, 1, 3, 6, 12]  # 0, 1-2, 3-5, 6-11

users["purchase_count"] = np.random.choice(
    [0, 1, 3, 6],  # 시작 인덱스
    size=len(users),
    p=purchase_probs
)

# 1~11 사이로 구매 횟수 랜덤 fine tuning
users["purchase_count"] = users.apply(
    lambda row: 0 if row.purchase_count == 0 else
    np.random.randint(row.purchase_count, row.purchase_count + (3 if row.purchase_count < 6 else 6)),
    axis=1
)

# -------------------------
# Order Date Generation
# -------------------------

def generate_order_dates(n):
    """주문 날짜 생성: 최근일수록 확률 ↑ + 요일별 seasonality"""
    dates = pd.date_range(end=pd.Timestamp.today(), periods=36*30)
    probs = np.linspace(0.3, 1.0, len(dates))  # 최근일수록 높음
    probs /= probs.sum()

    chosen_dates = np.random.choice(dates, size=n, p=probs)

    result = []
    for d in chosen_dates:
        d = pd.Timestamp(d)   # numpy.datetime64 → pandas.Timestamp 변환

        # 요일 seasonality 조정
        if d.weekday() >= 5:  # 토/일
            if np.random.rand() < 0.35:
                d = d + pd.Timedelta(hours=np.random.randint(1, 12))

        result.append(d)

    return result

# -------------------------
# Orders 생성
# -------------------------

orders_list = []
order_id = 1

for idx, row in users.iterrows():
    n_orders = row.purchase_count
    for _ in range(n_orders):
        orders_list.append([
            order_id,
            row.user_id,
            None,  # 나중에 order_items에서 채움
            row.signup_date,  # anomaly 용, 뒤에서 수정됨
        ])
        order_id += 1

orders = pd.DataFrame(orders_list, columns=["order_id", "user_id", "total_amount", "order_date"])

# 주문 날짜 부여
orders["order_date"] = generate_order_dates(len(orders))

# anomaly 1% 적용 (signup_date 이후보다 빠른 주문)
anomaly_idx = orders.sample(frac=0.01).index
orders.loc[anomaly_idx, "order_date"] = orders.loc[anomaly_idx, "order_date"] - pd.Timedelta(days=np.random.randint(1, 30))

# payment status
orders["payment_attempted"] = np.random.choice([1, 0], size=len(orders), p=[0.98, 0.02])
orders["payment_status"] = orders["payment_attempted"].apply(lambda x: 1 if x == 1 and np.random.rand() < 0.96 else 0)

orders.head()


# In[6]:


# Save
orders.to_csv("orders.csv", index=False)


# In[ ]:




