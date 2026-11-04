SELECT 'brands' AS tbl, COUNT(*) AS n FROM brands UNION ALL
SELECT 'categories', COUNT(*) FROM categories UNION ALL
SELECT 'coupons', COUNT(*) FROM coupons UNION ALL
SELECT 'customers', COUNT(*) FROM customers UNION ALL
SELECT 'employees', COUNT(*) FROM employees UNION ALL
SELECT 'inventory_log', COUNT(*) FROM inventory_log UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items UNION ALL
SELECT 'orders', COUNT(*) FROM orders UNION ALL
SELECT 'payments', COUNT(*) FROM payments UNION ALL
SELECT 'products', COUNT(*) FROM products UNION ALL
SELECT 'returns', COUNT(*) FROM returns UNION ALL
SELECT 'reviews', COUNT(*) FROM reviews UNION ALL
SELECT 'shipments', COUNT(*) FROM shipments UNION ALL
SELECT 'suppliers', COUNT(*) FROM suppliers;

SELECT 'brands' AS tbl, COUNT(*) AS n FROM brands UNION ALL
SELECT 'categories', COUNT(*) FROM categories UNION ALL
SELECT 'coupons', COUNT(*) FROM coupons UNION ALL
SELECT 'customers', COUNT(*) FROM customers UNION ALL
SELECT 'employees', COUNT(*) FROM employees UNION ALL
SELECT 'inventory_log', COUNT(*) FROM inventory_log UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items UNION ALL
SELECT 'orders', COUNT(*) FROM orders UNION ALL
SELECT 'payments', COUNT(*) FROM payments UNION ALL
SELECT 'products', COUNT(*) FROM products UNION ALL
SELECT 'returns', COUNT(*) FROM returns UNION ALL
SELECT 'reviews', COUNT(*) FROM reviews UNION ALL
SELECT 'shipments', COUNT(*) FROM shipments UNION ALL
SELECT 'suppliers', COUNT(*) FROM suppliers;


-- 1) clean_order_items : har order line ka sach (GRAIN = order_item_id)
DROP TABLE IF EXISTS clean_order_items;
CREATE TABLE clean_order_items AS
SELECT
    oi.order_item_id, oi.order_id, o.customer_id,
    o.order_date, DATE(o.order_date) AS order_day,
    o.order_status, o.sales_channel, o.shipping_city, o.coupon_id,
    oi.product_id, p.category_id, p.brand_id, p.supplier_id,
    oi.quantity, oi.unit_price, oi.discount_pct, p.cost_price,
    oi.quantity * oi.unit_price                                   AS gross_amount,
    oi.quantity * oi.unit_price * oi.discount_pct / 100           AS discount_amount,
    oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100)     AS net_amount,
    oi.quantity * p.cost_price                                    AS cost_amount,
    CASE WHEN r.order_item_id IS NOT NULL THEN 1 ELSE 0 END       AS is_returned,
    COALESCE(r.refund_amount, 0)                                  AS refund_amount,  -- return nahi = refund 0 (logically sahi)
    CASE WHEN o.order_status = 'Delivered' THEN 1 ELSE 0 END      AS is_delivered,
    CASE WHEN o.order_date < p.created_at THEN 1 ELSE 0 END       AS flag_before_product_launch,
    CASE WHEN r.return_date > '2026-10-28' THEN 1 ELSE 0 END      AS flag_future_return
FROM order_items oi
JOIN orders   o ON o.order_id   = oi.order_id
JOIN products p ON p.product_id = oi.product_id
LEFT JOIN returns r ON r.order_item_id = oi.order_item_id;

ALTER TABLE clean_order_items
  ADD PRIMARY KEY (order_item_id),
  ADD INDEX idx_oi_order (order_id), ADD INDEX idx_oi_cust (customer_id),
  ADD INDEX idx_oi_prod (product_id), ADD INDEX idx_oi_day (order_day);

