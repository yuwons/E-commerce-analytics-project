# config.py
# =========================
# Global
# =========================
SEED = 42

# Observation window (per-user, signup 기준)
OBS_DAYS = 180
SHORT_CONV_DAYS = 14
MID_CONV_DAYS = 30

REPEAT_INTENT_GLOBAL_MULT = 1.35

# =========================
# User Types
# =========================
TYPE_RATIOS = {"A": 0.30, "B": 0.30, "C": 0.25, "D": 0.15}

WEEKEND_BOOST = {"A": 0.00, "B": 0.12, "C": 0.02, "D": 0.10}
BASE_P_VISIT = {"A": 0.35, "B": 0.18, "C": 0.05, "D": 0.28}

A_DECAY = [(0, 7, 1.00), (8, 30, 0.55), (31, 179, 0.25)]
B_DECAY = [(0, 29, 1.00), (30, 179, 0.90)]
C_DECAY = [(0, 29, 1.00), (30, 179, 0.70)]
D_DECAY = [(0, 179, 0.98)]

A_BURST_DAYS = (1, 5)
A_BURST_P = 0.80
A_GAP_START_RANGE = (10, 25)
A_GAP_LEN_RANGE = (7, 14)
A_GAP_P = 0.05

# =========================
# Promo Calendar
# =========================
PROMO_DISCOUNT_RANGE = (0.05, 0.15)
PROMO_EVENTS_PER_YEAR = 5
PROMO_LEN_DAYS = 7

# =========================
# Session / Engagement
# =========================
VIEWS_LAMBDA = {"A": 8, "B": 5, "C": 2, "D": 10}

# 목표: view→click 19~20% 근접 (너가 합의한 수준)
CLICK_RATE = {"A": 0.35, "B": 0.40, "C": 0.20, "D": 0.45}

# =========================
# Funnel probabilities (base path)
# view -> click -> add_to_cart -> checkout -> purchase
# =========================
# 목표: click→cart 20~23% 근접
P_CART_GIVEN_CLICK = {"A": 0.14, "B": 0.25, "C": 0.05, "D": 0.30}

# 목표: cart→checkout 30~40% (현실/분석 균형)
P_CHECKOUT_GIVEN_CART = {"A": 0.45, "B": 0.48, "C": 0.30, "D": 0.55}

# 목표: checkout→purchase 60~70%
P_PURCHASE_GIVEN_CHECKOUT = {"A": 0.68, "B": 0.62, "C": 0.50, "D": 0.70}

# checkout→purchase 상한 (프로모/타깃 부스트 폭주 방지)
PURCHASE_PROB_CAP = 0.85

# Quick path (내부적으로 “cart 확률을 스킵”하는 용도)
# ⚠️ 코드에서 checkout이 cart 없이 찍히지 않도록, quick에서도 add_to_cart 이벤트를 "반드시" 찍게 수정함
P_QUICK_PATH = {
    "A": (0.05, 0.08),
    "B": (0.005, 0.01),
    "C": (0.0, 0.0),
    "D": (0.01, 0.02),
}

# quick이면 checkout 확률을 깎아서(보통 더 낮게) 과도한 quick-checkout 폭주를 막음
QUICK_CHECKOUT_MULTIPLIER = 0.60

# =========================
# First purchase targeting
# =========================
FIRST_PURCHASE_TARGET = {"A": (1, 5), "B": (7, 21), "C": None, "D": (5, 12)}
TARGET_BOOST_DAYS = 3

# 타깃부스트는 과하면 왜곡됨 (1.6~2.0 권장)
TARGET_PURCHASE_BOOST = 1.7

# 타깃 기간 밖 첫구매 확률을 약하게 낮춤 (신규구매 과다 방지)
FIRST_PURCHASE_NON_TARGET_MULT = 0.90

# =========================
# Orders / Order_items
# =========================
AVG_ITEMS_PER_ORDER = {"A": 1.3, "B": 1.4, "C": 1.0, "D": 1.8}
PRICE_MULTIPLIER = {"A": 1.00, "B": 1.05, "C": 0.95, "D": 1.20}

# =========================
# Heavy-tail control (per-user purchase propensity)
# =========================
# (폭주 방지쪽으로 약간 보수적으로)
USER_PURCHASE_MULT_SIGMA = 1.25
USER_PURCHASE_MULT_FLOOR = 0.35
USER_PURCHASE_MULT_CAP = 5.0

# cap도 유저별로 같이 늘리기 (효과 핵심)
USER_PURCHASE_CAP_POWER = 0.90
USER_PURCHASE_CAP_MULT_MAX = 5.0

# =========================
# Repeat purchase: session 기반 p_buy_session (첫 구매 이후)
# =========================
P_BUY_SESSION = {
    "A": [(0, 14, 0.14), (15, 60, 0.08), (61, 179, 0.03)],
    "B": [(0, 179, 0.24)],
    "C": [(0, 179, 0.04)],
    "D": [(0, 179, 0.36)],
}

PROMO_UPLIFT = {"A": 2.0, "B": 1.15, "C": 1.05, "D": 1.10}

# base cap (유저별 cap_mult가 곱해지므로 base는 너무 높이면 폭발함)
P_BUY_CAP = {"A": 0.35, "B": 0.32, "C": 0.18, "D": 0.45}

# =========================
# Subscription
# =========================
ELIG_ORDERS = 2
ELIG_SESSIONS = 6
SUB_BASE_PROB = {"A": 0.03, "B": 0.08, "C": 0.005, "D": 0.15}
SUB_PROB_CAP = 0.30
CONSISTENCY_MULT = 1.2

PREMIUM_MIN_ORDERS_60D = 3
PREMIUM_REVENUE_TOP_PCT = 0.15

SUB_OFFSET = {"D": (10, 60), "B": (20, 90), "A": (60, 120), "C": None}

# =========================
# Products
# =========================
PRODUCTS_N = 300

CATEGORIES = ["Furniture", "Appliances", "Kitchenware", "Fabric", "Organizers", "Deco", "Cleaning"]

CATEGORY_WEIGHTS = {
    "Furniture": 0.14,
    "Appliances": 0.12,
    "Kitchenware": 0.18,
    "Fabric": 0.16,
    "Organizers": 0.16,
    "Deco": 0.14,
    "Cleaning": 0.10,
}

PRICE_LN_PARAMS = {
    "Furniture": {"median": 280_000, "sigma": 0.55},
    "Appliances": {"median": 220_000, "sigma": 0.50},
    "Kitchenware": {"median": 50_000, "sigma": 0.55},
    "Fabric": {"median": 38_000, "sigma": 0.60},
    "Organizers": {"median": 28_000, "sigma": 0.55},
    "Deco": {"median": 25_000, "sigma": 0.65},
    "Cleaning": {"median": 18_000, "sigma": 0.45},
}

PRICE_CAP = {
    "Furniture": 2_000_000,
    "Appliances": 1_500_000,
    "Kitchenware": 300_000,
    "Fabric": 250_000,
    "Organizers": 200_000,
    "Deco": 300_000,
    "Cleaning": 150_000,
}

RATING_MEAN = 4.2
RATING_STD = 0.5
NEW_ARRIVAL_RATE = 0.20
