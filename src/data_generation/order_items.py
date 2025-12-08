#!/usr/bin/env python
# coding: utf-8

# In[1]:


import numpy as np
import pandas as pd


# In[3]:


# -------------------------
# Load Orders & Products
# -------------------------
orders = pd.read_csv("orders.csv")
products = pd.read_csv("products.csv")

# 상품 가격 / 카테고리 lookup
product_lookup = products.set_index("product_id")

# 각 주문에 대해 몇 개의 상품 포함할지 분포 정의
item_count_probs = [0.55, 0.25, 0.15, 0.05]
item_count_values = [1, 2, 3, 4]

def get_item_count():
    return np.random.choice(item_count_values, p=item_count_probs)

# -------------------------
# Order Items 생성
# -------------------------

order_items_list = []
order_item_id = 1

for _, row in orders.iterrows():
    order_id = row.order_id
    n_items = get_item_count()
    
    chosen_products = np.random.choice(products["product_id"], size=n_items, replace=False)

    for pid in chosen_products:
        price = product_lookup.loc[pid, "price"]
        category = product_lookup.loc[pid, "category"]
        price_tier = product_lookup.loc[pid, "price_tier"]
        
        qty = np.random.choice([1, 2, 3], p=[0.85, 0.10, 0.05])

        order_items_list.append([
            order_item_id,
            order_id,
            pid,
            category,
            price,
            price_tier,
            qty
        ])
        order_item_id += 1

order_items = pd.DataFrame(order_items_list, columns=[
    "order_item_id", "order_id", "product_id", "category", "price", "price_tier", "quantity"
])

# -------------------------
# Total Amount 업데이트
# -------------------------

order_amounts = order_items.groupby("order_id").apply(
    lambda df: (df["price"] * df["quantity"]).sum()
)

orders["total_amount"] = orders["order_id"].map(order_amounts)


order_items.head()


# In[4]:



# Save
order_items.to_csv("order_items.csv", index=False)
orders.to_csv("orders.csv", index=False)


# In[ ]:




