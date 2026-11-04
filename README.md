# 🛒 E-commerce Sales Analysis | MySQL + Power BI

End-to-end analysis of an e-commerce dataset: data cleaning in MySQL, 20 business questions solved with SQL, and a 3-page interactive Power BI dashboard.

> **Note:** The dataset is synthetic and was created for practice purposes.

---

## 📌 Project Overview

| Item | Details |
|------|---------|
| Database | MySQL (14 tables) |
| Visualization | Power BI (3-page dashboard) |
| Business Questions | 20 (Sales, Customers, Operations, Marketing) |
| Total Revenue | 579M |
| Total Profit | 151M (26.13% margin) |

---

## 🛠️ Tools & Skills Used

- **MySQL:** Joins, CTAS, subqueries, window functions (`LAG`, `DENSE_RANK`), aggregations, views
- **Power BI:** Data modeling, DAX measures, interactive dashboards, slicers
- **Data Cleaning:** Duplicate flags, NULL handling, date validation

---

## 🧹 Data Cleaning (SQL)

Created clean analytical tables from raw data:

- `clean_order_items`: one row per order line (revenue, cost, discount, return flags)
- `clean_orders`: one row per order (payment, shipping, delivery days)
- `clean_customers`: standardised emails, gender labels, duplicate-email flag
- `v_rev`: view of delivered and non-returned sales

Data quality flags added: orders placed before product launch, future-dated returns, duplicate emails.

---

## ❓ Business Questions Solved

**A. Sales Performance:** Revenue/profit/AOV, monthly trend, MoM growth, top products, categories, brands, sales channels

**B. Customer Analysis:** Repeat customer %, top customers, loyalty tiers, top cities, customers who never ordered

**C. Operations & Returns:** Delivery time by courier, return rate by category, return reasons, supplier return rate

**D. Marketing & Payments:** Coupon vs non-coupon AOV, popular coupons, payment method split, high-rated low-selling products

---

## 📊 Dashboard Preview

### 1. Sales Performance
![Sales Performance](screenshots/1_sales_performance.png)

### 2. Customer Analysis
![Customer Analysis](screenshots/2_customer_analysis.png)

### 3. Operations, Returns & Marketing
![Operations](screenshots/3_operations_returns_marketing.png)

---

## 🔍 Key Insights

- **Revenue:** 579M total revenue from 19K orders, with an AOV of 31K and a 26.13% profit margin
- **Growth:** Monthly revenue shows a strong upward trend over time
- **Channels:** Mobile App contributes ~50% of revenue, followed by Website (~36%)
- **Categories:** Smart Watches and Cameras are the top revenue categories
- **Geography:** Uttar Pradesh, Madhya Pradesh and Maharashtra lead in revenue
- **Customers:** Bronze tier contributes the highest revenue
- **Returns:** Overall return rate is 6.64%, with Staples and Appliances the highest. "Not as described" is the top return reason
- **Operations:** Average delivery time is 5.49 days, with little difference across couriers
- **Marketing:** 24.5% of orders use coupons, and UPI is the most used payment method (~40%)

---


---

## ▶️ How to Use

1. Load the dataset into MySQL and run `sql/Ecommerce.sql`
2. Open `powerbi/Ecommerce.pbix` in Power BI Desktop
3. Refresh the data source if needed

---

## 📬 Contact

**[Your Full Name]**

- 📧 Email: devsing8003@gmail.com
- 💼 LinkedIn:(https://www.linkedin.com/in/deep-dev-b18949387/)

⭐ If you found this project useful, consider giving it a star!