-- 2) clean_orders : har order ek row (GRAIN = order_id)
DROP TABLE IF EXISTS clean_orders;
CREATE TABLE clean_orders AS
SELECT
    o.order_id, o.customer_id, o.order_date, DATE(o.order_date) AS order_day,
    DATE_SUB(DATE(o.order_date), INTERVAL DAYOFMONTH(o.order_date) - 1 DAY) AS order_month,
    o.order_status, o.sales_channel, o.shipping_city, o.coupon_id,
    CASE WHEN o.coupon_id IS NULL THEN 0 ELSE 1 END AS has_coupon,
    p.payment_method, p.payment_status, p.amount AS payment_amount,
    s.courier, s.shipped_date, s.delivered_date,
    DATEDIFF(s.delivered_date, s.shipped_date) AS delivery_days,   -- In Transit = NULL (sahi hai)
    i.line_count, i.units, i.gross_amount, i.discount_amount, i.net_amount
FROM orders o
JOIN payments p ON p.order_id = o.order_id
LEFT JOIN shipments s ON s.order_id = o.order_id
JOIN (SELECT order_id, COUNT(*) AS line_count, SUM(quantity) AS units,
             SUM(gross_amount) AS gross_amount, SUM(discount_amount) AS discount_amount,
             SUM(net_amount) AS net_amount
      FROM clean_order_items GROUP BY order_id) i ON i.order_id = o.order_id;

ALTER TABLE clean_orders
  ADD PRIMARY KEY (order_id),
  ADD INDEX idx_o_cust (customer_id), ADD INDEX idx_o_month (order_month);

-- 3) clean_customers : email saaf + flags
DROP TABLE IF EXISTS clean_customers;
CREATE TABLE clean_customers AS
SELECT c.*,
       LOWER(TRIM(c.email))            AS email_clean,
       COALESCE(c.gender, 'Unknown')   AS gender_clean,   -- sirf reporting label, original NULL safe hai
       CASE WHEN d.email_clean IS NOT NULL THEN 1 ELSE 0 END AS is_dup_email
FROM customers c
LEFT JOIN (SELECT LOWER(TRIM(email)) AS email_clean FROM customers
           WHERE email IS NOT NULL GROUP BY LOWER(TRIM(email)) HAVING COUNT(*) > 1) d
       ON d.email_clean = LOWER(TRIM(c.email));
ALTER TABLE clean_customers ADD PRIMARY KEY (customer_id);

CREATE OR REPLACE VIEW v_rev AS
SELECT * FROM clean_order_items
WHERE is_delivered = 1 AND is_returned = 0;

-- A. Sales Performance
-- Q1. What are the total revenue, profit, orders and AOV?
select count(distinct order_id) as total_orders,
sum(net_amount) as revenue,
sum(net_amount - cost_amount) as profit,
round(sum(net_amount - cost_amount) * 100 / SUM(net_amount), 2) as profit_margin_pct,
round(sum(net_amount) / count(distinct order_id), 2) as aov
from clean_order_items
where flag_before_product_launch = 0 and flag_future_return = 0;

-- Q2. What is the monthly revenue and profit trend?
select date_format(order_date, '%Y-%m') as month,
sum(net_amount) as revenue,
sum(net_amount - cost_amount) as profit
from clean_order_items
where flag_before_product_launch = 0 and flag_future_return = 0
group by month
order by month;

-- Q3. What is the month-over-month revenue growth %?
select month, revenue,
round((revenue - lag(revenue) over (order by month)) * 100/ LAG(revenue) OVER (order by month), 2) AS mom_growth_pct
from (select date_format(order_date, '%Y-%m') as month, sum(net_amount) as revenue
from clean_order_items
where flag_before_product_launch = 0 and flag_future_return = 0
group by month) t;

-- Q4. Which are the top 10 products by revenue?
select p.product_name, sum(i.net_amount) AS revenue, sum(i.quantity) as units
from clean_order_items i
join products p on i.product_id = p.product_id
where i.flag_before_product_launch = 0 and i.flag_future_return = 0
group by p.product_name
order by revenue desc
limit 10;

-- Q5. Which categories give the highest revenue and margin?
select c.category_name,sum(i.net_amount) as revenue,
round(sum(i.net_amount - i.cost_amount) * 100 / sum(i.net_amount), 2) as margin_pct
from clean_order_items i
join categories c on i.category_id = c.category_id
where i.flag_before_product_launch = 0 and i.flag_future_return = 0
group by c.category_name
order by revenue desc;

-- Q6. Which brands perform best?
select  b.brand_name, sum(i.net_amount) as revenue,
sum(i.net_amount - i.cost_amount) as profit
from clean_order_items i
join brands b on i.brand_id = b.brand_id
where i.flag_before_product_launch = 0 and i.flag_future_return = 0
group by b.brand_name
order by revenue desc
limit 10;

-- Q7. Which sales channel brings the most revenue and the best AOV?
select sales_channel,count(*) as orders,sum(net_amount) as revenue,round(avg(net_amount), 2) as aov
from clean_orders
group by sales_channel
order by revenue desc;

-- B. Customer Analysis

-- Q8. What % of customers are repeat customers?
select round(count(case when cnt > 1 then 1 end) * 100.0 / count(*), 2) as repeat_pct
from (select customer_id, count(*) as cnt
from clean_orders group by customer_id) t;
      
-- Q9. Who are the top 10 customers by spend? (window function)
select customer_id, total_spend,
dense_rank() over (order by total_spend desc) as rnk
from (select customer_id, sum(net_amount) as total_spend
from clean_orders group by customer_id) t
order by rnk
limit 10;

-- Q10. How does revenue vary by loyalty tier?
select c.loyalty_tier,count(distinct c.customer_id) as customers,
sum(o.net_amount) as revenue,
round(sum(o.net_amount) / count(DISTINCT c.customer_id), 2) as revenue_per_customer
from clean_customers c
join clean_orders o ON c.customer_id = o.customer_id
where c.is_dup_email = 0
group by c.loyalty_tier
order by revenue desc;

-- Q11. Which states and cities generate the most sales?
select c.state, c.city, sum(o.net_amount) as revenue
from clean_customers c
join clean_orders o on c.customer_id = o.customer_id
group by c.state, c.city
order by revenue desc
limit 10;

-- Q12. Which customers signed up but never ordered? 
select c.customer_id, c.signup_date
from clean_customers c
left join clean_orders o on c.customer_id = o.customer_id
where o.order_id is null;

-- C. Operations & Returns

-- Q13. What is the average delivery time by courier?
select courier,round(avg(delivery_days), 2) as avg_delivery_days,
count(*) as shipments
from clean_orders
where delivery_days is not null
group by courier
order by avg_delivery_days;

-- Q14. What is the return rate by category?
select c.category_name,round(sum(i.is_returned) * 100.0 / COUNT(*), 2) as return_rate_pct,
sum(i.refund_amount) as total_refund
from clean_order_items i
join categories c on i.category_id = c.category_id
where i.flag_future_return = 0
group by c.category_name
order by return_rate_pct desc;

-- Q15. What are the top return reasons?
select reason, count(*) as returns, SUM(refund_amount) as refund
from returns
group by reason
order by returns desc;

-- Q16. Which suppliers have a high return rate?
select s.supplier_name, s.rating,
round(sum(i.is_returned) * 100.0 / COUNT(*), 2) as return_rate_pct
from clean_order_items i
join suppliers s on i.supplier_id = s.supplier_id
group by s.supplier_name, s.rating
having COUNT(*) > 50
order by return_rate_pct desc;

-- D. Marketing & Payments

-- Q17. Do coupon orders have a higher or lower AOV than non-coupon orders?
select has_coupon,count(*) as orders,round(avg(net_amount), 2) as aov,
sum(discount_amount) as total_discount
from clean_orders
group by has_coupon;

-- Q18. Which coupon codes are most used? 
select cp.code, cp.discount_type, COUNT(*) as times_used, SUM(o.net_amount) AS revenue
from clean_orders o
join coupons cp ON o.coupon_id = cp.coupon_id
group by cp.code, cp.discount_type
order by times_used desc;

-- Q19. What is the payment method and payment status split?
select payment_method, payment_status,
count(*) as orders, SUM(payment_amount) as amount
from clean_orders
group by payment_method, payment_status
order by orders desc;

-- Q20. Which products have high ratings but low sales? (hidden opportunity)
select p.product_name,round(avg(r.rating), 2) as avg_rating,
(select sum(i.quantity) from clean_order_items i
where i.product_id = p.product_id) as units_sold
from products p
join reviews r on p.product_id = r.product_id
group by p.product_id, p.product_name
having avg_rating >= 4
order by units_sold asc
limit  10;



