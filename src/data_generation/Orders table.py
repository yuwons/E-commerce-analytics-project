#!/usr/bin/env python
# coding: utf-8

# In[1]:


import pandas as pd
import numpy as np
import random
from datetime import datetime, timedelta


# In[2]:


# -------------------------------
# CONFIG
# -------------------------------

# anomaly 비율: order_date가 signup_date 이전인 주문 (전처리/QA용)
ANOMALY_RATE = 0.01  # 1%

# payment_status 분포
PAYMENT_STATUS_DIST = {
    "Completed": 0.92,
    "Failed": 0.03,
    "Cancelled": 0.05,
}

# 요일 가중치 (주말 주문 더 많게)
# 월=0, 화=1, ... 일=6
WEEKDAY_WEIGHTS = {
    0: 1.0,  # Mon
    1: 1.0,  # Tue
    2: 1.0,  # Wed
    3: 1.0,  # Thu
    4: 1.3,  # Fri
    5: 1.4,  # Sat
    6: 1.2,  # Sun
}

# 월별 seasonality 가중치 (Mid level)
MONTH_WEIGHTS = {
    1: 1.0,  # Jan
    2: 0.8,  # Feb
    3: 0.9,  # Mar
    4: 1.0,  # Apr
    5: 1.0,  # May
    6: 1.0,  # Jun
    7: 1.0,  # Jul
    8: 1.0,  # Aug
    9: 1.0,  # Sep
    10: 1.1, # Oct
    11: 1.2, # Nov
    12: 1.5, # Dec
}

# 구매 횟수 분포 (연간 기준)
# 0회 / 1~2회 / 3~5회 / 6~10회 / 11~20회
BASE_PURCHASE_BUCKETS = [
    {"name": "0",    "min": 0,  "max": 0},
    {"name": "1-2",  "min": 1,  "max": 2},
    {"name": "3-5",  "min": 3,  "max": 5},
    {"name": "6-10", "min": 6,  "max": 10},
    {"name": "11-20","min": 11, "max": 20},
]

# 전체 유저 population 기준 기본 비율
BASE_PURCHASE_PROBS = np.array([0.20, 0.35, 0.25, 0.12, 0.08])

# "신규 유저" 쪽 분포 (가입 최근일수록 이쪽에 가깝게)
NEW_USER_PURCHASE_PROBS = np.array([0.35, 0.40, 0.18, 0.05, 0.02])

# "오래된 유저" 쪽 분포 (가입 오래된 유저일수록 이쪽에 가까움)
OLD_USER_PURCHASE_PROBS = np.array([0.10, 0.30, 0.30, 0.18, 0.12])


# -------------------------------
# Helper functions
# -------------------------------

def load_users(path="users.csv"):
    """
    users.csv 로드
    - signup_date를 날짜 타입으로 파싱
    """
    df = pd.read_csv(path, parse_dates=["signup_date"])
    return df


def compute_global_date_weights(users_df):
    """
    전체 signup_date ~ 오늘(TODAY)까지의 날짜에 대해
    - recency_weight
    - weekday_weight
    - month_weight
    를 곱한 최종 weight를 계산해 둠.
    이후 각 유저별로 signup_date 이후 날짜만 subset해서 사용.
    """
    # 오늘 날짜 (date 타입)
    today = datetime.today().date()

    # 전체 유저 중 가장 이른 signup_date
    min_signup = users_df["signup_date"].min().date()

    # 전체 날짜 범위 생성
    all_dates = pd.date_range(start=min_signup, end=today, freq="D")
    all_dates = all_dates.date  # numpy array of date

    # 각 날짜별 가중치 계산
    weights = []
    for d in all_dates:
        # 1) recency_weight: 최근일수록 가중치 높음
        days_diff = (today - d).days
        if days_diff <= 90:
            recency_weight = 3.0
        elif days_diff <= 360:
            recency_weight = 2.0
        elif days_diff <= 720:
            recency_weight = 1.0
        else:
            recency_weight = 0.5

        # 2) weekday_weight
        weekday = datetime(d.year, d.month, d.day).weekday()  # 0=Mon
        weekday_weight = WEEKDAY_WEIGHTS[weekday]

        # 3) month_weight
        month_weight = MONTH_WEIGHTS[d.month]

        # 최종 weight = recency * weekday * month
        w = recency_weight * weekday_weight * month_weight
        weights.append(w)

    date_weights = pd.DataFrame({
        "date": all_dates,
        "weight": weights
    })

    return date_weights


