-- =============================================================
-- PETSTORE OLAP QUERIES
-- PostgreSQL
-- =============================================================
SET search_path = petstore_olap;

-- -------------------------------------------------------------
-- Q1: Annual and quarterly pet sales revenue by category
-- (What is the seasonal revenue pattern across pet categories?)
-- -------------------------------------------------------------
SELECT
    dd.year,
    dd.quarter,
    dc.category_name,
    COUNT(fps.pet_sale_key)         AS pets_sold,
    SUM(fps.sale_price)             AS total_revenue,
    ROUND(AVG(fps.sale_price), 2)   AS avg_price,
    ROUND(
        100.0 * SUM(fps.sale_price)
            / SUM(SUM(fps.sale_price)) OVER (PARTITION BY dd.year, dd.quarter),
        1
    )                               AS pct_of_quarter_revenue
FROM fact_pet_sales fps
JOIN dim_date     dd ON dd.date_key    = fps.date_key
JOIN dim_pet      dp ON dp.pet_key     = fps.pet_key
JOIN dim_breed    db ON db.breed_key   = dp.breed_key
JOIN dim_category dc ON dc.category_key = db.category_key
GROUP BY dd.year, dd.quarter, dc.category_name
ORDER BY dd.year, dd.quarter, total_revenue DESC;

-- -------------------------------------------------------------
-- Q2: Top 10 customers by total lifetime spend (pets + products)
-- (Who are the most valuable customers?)
-- -------------------------------------------------------------
SELECT
    dc.email,
    dc.first_name || ' ' || dc.last_name   AS full_name,
    dc.country,
    COALESCE(pet_stats.pet_revenue, 0)      AS pet_revenue,
    COALESCE(prod_stats.product_revenue, 0) AS product_revenue,
    COALESCE(pet_stats.pet_revenue, 0)
        + COALESCE(prod_stats.product_revenue, 0) AS total_lifetime_spend,
    COALESCE(pet_stats.pets_bought, 0)      AS pets_bought,
    COALESCE(prod_stats.product_orders, 0)  AS product_line_items
FROM dim_customer dc
LEFT JOIN (
    SELECT customer_key,
           SUM(sale_price) AS pet_revenue,
           COUNT(*)        AS pets_bought
    FROM fact_pet_sales
    GROUP BY customer_key
) pet_stats ON pet_stats.customer_key = dc.customer_key
LEFT JOIN (
    SELECT customer_key,
           SUM(line_total)  AS product_revenue,
           COUNT(*)         AS product_orders
    FROM fact_product_sales
    GROUP BY customer_key
) prod_stats ON prod_stats.customer_key = dc.customer_key
WHERE dc.is_current = TRUE
  AND (pet_stats.pet_revenue IS NOT NULL OR prod_stats.product_revenue IS NOT NULL)
ORDER BY total_lifetime_spend DESC
LIMIT 10;

-- -------------------------------------------------------------
-- Q3: Monthly product sales trend by supplier country
-- (Which countries supply the most revenue by month?)
-- -------------------------------------------------------------
SELECT
    dd.year,
    dd.month_name,
    dd.month_num,
    ds.country                       AS supplier_country,
    COUNT(DISTINCT fps.order_code)   AS orders,
    SUM(fps.quantity)                AS units_sold,
    SUM(fps.line_total)              AS revenue
FROM fact_product_sales fps
JOIN dim_date     dd ON dd.date_key     = fps.date_key
JOIN dim_supplier ds ON ds.supplier_key = fps.supplier_key
GROUP BY dd.year, dd.month_name, dd.month_num, ds.country
ORDER BY dd.year, dd.month_num, revenue DESC;

-- -------------------------------------------------------------
-- Q4: Pet sales conversion time analysis by breed
-- (Which breeds take longest to sell? Grouped by category.)
-- -------------------------------------------------------------
SELECT
    dc.category_name,
    db.breed_name,
    COUNT(fps.pet_sale_key)             AS total_sold,
    ROUND(AVG(fps.days_to_sell), 1)     AS avg_days_to_sell,
    MIN(fps.days_to_sell)               AS min_days,
    MAX(fps.days_to_sell)               AS max_days,
    ROUND(AVG(fps.sale_price), 2)       AS avg_sale_price
FROM fact_pet_sales fps
JOIN dim_pet      dp ON dp.pet_key      = fps.pet_key
JOIN dim_breed    db ON db.breed_key    = dp.breed_key
JOIN dim_category dc ON dc.category_key = db.category_key
WHERE fps.days_to_sell IS NOT NULL
GROUP BY dc.category_name, db.breed_name
HAVING COUNT(fps.pet_sale_key) >= 1
ORDER BY avg_days_to_sell DESC;

-- -------------------------------------------------------------
-- Q5: Revenue by shipping country and payment method
-- (Where do customers buy from, and how do they pay?)
-- -------------------------------------------------------------
SELECT
    fps.shipping_country,
    fps.payment_method,
    COUNT(DISTINCT fps.order_code)      AS orders,
    SUM(fps.sale_price)                 AS pet_revenue,
    COALESCE(prod.product_revenue, 0)   AS product_revenue,
    SUM(fps.sale_price)
        + COALESCE(prod.product_revenue, 0) AS total_revenue
FROM fact_pet_sales fps
LEFT JOIN (
    SELECT shipping_country, payment_method,
           SUM(line_total) AS product_revenue
    FROM fact_product_sales
    GROUP BY shipping_country, payment_method
) prod ON prod.shipping_country = fps.shipping_country
       AND prod.payment_method  = fps.payment_method
GROUP BY fps.shipping_country, fps.payment_method, prod.product_revenue
ORDER BY total_revenue DESC;

-- -------------------------------------------------------------
-- Q6: Tag influence on pet sales price (via bridge table)
-- (Using the bridge table: do tagged pets sell for more?)
-- -------------------------------------------------------------
SELECT
    bpt.tag_name,
    COUNT(fps.pet_sale_key)         AS pets_sold,
    ROUND(AVG(fps.sale_price), 2)   AS avg_sale_price,
    SUM(fps.sale_price)             AS total_revenue,
    ROUND(AVG(fps.days_to_sell), 1) AS avg_days_to_sell
FROM fact_pet_sales fps
JOIN bridge_pet_tag bpt ON bpt.pet_key = fps.pet_key
GROUP BY bpt.tag_name
ORDER BY avg_sale_price DESC;
