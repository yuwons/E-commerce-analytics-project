#!/usr/bin/env python
# coding: utf-8

# In[ ]:


# config.py
SEED = 42

OBS_DAYS = 180
SHORT_CONV_DAYS = 14
MID_CONV_DAYS = 30

TYPE_RATIOS = {"A": 0.30, "B": 0.30, "C": 0.25, "D": 0.15}

# Weekly (weekend-heavy): B/D만 강하게
WEEKEND_BOOST = {"A": 0.00, "B": 0.12, "C": 0.02, "D": 0.10}

# Base visit probability
BASE_P_VISIT = {"A": 0.35, "B": 0.18, "C": 0.05, "D": 0.28}

# A decay schedule (day index 기준)
A_DECAY = [(0, 7, 1.00), (8, 30, 0.55), (31, 179, 0.25)]
B_DECAY = [(0, 29, 1.00), (30, 179, 0.90)]
C_DECAY = [(0, 29, 1.00), (30, 179, 0.70)]
D_DECAY = [(0, 179, 0.98)]

# A Burst-Gap-Return
A_BURST_DAYS = (1, 5)               # signup+1 ~ signup+5
A_BURST_P = 0.80
A_GAP_START_RANGE = (10, 25)
A_GAP_LEN_RANGE = (7, 14)
A_GAP_P = 0.05

# Promo: 공통 할인
PROMO_DISCOUNT_RANGE = (0.05, 0.15)
PROMO_EVENTS_PER_YEAR = 5
PROMO_LEN_DAYS = 7

# Session 내 탐색량 평균(views/session)
VIEWS_LAMBDA = {"A": 8, "B": 5, "C": 2, "D": 10}
CLICK_RATE = {"A": 0.30, "B": 0.35, "C": 0.20, "D": 0.40}

# Funnel 확률 (기본 경로)
P_CART_GIVEN_CLICK = {"A": 0.12, "B": 0.20, "C": 0.05, "D": 0.25}
P_CHECKOUT_GIVEN_CART = {"A": 0.75, "B": 0.65, "C": 0.40, "D": 0.75}
P_PURCHASE_GIVEN_CHECKOUT = {"A": 0.65, "B": 0.55, "C": 0.30, "D": 0.70}

# Quick path: view->click->checkout->purchase (add_to_cart 생략)
P_QUICK_PATH = {"A": (0.05, 0.08), "B": (0.005, 0.01), "C": (0.0, 0.0), "D": (0.01, 0.02)}

# First purchase target day (타입별 대략 범위: 구현 시 분포로)
FIRST_PURCHASE_TARGET = {
    "A": (1, 5),
    "B": (10, 30),
    "C": None,
    "D": (7, 14)
}
TARGET_BOOST_DAYS = 3
TARGET_PURCHASE_BOOST = 2.5  # target~target+3 구간에서 checkout->purchase 확률 배수 (cap 걸기)

# Orders / Order_items
AVG_ITEMS_PER_ORDER = {"A": 1.3, "B": 1.4, "C": 1.0, "D": 1.8}
PRICE_MULTIPLIER = {"A": 1.00, "B": 1.05, "C": 0.95, "D": 1.20}

# Repeat purchase: session 기반 p_buy_session (첫 구매 이후)
P_BUY_SESSION = {
    "A": [(0, 14, 0.10), (15, 60, 0.03), (61, 179, 0.01)],
    "B": [(0, 179, 0.05)],
    "C": [(0, 179, 0.005)],
    "D": [(0, 179, 0.08)],
}
PROMO_UPLIFT = {"A": 2.0, "B": 1.15, "C": 1.05, "D": 1.10}
P_BUY_CAP = {"A": 0.25, "B": 0.12, "C": 0.02, "D": 0.18}

# Subscription
ELIG_ORDERS = 2
ELIG_SESSIONS = 6
SUB_BASE_PROB = {"A": 0.03, "B": 0.08, "C": 0.005, "D": 0.15}
SUB_PROB_CAP = 0.30
CONSISTENCY_MULT = 1.2

# Premium condition (Option B)
PREMIUM_MIN_ORDERS_60D = 3
PREMIUM_REVENUE_TOP_PCT = 0.15  # 상위 15%

SUB_OFFSET = {
    "D": (10, 60),
    "B": (20, 90),
    "A": (60, 120),
    "C": None
}