def interpolate_purchase_probs(age_factor):
    """
    유저의 '가입 경과시간 비율(age_factor)'에 따라
    - NEW_USER_PURCHASE_PROBS (age_factor=0)에 가깝게
    - OLD_USER_PURCHASE_PROBS (age_factor=1)에 가깝게
    선형 보간하여 구매 횟수 분포를 결정.
    """
    # age_factor: 0(완전 신규) ~ 1(가장 오래된 유저)
    probs = (1 - age_factor) * NEW_USER_PURCHASE_PROBS + age_factor * OLD_USER_PURCHASE_PROBS
    probs = probs / probs.sum()  # 정규화
    return probs


def sample_purchase_count(age_factor, rng):
    """
    한 유저에 대해 구매 횟수(orders 수)를 샘플링.
    - age_factor(0~1)에 따라 '신규형' vs '오래된 유저형' 분포 사이에서 보간된 확률 사용
    - bucket 선택 후 해당 bucket의 min~max 범위에서 실제 주문 수 선택
    """
    probs = interpolate_purchase_probs(age_factor)
    bucket_index = rng.choice(len(BASE_PURCHASE_BUCKETS), p=probs)

    bucket = BASE_PURCHASE_BUCKETS[bucket_index]
    if bucket["min"] == bucket["max"]:
        return bucket["min"]
    else:
        return int(rng.integers(bucket["min"], bucket["max"] + 1))


def weighted_choice_dates(date_weights_df, start_date, rng, n_choices=1):
    """
    특정 유저의 signup_date 이후 날짜 중에서
    - date_weights_df의 weight를 기반으로
    - n_choices개의 order_date를 샘플링.

    중복 허용 (동일 날짜에 여러 주문 가능)
    """
    mask = date_weights_df["date"] >= start_date
    cand = date_weights_df.loc[mask]

    if cand.empty:
        # 이론상 거의 없겠지만, 방어 로직: signup_date가 오늘보다 미래인 경우 등
        # 그냥 전체 날짜에서 뽑도록 fallback
        cand = date_weights_df

    weights = cand["weight"].to_numpy()
    dates = cand["date"].to_numpy()
    weights = weights / weights.sum()

    # n_choices개 샘플링 (중복 허용)
    chosen = rng.choice(len(dates), size=n_choices, p=weights)
    chosen_dates = [dates[i] for i in chosen]
    return chosen_dates


def sample_anomaly_date(date_weights_df, signup_date, rng):
    """
    anomaly용 order_date 샘플링:
    - signup_date 이전 날짜 중 하나 선택
    - 날짜가 없다면(이론적 예외) signup_date 이후 날짜에서 뽑도록 fallback
    """
    mask = date_weights_df["date"] < signup_date
    cand = date_weights_df.loc[mask]

    if cand.empty:
        # fallback: signup 이후 중에서 선택
        cand = date_weights_df[date_weights_df["date"] >= signup_date]

    weights = cand["weight"].to_numpy()
    dates = cand["date"].to_numpy()
    weights = weights / weights.sum()

    idx = rng.choice(len(dates), p=weights)
    return dates[idx]


def sample_payment_status(rng):
    """
    payment_status 샘플링:
    - Completed 92%
    - Failed 3%
    - Cancelled 5%
    """
    statuses = list(PAYMENT_STATUS_DIST.keys())
    probs = list(PAYMENT_STATUS_DIST.values())
    return rng.choice(statuses, p=probs)


# -------------------------------
# MAIN GENERATION
# -------------------------------

def generate_orders(users_path="users.csv", output_path="orders.csv", random_seed=42):
    # 랜덤 시드 고정 (재현 가능성 확보)
    rng = np.random.default_rng(random_seed)

    # 1) users 로드
    users_df = load_users(users_path)

    # 기준 날짜: 오늘
    today = datetime.today().date()

    # 2) 전체 날짜에 대한 weight 사전 계산
    date_weights_df = compute_global_date_weights(users_df)

    orders = []
    next_order_id = 1

    # 전체 유저 중 가장 오래된 signup_date
    min_signup = users_df["signup_date"].min().date()
    max_signup = users_df["signup_date"].max().date()
    total_signup_range_days = max((max_signup - min_signup).days, 1)

    # 모든 유저에 대해 반복
    for _, row in users_df.iterrows():
        user_id = int(row["user_id"])
        signup_date = row["signup_date"].date()

        # -----------------------------
        # (1) 유저의 age_factor 계산 (0~1)
        #     - 가장 오래된 유저: age_factor ~ 1
        #     - 가장 최근 유저: age_factor ~ 0
        # -----------------------------
        age_days = (signup_date - min_signup).days
        age_factor = age_days / total_signup_range_days  # 0 ~ 1

        # -----------------------------
        # (2) 구매 횟수(purchase_count) 샘플링
        #     - 0 / 1~2 / 3~5 / 6~10 / 11~20 중 하나
        #     - age_factor를 반영한 분포 사용
        # -----------------------------
        purchase_count = sample_purchase_count(age_factor, rng)

        if purchase_count == 0:
            # 이 유저는 주문이 없음
            continue

        # -----------------------------
        # (3) 각 주문에 대한 order_date / payment_status / anomaly_flag 생성
        # -----------------------------
        # 우선 정상적인 order_date들을 weight 기반으로 뽑아놓고,
        # anomaly로 뽑히는 주문만 별도 처리
        normal_dates = weighted_choice_dates(
            date_weights_df=date_weights_df,
            start_date=signup_date,
            rng=rng,
            n_choices=purchase_count
        )

        for i in range(purchase_count):
            # 기본적으로 normal 설정
            order_date = normal_dates[i]
            anomaly_flag = 0

            # anomaly인지 여부 결정 (1% 확률)
            if rng.random() < ANOMALY_RATE:
                # signup_date 이전 날짜에서 하나 선택
                order_date = sample_anomaly_date(date_weights_df, signup_date, rng)
                anomaly_flag = 1

            # payment_status 샘플링
            payment_status = sample_payment_status(rng)

            # -----------------------------
            # (4) Orders 테이블 컬럼 생성
            # -----------------------------
            # order_id: 전체 데이터셋에서 unique ID
            current_order_id = next_order_id
            next_order_id += 1

            # user_id: FK
            # 이미 user_id 변수에 있음

            # order_date: 위에서 생성한 날짜 (signup_date 이후, 또는 anomaly)
            # total_amount: 현재 단계에서는 0으로 초기화
            #   -> 나중에 order_items 생성 후 다시 계산하여 업데이트할 예정
            total_amount = 0.0

            # is_discount_day:
            #   현재 단계에서는 False로 초기화
            #   -> 나중에 order_items + products.discount_day_of_week를 보고 다시 계산
            is_discount_day = False

            # anomaly_flag: 1% 비율로 signup 이전 order_date를 가진 주문
            # payment_status: Completed / Failed / Cancelled

            orders.append([
                current_order_id,   # order_id (INT, PK)
                user_id,            # user_id (INT, FK)
                order_date,         # order_date (DATE)
                total_amount,       # total_amount (FLOAT, placeholder)
                is_discount_day,    # is_discount_day (BOOL, placeholder)
                payment_status,     # payment_status (STRING)
                anomaly_flag        # anomaly_flag (INT)
            ])

    # DataFrame으로 변환
    orders_df = pd.DataFrame(orders, columns=[
        "order_id",
        "user_id",
        "order_date",
        "total_amount",
        "is_discount_day",
        "payment_status",
        "anomaly_flag"
    ])

    # CSV 저장
    orders_df.to_csv(output_path, index=False, encoding="utf-8-sig")
    print(f"{output_path} 생성 완료! 총 주문 수: {len(orders_df):,} 건")


if __name__ == "__main__":
    generate_orders()


# In[6]:





# In[ ]:




