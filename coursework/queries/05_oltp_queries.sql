-- =============================================================
-- PETSTORE OLTP QUERIES
-- PostgreSQL
-- =============================================================
SET search_path = petstore_oltp;

-- -------------------------------------------------------------
-- Q1: Top 5 best-selling pet breeds by revenue
-- (How much revenue did each breed generate from pet sales?)
-- -------------------------------------------------------------
SELECT
    b.breed_name,
    c.category_name,
    COUNT(op.pet_code)          AS pets_sold,
    SUM(op.sale_price)          AS total_revenue,
    ROUND(AVG(op.sale_price),2) AS avg_sale_price
FROM order_pet op
JOIN pet       p  ON p.pet_code     = op.pet_code
JOIN breed     b  ON b.breed_name   = p.breed_name
JOIN category  c  ON c.category_name = b.category_name
JOIN "order"   o  ON o.order_code   = op.order_code
WHERE o.status IN ('delivered','shipped','processing')
GROUP BY b.breed_name, c.category_name
ORDER BY total_revenue DESC
LIMIT 5;

-- -------------------------------------------------------------
-- Q2: Monthly order volume and revenue (pets + products combined)
-- (What is the trend in orders and revenue month by month?)
-- -------------------------------------------------------------
SELECT
    DATE_TRUNC('month', o.order_date)::DATE AS month,
    COUNT(DISTINCT o.order_code)             AS total_orders,
    -- Pet revenue
    COALESCE(SUM(op.sale_price), 0)          AS pet_revenue,
    -- Product revenue
    COALESCE(SUM(opr.quantity * opr.unit_price), 0) AS product_revenue,
    -- Combined
    COALESCE(SUM(op.sale_price), 0)
        + COALESCE(SUM(opr.quantity * opr.unit_price), 0) AS total_revenue
FROM "order" o
LEFT JOIN order_pet     op  ON op.order_code  = o.order_code
LEFT JOIN order_product opr ON opr.order_code = o.order_code
WHERE o.status != 'cancelled'
GROUP BY DATE_TRUNC('month', o.order_date)
ORDER BY month;

-- -------------------------------------------------------------
-- Q3: Customers who bought both a pet and products
-- (Which customers made mixed orders?)
-- -------------------------------------------------------------
SELECT
    c.email,
    c.first_name || ' ' || c.last_name AS full_name,
    c.country,
    COUNT(DISTINCT o.order_code)        AS total_orders,
    SUM(op.sale_price)                  AS pet_spend,
    SUM(opr.quantity * opr.unit_price)  AS product_spend
FROM customer c
JOIN "order"       o   ON o.customer_email = c.email
JOIN order_pet     op  ON op.order_code    = o.order_code
JOIN order_product opr ON opr.order_code   = o.order_code
WHERE o.status != 'cancelled'
GROUP BY c.email, c.first_name, c.last_name, c.country
ORDER BY SUM(op.sale_price) + SUM(opr.quantity * opr.unit_price) DESC;

-- -------------------------------------------------------------
-- Q4: Most popular product categories by quantity sold
-- (Which product categories move the most units?)
-- -------------------------------------------------------------
SELECT
    c.category_name,
    COUNT(DISTINCT opr.order_code)      AS orders_containing,
    SUM(opr.quantity)                   AS total_units_sold,
    SUM(opr.quantity * opr.unit_price)  AS total_revenue,
    COUNT(DISTINCT p.product_code)      AS distinct_products_sold
FROM order_product opr
JOIN product  p ON p.product_code  = opr.product_code
JOIN category c ON c.category_name = p.category_name
JOIN "order"  o ON o.order_code    = opr.order_code
WHERE o.status != 'cancelled'
GROUP BY c.category_name
ORDER BY total_revenue DESC;

-- -------------------------------------------------------------
-- Q5: Pet inventory status summary
-- (How many pets are currently available, pending, or sold per category?)
-- -------------------------------------------------------------
SELECT
    c.category_name,
    SUM(CASE WHEN p.status = 'available' THEN 1 ELSE 0 END) AS available,
    SUM(CASE WHEN p.status = 'pending'   THEN 1 ELSE 0 END) AS pending,
    SUM(CASE WHEN p.status = 'sold'      THEN 1 ELSE 0 END) AS sold,
    COUNT(*)                                                  AS total_listed,
    ROUND(AVG(p.price), 2)                                   AS avg_listed_price
FROM pet  p
JOIN breed    b ON b.breed_name   = p.breed_name
JOIN category c ON c.category_name = b.category_name
GROUP BY c.category_name
ORDER BY total_listed DESC;

-- -------------------------------------------------------------
-- Q6: Tags associated with sold pets and their average price
-- (Do certain tags correlate with higher sale prices?)
-- -------------------------------------------------------------
SELECT
    pt.tag_name,
    COUNT(DISTINCT p.pet_code)          AS pets_with_tag,
    COUNT(DISTINCT op.order_code)       AS times_sold,
    ROUND(AVG(op.sale_price), 2)        AS avg_sale_price,
    SUM(op.sale_price)                  AS total_revenue
FROM tag t
JOIN pet_tag   pt ON pt.tag_name  = t.tag_name
JOIN pet        p ON p.pet_code   = pt.pet_code
LEFT JOIN order_pet op ON op.pet_code = p.pet_code
GROUP BY pt.tag_name
ORDER BY avg_sale_price DESC NULLS LAST;
