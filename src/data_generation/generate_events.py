# -*- coding: utf-8 -*-
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

from data_generation import config


def _read_csv_safe(path: Path, date_cols: list[str] | None = None) -> pd.DataFrame:
    df = pd.read_csv(
        path,
        dtype="string",
        keep_default_na=True,
        na_values=["", "NA", "NaN", "null", "None"],
        low_memory=False,
    )
    if date_cols:
        for c in date_cols:
            if c in df.columns:
                df[c] = pd.to_datetime(df[c], errors="coerce")
    return df


def _ensure_parent_dir(p: Path) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)


def _sample_sched_prob(sched: list[tuple[int, int, float]], day_idx: int) -> float:
    for s, e, p in sched:
        if s <= day_idx <= e:
            return float(p)
    return float(sched[-1][2])


def generate_events(
    users_path: Path,
    sessions_path: Path,
    products_path: Path,
    out_path: Path,
    seed: int = config.SEED,
    max_view_events_per_session: int | None = None,
) -> pd.DataFrame:
    """
    session 기반 events 생성 (view->click->add_to_cart->checkout->purchase)

    FIXED:
    - checkout을 intent gate만 통과하면 무조건 찍던 버그 제거
    - quick path에서도 add_to_cart 이벤트를 반드시 찍어 funnel 일관성 보장
      (checkout 수가 cart 수보다 커지는 현상 방지)
    - repeat intent gate는 checkout 확률 통과 이후에 적용
    """
    rng = np.random.default_rng(seed)

    users = _read_csv_safe(users_path, date_cols=["signup_date"])
    sessions = _read_csv_safe(sessions_path, date_cols=["session_start_ts"])
    products = _read_csv_safe(products_path)

    max_view_events_per_session = int(max_view_events_per_session or getattr(config, "MAX_VIEW_EVENTS_PER_SESSION", 2))
    purchase_prob_cap = float(getattr(config, "PURCHASE_PROB_CAP", 0.85))
    quick_checkout_multiplier = float(getattr(config, "QUICK_CHECKOUT_MULTIPLIER", 0.60))

    # lookup
    user_signup = dict(zip(users["user_id"].astype(str), pd.to_datetime(users["signup_date"], errors="coerce")))
    user_type = dict(zip(users["user_id"].astype(str), users["user_type"].astype(str)))
    user_device = dict(zip(users["user_id"].astype(str), users["device"].astype(str)))

    # =========================
    # per-user heavy-tail + per-user cap scaling
    # =========================
    uid_list = users["user_id"].astype(str).tolist()

    sigma = float(getattr(config, "USER_PURCHASE_MULT_SIGMA", 0.9))
    floor = float(getattr(config, "USER_PURCHASE_MULT_FLOOR", 0.40))
    mult_cap = float(getattr(config, "USER_PURCHASE_MULT_CAP", 3.0))

    cap_power = float(getattr(config, "USER_PURCHASE_CAP_POWER", 0.75))
    cap_mult_max = float(getattr(config, "USER_PURCHASE_CAP_MULT_MAX", 2.0))

    raw = rng.lognormal(mean=0.0, sigma=sigma, size=len(uid_list))
    raw = raw / raw.mean()  # 전체 평균 1로 스케일
    user_mult = np.clip(raw, floor, mult_cap)

    user_buy_mult = dict(zip(uid_list, user_mult))
    user_cap_mult = dict(zip(uid_list, np.clip(user_mult ** cap_power, 1.0, cap_mult_max)))

    product_ids = products["product_id"].astype(str).tolist()
    if not product_ids:
        raise ValueError("products is empty.")

    # first purchase targeting
    first_purchase_day: dict[str, int] = {}
    first_purchase_target: dict[str, int | None] = {}
    for uid, ut in user_type.items():
        rr = config.FIRST_PURCHASE_TARGET.get(ut)
        if rr is None:
            first_purchase_target[uid] = None
        else:
            lo, hi = rr
            first_purchase_target[uid] = int(rng.integers(lo, hi + 1))

    # chunk write
    _ensure_parent_dir(Path(out_path))
    first_write = True
    chunk_flush_n = 200_000

    events_rows: list[dict] = []
    e_id = 0
    order_seq = 0

    def flush():
        nonlocal events_rows, first_write
        if not events_rows:
            return
        df = pd.DataFrame(events_rows)
        df.to_csv(out_path, index=False, mode="w" if first_write else "a", header=first_write)
        first_write = False
        events_rows = []

    # sessions required
    for col in ["session_id", "user_id", "session_start_ts"]:
        if col not in sessions.columns:
            raise ValueError(f"sessions missing column: {col}")

    for s in sessions.itertuples(index=False):
        uid = str(s.user_id)
        sid = str(s.session_id)

        st = pd.to_datetime(s.session_start_ts, errors="coerce")
        if pd.isna(st):
            continue

        ut = str(getattr(s, "user_type", user_type.get(uid, "B")))
        device = str(getattr(s, "device", user_device.get(uid, "Web")))

        is_promo = int(getattr(s, "is_promo", 0) or 0)
        promo_id = getattr(s, "promo_id", None)
        promo_id = None if (promo_id is None or str(promo_id) in ["<NA>", "nan", "None"]) else str(promo_id)
        discount_rate = float(getattr(s, "discount_rate", 0.0) or 0.0)

        signup = user_signup.get(uid)
        if signup is None or pd.isna(signup):
            continue

        day_idx = int((st.normalize() - signup.normalize()).days)
        day_idx = max(day_idx, 0)

        primary_pid = product_ids[int(rng.integers(0, len(product_ids)))]

        # ---------------------------
        # view (cap)
        # ---------------------------
        lam = float(config.VIEWS_LAMBDA.get(ut, 4))
        k_views = int(rng.poisson(lam))
        k_views = max(1, min(k_views, max_view_events_per_session))

        t = st
        for _ in range(k_views):
            e_id += 1
            t = t + pd.Timedelta(seconds=int(rng.integers(5, 40)))
            events_rows.append(
                {
                    "event_id": f"E_{e_id}",
                    "user_id": uid,
                    "event_ts": t,
                    "event_type": "view",
                    "session_id": sid,
                    "device": device,
                    "order_id": None,
                    "product_id": primary_pid,
                    "is_promo": is_promo,
                    "discount_rate": discount_rate if is_promo else 0.0,
                    "promo_id": promo_id,
                }
            )

        # ---------------------------
        # click
        # ---------------------------
        if rng.random() >= float(config.CLICK_RATE.get(ut, 0.30)):
            if len(events_rows) >= chunk_flush_n:
                flush()
            continue

        e_id += 1
        t = t + pd.Timedelta(seconds=int(rng.integers(5, 30)))
        events_rows.append(
            {
                "event_id": f"E_{e_id}",
                "user_id": uid,
                "event_ts": t,
                "event_type": "click",
                "session_id": sid,
                "device": device,
                "order_id": None,
                "product_id": primary_pid,
                "is_promo": is_promo,
                "discount_rate": discount_rate if is_promo else 0.0,
                "promo_id": promo_id,
            }
        )

        # ---------------------------
        # quick path 결정
        # ---------------------------
        q_lo, q_hi = config.P_QUICK_PATH.get(ut, (0.0, 0.0))
        quick_p = float(rng.uniform(q_lo, q_hi)) if q_hi > 0 else 0.0
        quick = (rng.random() < quick_p)

        # ---------------------------
        # add_to_cart
        # - standard: 확률로
        # - quick: "반드시" 찍어서 funnel 일관성 유지 (checkout>cart 방지)
        # ---------------------------
        if quick:
            has_cart = True
        else:
            has_cart = (rng.random() < float(config.P_CART_GIVEN_CLICK.get(ut, 0.15)))

        if not has_cart:
            if len(events_rows) >= chunk_flush_n:
                flush()
            continue

        e_id += 1
        t = t + pd.Timedelta(seconds=int(rng.integers(10, 60)))
        events_rows.append(
            {
                "event_id": f"E_{e_id}",
                "user_id": uid,
                "event_ts": t,
                "event_type": "add_to_cart",
                "session_id": sid,
                "device": device,
                "order_id": None,
                "product_id": primary_pid,
                "is_promo": is_promo,
                "discount_rate": discount_rate if is_promo else 0.0,
                "promo_id": promo_id,
            }
        )

        # ---------------------------
        # checkout 확률 결정
        # ---------------------------
        base_checkout = float(config.P_CHECKOUT_GIVEN_CART.get(ut, 0.45))
        p_checkout = base_checkout * (quick_checkout_multiplier if quick else 1.0)
        p_checkout = float(np.clip(p_checkout, 0.0, 1.0))

        if rng.random() >= p_checkout:
            if len(events_rows) >= chunk_flush_n:
                flush()
            continue

        # =========================================================
        # PURCHASE INTENT GATE (repeat purchase control)
        # - checkout "직전"에 적용
        # - 첫 구매 전: 통과
        # - 첫 구매 후: P_BUY_SESSION * heavy-tail, cap은 user별 확장
        # =========================================================
        if uid in first_purchase_day:
            delta = day_idx - int(first_purchase_day[uid])
            sched = config.P_BUY_SESSION.get(ut, [(0, config.OBS_DAYS - 1, 0.02)])

            p_intent = float(_sample_sched_prob(sched, max(delta, 0)))
            p_intent *= float(user_buy_mult.get(uid, 1.0))
            p_intent *= float(getattr(config, "REPEAT_INTENT_GLOBAL_MULT", 1.0))  # ✅ 추가: 평균 repeat 살리기
            base_cap = float(config.P_BUY_CAP.get(ut, 0.22))
            per_user_cap = base_cap * float(user_cap_mult.get(uid, 1.0))

            # 절대 상한 (확률 1.0 넘어가거나 과폭주 방지)
            per_user_cap = min(per_user_cap, 0.95)
            p_intent = max(0.0, min(p_intent, per_user_cap))

            if rng.random() >= p_intent:
                if len(events_rows) >= chunk_flush_n:
                    flush()
                continue

        # checkout 기록
        e_id += 1
        t = t + pd.Timedelta(seconds=int(rng.integers(10, 60)))
        events_rows.append(
            {
                "event_id": f"E_{e_id}",
                "user_id": uid,
                "event_ts": t,
                "event_type": "checkout",
                "session_id": sid,
                "device": device,
                "order_id": None,
                "product_id": primary_pid,
                "is_promo": is_promo,
                "discount_rate": discount_rate if is_promo else 0.0,
                "promo_id": promo_id,
            }
        )

        # ---------------------------
        # purchase
        # ---------------------------
        base_p = float(config.P_PURCHASE_GIVEN_CHECKOUT.get(ut, 0.60))

        if is_promo:
            base_p *= float(config.PROMO_UPLIFT.get(ut, 1.0))

        # 첫 구매만 타겟팅
        if uid not in first_purchase_day:
            tgt = first_purchase_target.get(uid)
            if tgt is not None:
                if tgt <= day_idx <= tgt + int(config.TARGET_BOOST_DAYS):
                    base_p *= float(config.TARGET_PURCHASE_BOOST)
                else:
                    base_p *= float(getattr(config, "FIRST_PURCHASE_NON_TARGET_MULT", 0.75))

        base_p = float(np.clip(base_p, 0.0, purchase_prob_cap))

        if rng.random() >= base_p:
            if len(events_rows) >= chunk_flush_n:
                flush()
            continue

        # purchase 기록 + order_id 부여
        order_seq += 1
        order_id = f"O_{order_seq}"

        e_id += 1
        t = t + pd.Timedelta(seconds=int(rng.integers(5, 30)))
        events_rows.append(
            {
                "event_id": f"E_{e_id}",
                "user_id": uid,
                "event_ts": t,
                "event_type": "purchase",
                "session_id": sid,
                "device": device,
                "order_id": order_id,
                "product_id": primary_pid,
                "is_promo": is_promo,
                "discount_rate": discount_rate if is_promo else 0.0,
                "promo_id": promo_id,
            }
        )

        if uid not in first_purchase_day:
            first_purchase_day[uid] = day_idx

        if len(events_rows) >= chunk_flush_n:
            flush()

    flush()
    return pd.read_csv(out_path, nrows=5)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--users_path", type=str, required=True)
    ap.add_argument("--sessions_path", type=str, required=True)
    ap.add_argument("--products_path", type=str, required=True)
    ap.add_argument("--out_path", type=str, required=True)
    ap.add_argument("--seed", type=int, default=config.SEED)
    ap.add_argument("--max_view_events_per_session", type=int, default=getattr(config, "MAX_VIEW_EVENTS_PER_SESSION", 2))
    args = ap.parse_args()

    _ = generate_events(
        users_path=Path(args.users_path),
        sessions_path=Path(args.sessions_path),
        products_path=Path(args.products_path),
        out_path=Path(args.out_path),
        seed=args.seed,
        max_view_events_per_session=args.max_view_events_per_session,
    )
    print(f"[OK] events saved to {args.out_path}")


if __name__ == "__main__":
    main()
