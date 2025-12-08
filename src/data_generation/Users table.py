#!/usr/bin/env python
# coding: utf-8

# In[2]:


import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import random


# In[3]:


# -----------------------------
# 기본 설정
# -----------------------------
NUM_USERS = 30000
TODAY = datetime(2025, 1, 1)

np.random.seed(42)
random.seed(42)

# -----------------------------
# 1) user_id 생성
# -----------------------------
user_ids = np.arange(1, NUM_USERS + 1)

# -----------------------------
# 2) signup_date 생성
#    - 최근 36개월
#    - 최근 18개월 70%
# -----------------------------
months_36 = 36
days_range = months_36 * 30  # 대략적 계산

def generate_signup_date():
    if np.random.rand() < 0.70:  # 최근 18개월
        days = np.random.randint(0, 18 * 30)
    else:  # 그 이전 18개월
        days = np.random.randint(18 * 30, 36 * 30)
    return TODAY - timedelta(days=int(days))

signup_dates = [generate_signup_date() for _ in range(NUM_USERS)]

# -----------------------------
# 3) device
# -----------------------------
device_choices = ["iOS", "Android", "Web"]
device_probs = [0.40, 0.45, 0.15]

devices = np.random.choice(device_choices, size=NUM_USERS, p=device_probs)

# -----------------------------
# 4) region
# -----------------------------
region_choices = ["Seoul", "Gyeonggi", "Other"]
region_probs = [0.38, 0.32, 0.30]

regions = np.random.choice(region_choices, size=NUM_USERS, p=region_probs)

# -----------------------------
# 5) marketing_source
# -----------------------------
marketing_choices = ["Organic", "Paid", "Referral"]
marketing_probs = [0.60, 0.30, 0.10]

marketing_sources = np.random.choice(marketing_choices, size=NUM_USERS, p=marketing_probs)

# -----------------------------
# 6) subscription_type
# -----------------------------
sub_choices = ["Free", "Plus", "Premium"]
sub_probs = [0.65, 0.25, 0.10]

subscription_types = np.random.choice(sub_choices, size=NUM_USERS, p=sub_probs)

# -----------------------------
# 7) subscription_join_date
# -----------------------------
def generate_subscription_join(signup_date, sub_type):
    if sub_type == "Free":
        return None
    elif sub_type == "Plus":
        days_after = np.random.randint(30, 180)
    elif sub_type == "Premium":
        days_after = np.random.randint(10, 90)
    
    join_date = signup_date + timedelta(days=int(days_after))
    return join_date if join_date < TODAY else TODAY

subscription_join_dates = [
    generate_subscription_join(signup_dates[i], subscription_types[i])
    for i in range(NUM_USERS)
]

# -----------------------------
# 8) is_new_user_flag
# -----------------------------
is_new_user = [
    1 if signup_dates[i] > TODAY - timedelta(days=30) else 0
    for i in range(NUM_USERS)
]

# -----------------------------
# 9) anomaly_flag (1% intentionally wrong)
#    → signup_date > first_order_date 만들 때 사용
# -----------------------------
anomaly_flag = np.random.choice([0, 1], size=NUM_USERS, p=[0.99, 0.01])

# -----------------------------
# 최종 DataFrame 생성
# -----------------------------
users_df = pd.DataFrame({
    "user_id": user_ids,
    "signup_date": signup_dates,
    "device": devices,
    "region": regions,
    "marketing_source": marketing_sources,
    "subscription_type": subscription_types,
    "subscription_join_date": subscription_join_dates,
    "is_new_user_flag": is_new_user,
    "anomaly_flag": anomaly_flag
})

users_df.head()


# In[ ]:




