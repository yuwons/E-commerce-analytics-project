#!/usr/bin/env python
# coding: utf-8

# In[4]:


import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import random


# In[5]:


# -------------------------------
# CONFIG
# -------------------------------

# 생성할 유저 수 (원하면 숫자 조정해서 사용)
NUM_USERS = 50000
# 기준일 (실행 시점 기준 오늘 날짜)
TODAY = datetime.today()

# 가입일 날짜 범위 설정: 최근 36개월
MONTHS = 36
# 최근 18개월 비중: 70%
RECENT_WEIGHT = 0.70   # 최근 18개월 비중

# 디바이스 분포
DEVICE_DIST = {"iOS": 0.40, "Android": 0.45, "Web": 0.15}
# 지역 분포
REGION_DIST = {"Seoul": 0.38, "Gyeonggi": 0.32, "Other": 0.30}
# 마케팅 유입 채널 분포
MKT_DIST = {"Organic": 0.60, "Paid": 0.30, "Referral": 0.10}
# 구독 타입 분포
SUBS_DIST = {"Free": 0.65, "Plus": 0.25, "Premium": 0.10}


# -------------------------------
# Helper functions
# -------------------------------

def generate_signup_date():
    """
    signup_date 생성 로직
    - 최근 36개월 안에서 날짜 선택
    - 이 중 70%는 최근 18개월에 몰리도록 비중 조정
    """
    # 최근 18개월 시작일
    cutoff_recent = TODAY - timedelta(days=18 * 30)
    # 36개월 전 시작일
    cutoff_36m = TODAY - timedelta(days=36 * 30)

    if random.random() < RECENT_WEIGHT:
        # 최근 18개월 구간에서 랜덤 날짜 선택
        days_range = (TODAY - cutoff_recent).days
        return cutoff_recent + timedelta(days=random.randint(0, days_range))
    else:
        # 이전 18~36개월 구간에서 랜덤 날짜 선택
        days_range = (cutoff_recent - cutoff_36m).days
        return cutoff_36m + timedelta(days=random.randint(0, days_range))


def pick_with_prob(dist_dict):
    """
    주어진 분포(dist_dict)에 따라 key 하나를 확률적으로 선택
    예: {"iOS": 0.4, "Android": 0.45, "Web": 0.15}
    """
    return np.random.choice(list(dist_dict.keys()), p=list(dist_dict.values()))


def generate_subscription_join(signup_date, subscription_type):
    """
    subscription_join_date 생성 로직
    - Plus: signup_date + 30~180일
    - Premium: signup_date + 10~90일
    - Free: None (구독 가입일 없음)
    """
    if subscription_type == "Plus":
        offset = random.randint(30, 180)
        return signup_date + timedelta(days=offset)
    elif subscription_type == "Premium":
        offset = random.randint(10, 90)
        return signup_date + timedelta(days=offset)
    else:
        return None


# -------------------------------
# MAIN GENERATION
# -------------------------------

def generate_users(num_users=NUM_USERS):
    # 각 유저 row를 담을 리스트
    users = []

    for uid in range(1, num_users + 1):
        # user_id: 1부터 시작하는 고유 정수 ID (PK)
        user_id = uid

        # signup_date: 위 helper 함수 로직으로 생성 (최근 36개월, 70% 최근 18개월)
        signup_date = generate_signup_date()

        # device: iOS / Android / Web 비율에 맞게 샘플링
        device = pick_with_prob(DEVICE_DIST)

        # region: Seoul / Gyeonggi / Other 비율에 맞게 샘플링
        region = pick_with_prob(REGION_DIST)

        # marketing_source: Organic / Paid / Referral 비율에 맞게 샘플링
        mkt = pick_with_prob(MKT_DIST)

        # subscription_type: Free / Plus / Premium 비율에 맞게 샘플링
        subs = pick_with_prob(SUBS_DIST)

        # subscription_join_date:
        # - Free: None
        # - Plus: signup 이후 30~180일 사이
        # - Premium: signup 이후 10~90일 사이
        subscription_join_date = generate_subscription_join(signup_date, subs)

        # is_new_user_flag:
        # - 가입 후 45일 이내의 유저면 True
        #   (기존 30일 → 45일로 변경)
        is_new = (TODAY - signup_date).days <= 45

        # anomaly_flag:
        # - 1% 확률로 1 (이상치 플래그), 나머지는 0
        anomaly = 1 if random.random() < 0.01 else 0

        # users 리스트에 한 유저 row 추가
        # 각 요소는 Golden Schema의 컬럼 순서를 그대로 따라감
        users.append([
            user_id,                                             # user_id (INT, PK)
            signup_date.date(),                                  # signup_date (DATE)
            device,                                              # device (STRING)
            region,                                              # region (STRING)
            mkt,                                                 # marketing_source (STRING)
            subs,                                                # subscription_type (STRING)
            subscription_join_date.date() if subscription_join_date else None,  # subscription_join_date (DATE or None)
            is_new,                                              # is_new_user_flag (BOOL)
            anomaly                                              # anomaly_flag (INT)
        ])

    # DataFrame 생성: 컬럼명은 Golden Schema v1.0에 맞게 정의
    df = pd.DataFrame(users, columns=[
        "user_id",                # 유저 PK
        "signup_date",            # 가입일
        "device",                 # 디바이스 (iOS/Android/Web)
        "region",                 # 지역 (Seoul/Gyeonggi/Other)
        "marketing_source",       # 유입 채널 (Organic/Paid/Referral)
        "subscription_type",      # 구독 타입 (Free/Plus/Premium)
        "subscription_join_date", # 구독 가입일 (Free인 경우 NULL)
        "is_new_user_flag",       # 가입 후 45일 이내 유저 여부
        "anomaly_flag"            # 이상치 플래그 (1% 정도)
    ])

    return df


if __name__ == "__main__":
    # 메인 실행: users 데이터 생성
    df = generate_users()

    # CSV 파일로 저장 (utf-8-sig: 엑셀에서 한글 안깨지게)
    df.to_csv("users.csv", index=False, encoding="utf-8-sig")
    print("users.csv 생성 완료!")


# In[6]:


df.head()


# In[ ]:




