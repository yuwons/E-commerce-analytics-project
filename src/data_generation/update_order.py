#!/usr/bin/env python
# coding: utf-8

# In[4]:


import pandas as pd

# Load orders & order_items
orders = pd.read_csv("orders.csv")
order_items = pd.read_csv("order_items.csv")

# 1) summary 계산
order_summary = (
    order_items.groupby("order_id")
    .agg(
        total_amount=("line_amount", "sum"),
        is_discount_day=("is_discounted", "max"),
    )
    .reset_index()
)

# 2) merge 시 suffix 처리하여 기존 컬럼과 충돌 막기
updated = orders.merge(order_summary, on="order_id", how="left", suffixes=("", "_new"))

# 3) 기존 total_amount / is_discount_day를 새로운 값으로 교체
updated["total_amount"] = updated["total_amount_new"]
updated["is_discount_day"] = updated["is_discount_day_new"]

# 4) null → default 값 처리
updated["total_amount"] = updated["total_amount"].fillna(0)
updated["is_discount_day"] = updated["is_discount_day"].fillna(False)

# 5) 사용 끝난 임시 컬럼 제거
updated = updated.drop(columns=["total_amount_new", "is_discount_day_new"])

# 6) 저장
updated.to_csv("orders_updated.csv", index=False)

print("완료! orders_updated.csv 생성됨.")


# In[ ]:




