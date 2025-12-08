#!/usr/bin/env python
# coding: utf-8

# In[1]:


import numpy as np
import pandas as pd


# In[2]:


# ------------------------
# Product Spec Definition
# ------------------------

categories = {
    "Furniture": (100000, 300000),
    "Appliances": (80000, 250000),
    "Cleaning": (15000, 120000),
    "Kitchenware": (10000, 70000),
    "Fabric": (20000, 120000),
    "Organizers": (8000, 50000),
    "Deco": (5000, 40000)
}

brands_per_category = {
    "Furniture": ["FurniCo", "HomePlus", "WoodCraft", "FurnHouse", "ModernOak"],
    "Appliances": ["AppliMax", "ElectroCo", "SmartHome", "CleanWave", "EcoTech"],
    "Cleaning": ["CleanPro", "FreshHome", "SweepKing", "EcoWash", "ShineCo"],
    "Kitchenware": ["CookMaster", "KitchenLab", "ChefTools", "HomeCook", "SteelWare"],
    "Fabric": ["SoftTextile", "ComfortWeave", "FabricCo", "WarmNest", "QTextile"],
    "Organizers": ["OrganizeIt", "HomeSort", "Boxy", "NeatHouse", "ArrangeCo"],
    "Deco": ["DecoArt", "HomeDeco", "RoomGlow", "DesignCo", "SparkDecor"]
}

NUM_PRODUCTS = 300

# ------------------------
# Product Generation
# ------------------------

product_list = []
product_id = 1

for category, (low, high) in categories.items():
    
    n_items = NUM_PRODUCTS // len(categories)  # 균등 분포
    
    # 자연스러운 가격 생성 (정규분포 기반)
    mean = (low + high) / 2
    std = (high - low) / 6

    prices = np.random.normal(mean, std, n_items).astype(int)
    prices = np.clip(prices, low, high)  # 가격 범위 밖 제외

    # 브랜드 랜덤 선택
    brand_choices = brands_per_category[category]
    brands = np.random.choice(brand_choices, n_items, replace=True)

    for price, brand in zip(prices, brands):
        product_list.append([product_id, category, price, brand])
        product_id += 1

df_products = pd.DataFrame(product_list, columns=["product_id", "category", "price", "brand"])

# ------------------------
# Price Tier 생성
# ------------------------
df_products["price_tier"] = pd.qcut(df_products["price"], q=[0, 0.2, 0.8, 1],
                                    labels=["low", "mid", "high"])

# ------------------------
# Save
# ------------------------
df_products.to_csv("products.csv", index=False)

df_products.head()

