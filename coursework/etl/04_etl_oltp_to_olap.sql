-- =============================================================
-- PETSTORE ETL  –  OLTP → OLAP
-- PostgreSQL
-- Rerunnable: never overwrites existing records
-- Run order: dimensions first, then facts
-- =============================================================

SET search_path = petstore_olap;

-- =============================================================
-- STEP 1: POPULATE Dim_Date  (2023-01-01 → 2026-12-31)
-- Only inserts dates not already present
-- =============================================================
INSERT INTO dim_date (
    date_key, full_date, day_of_month, day_name,
    week_of_year, month_num, month_name, quarter, year, is_weekend
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT,
    d,
    EXTRACT(DAY   FROM d)::SMALLINT,
    TO_CHAR(d, 'Day'),
    EXTRACT(WEEK  FROM d)::SMALLINT,
    EXTRACT(MONTH FROM d)::SMALLINT,
    TO_CHAR(d, 'Month'),
    EXTRACT(QUARTER FROM d)::SMALLINT,
    EXTRACT(YEAR  FROM d)::SMALLINT,
    EXTRACT(ISODOW FROM d) IN (6, 7)
FROM GENERATE_SERIES('2023-01-01'::DATE, '2026-12-31'::DATE, '1 day') AS d
ON CONFLICT (date_key) DO NOTHING;

-- =============================================================
-- STEP 2: Dim_Category  –  load from OLTP
-- =============================================================
INSERT INTO dim_category (category_name, description)
SELECT category_name, description
FROM petstore_oltp.category
ON CONFLICT (category_name) DO NOTHING;

-- =============================================================
-- STEP 3: Dim_Breed  –  snowflake → needs category_key
-- =============================================================
INSERT INTO dim_breed (breed_name, category_key)
SELECT
    b.breed_name,
    dc.category_key
FROM petstore_oltp.breed b
JOIN dim_category dc ON dc.category_name = b.category_name
ON CONFLICT (breed_name) DO NOTHING;

-- =============================================================
-- STEP 4: Dim_Supplier
-- =============================================================
INSERT INTO dim_supplier (supplier_name, country)
SELECT supplier_name, country
FROM petstore_oltp.supplier
ON CONFLICT (supplier_name) DO NOTHING;

-- =============================================================
-- STEP 5: Dim_Customer  –  SCD Type 2
-- Logic:
--   • New email never seen → insert as current record
--   • Existing email with changed city/country →
--       close old record (set valid_to, is_current=false)
--       insert new record as current
--   • No changes → skip
-- =============================================================
DO $$
DECLARE
    r RECORD;
    existing RECORD;
    today DATE := CURRENT_DATE;
BEGIN
    FOR r IN
        SELECT email, first_name, last_name, city, country,
               registered_at::DATE AS reg_date
        FROM petstore_oltp.customer
    LOOP
        -- Get the current active record for this email
        SELECT * INTO existing
        FROM dim_customer
        WHERE email = r.email AND is_current = TRUE
        LIMIT 1;

        IF NOT FOUND THEN
            -- Brand new customer
            INSERT INTO dim_customer
                (email, first_name, last_name, city, country, valid_from, valid_to, is_current)
            VALUES
                (r.email, r.first_name, r.last_name, r.city, r.country,
                 r.reg_date, NULL, TRUE);

        ELSIF existing.city IS DISTINCT FROM r.city
           OR existing.country IS DISTINCT FROM r.country THEN
            -- Location changed → close old record
            UPDATE dim_customer
            SET valid_to   = today - 1,
                is_current = FALSE
            WHERE customer_key = existing.customer_key;

            -- Insert new current record
            INSERT INTO dim_customer
                (email, first_name, last_name, city, country, valid_from, valid_to, is_current)
            VALUES
                (r.email, r.first_name, r.last_name, r.city, r.country,
                 today, NULL, TRUE);
        END IF;
        -- No change → do nothing
    END LOOP;
END $$;

-- =============================================================
-- STEP 6: Dim_Pet
-- =============================================================
INSERT INTO dim_pet (pet_code, pet_name, breed_key, gender, age_months)
SELECT
    p.pet_code,
    p.pet_name,
    db.breed_key,
    p.gender,
    p.age_months
FROM petstore_oltp.pet p
JOIN dim_breed db ON db.breed_name = p.breed_name
ON CONFLICT (pet_code) DO NOTHING;

-- =============================================================
-- STEP 7: Dim_Product
-- =============================================================
INSERT INTO dim_product (product_code, product_name, category_key, supplier_key, unit)
SELECT
    pr.product_code,
    pr.product_name,
    dc.category_key,
    ds.supplier_key,
    pr.unit
FROM petstore_oltp.product pr
JOIN dim_category dc ON dc.category_name = pr.category_name
JOIN dim_supplier ds ON ds.supplier_name = pr.supplier_name
ON CONFLICT (product_code) DO NOTHING;

-- =============================================================
-- STEP 8: Bridge_Pet_Tag
-- =============================================================
INSERT INTO bridge_pet_tag (pet_key, tag_name)
SELECT
    dp.pet_key,
    pt.tag_name
FROM petstore_oltp.pet_tag pt
JOIN dim_pet dp ON dp.pet_code = pt.pet_code
ON CONFLICT (pet_key, tag_name) DO NOTHING;

-- =============================================================
-- STEP 9: Fact_Pet_Sales
-- Only load orders not yet in the fact table
-- =============================================================
INSERT INTO fact_pet_sales (
    date_key, pet_key, customer_key, breed_key,
    order_code, sale_price, days_to_sell,
    payment_method, shipping_country
)
SELECT
    TO_CHAR(o.order_date, 'YYYYMMDD')::INT   AS date_key,
    dp.pet_key,
    dc.customer_key,
    dp.breed_key,
    o.order_code,
    op.sale_price,
    (o.order_date::DATE - p.listed_at::DATE) AS days_to_sell,
    o.payment_method,
    o.shipping_country
FROM petstore_oltp.order_pet op
JOIN petstore_oltp."order"  o   ON o.order_code      = op.order_code
JOIN petstore_oltp.pet      p   ON p.pet_code         = op.pet_code
JOIN dim_pet                dp  ON dp.pet_code         = op.pet_code
JOIN dim_customer           dc  ON dc.email            = o.customer_email
                                AND dc.is_current      = TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM fact_pet_sales fps
    WHERE fps.order_code = op.order_code
      AND fps.pet_key    = dp.pet_key
);

-- =============================================================
-- STEP 10: Fact_Product_Sales
-- =============================================================
INSERT INTO fact_product_sales (
    date_key, product_key, customer_key, supplier_key,
    order_code, quantity, unit_price, line_total,
    payment_method, shipping_country
)
SELECT
    TO_CHAR(o.order_date, 'YYYYMMDD')::INT   AS date_key,
    dpr.product_key,
    dc.customer_key,
    dpr.supplier_key,
    o.order_code,
    opr.quantity,
    opr.unit_price,
    opr.quantity * opr.unit_price             AS line_total,
    o.payment_method,
    o.shipping_country
FROM petstore_oltp.order_product opr
JOIN petstore_oltp."order"  o    ON o.order_code      = opr.order_code
JOIN dim_product             dpr  ON dpr.product_code  = opr.product_code
JOIN dim_customer            dc   ON dc.email           = o.customer_email
                                 AND dc.is_current      = TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM fact_product_sales fpr
    WHERE fpr.order_code   = opr.order_code
      AND fpr.product_key  = dpr.product_key
);

-- =============================================================
-- VERIFICATION
-- =============================================================
SELECT 'dim_date'           AS tbl, COUNT(*) AS rows FROM dim_date
UNION ALL SELECT 'dim_category',    COUNT(*) FROM dim_category
UNION ALL SELECT 'dim_breed',       COUNT(*) FROM dim_breed
UNION ALL SELECT 'dim_supplier',    COUNT(*) FROM dim_supplier
UNION ALL SELECT 'dim_customer',    COUNT(*) FROM dim_customer
UNION ALL SELECT 'dim_pet',         COUNT(*) FROM dim_pet
UNION ALL SELECT 'dim_product',     COUNT(*) FROM dim_product
UNION ALL SELECT 'bridge_pet_tag',  COUNT(*) FROM bridge_pet_tag
UNION ALL SELECT 'fact_pet_sales',  COUNT(*) FROM fact_pet_sales
UNION ALL SELECT 'fact_product_sales', COUNT(*) FROM fact_product_sales
ORDER BY tbl;
