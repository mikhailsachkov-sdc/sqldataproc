-- =============================================================
-- PETSTORE OLTP  –  CSV DATA LOADER
-- PostgreSQL
-- Rerunnable: uses INSERT ... ON CONFLICT DO NOTHING
-- Previously loaded rows are never modified.
-- =============================================================
SET search_path = petstore_oltp;

-- -------------------------------------------------------------
-- 1. CATEGORY
-- -------------------------------------------------------------
BEGIN;
CREATE TEMP TABLE stg_category (LIKE category) ON COMMIT DROP;
COPY stg_category (category_name, description)
FROM '/data/csv/categories.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');
INSERT INTO category (category_name, description)
SELECT category_name, description FROM stg_category
ON CONFLICT (category_name) DO NOTHING;
COMMIT;

-- -------------------------------------------------------------
-- 2. BREED
-- -------------------------------------------------------------
BEGIN;
CREATE TEMP TABLE stg_breed (LIKE breed) ON COMMIT DROP;
COPY stg_breed (breed_name, category_name, description)
FROM '/data/csv/breeds.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');
INSERT INTO breed (breed_name, category_name, description)
SELECT breed_name, category_name, description FROM stg_breed
ON CONFLICT (breed_name) DO NOTHING;
COMMIT;

-- -------------------------------------------------------------
-- 3. TAG
-- -------------------------------------------------------------
BEGIN;
CREATE TEMP TABLE stg_tag (LIKE tag) ON COMMIT DROP;
COPY stg_tag (tag_name, description)
FROM '/data/csv/tags.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');
INSERT INTO tag (tag_name, description)
SELECT tag_name, description FROM stg_tag
ON CONFLICT (tag_name) DO NOTHING;
COMMIT;

-- -------------------------------------------------------------
-- 4. SUPPLIER
-- -------------------------------------------------------------
BEGIN;
CREATE TEMP TABLE stg_supplier (LIKE supplier) ON COMMIT DROP;
COPY stg_supplier (supplier_name, contact_email, phone, country)
FROM '/data/csv/suppliers.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');
INSERT INTO supplier (supplier_name, contact_email, phone, country)
SELECT supplier_name, contact_email, phone, country FROM stg_supplier
ON CONFLICT (supplier_name) DO NOTHING;
COMMIT;

-- -------------------------------------------------------------
-- 5. PET
-- -------------------------------------------------------------
BEGIN;
CREATE TEMP TABLE stg_pet (LIKE pet) ON COMMIT DROP;
COPY stg_pet (pet_code, pet_name, breed_name, age_months, gender, price, status, listed_at)
FROM '/data/csv/pets.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');
INSERT INTO pet (pet_code, pet_name, breed_name, age_months, gender, price, status, listed_at)
SELECT pet_code, pet_name, breed_name, age_months, gender, price, status, listed_at
FROM stg_pet
ON CONFLICT (pet_code) DO NOTHING;
COMMIT;

-- -------------------------------------------------------------
-- 6. PET_TAG
-- -------------------------------------------------------------
BEGIN;
CREATE TEMP TABLE stg_pet_tag (LIKE pet_tag) ON COMMIT DROP;
COPY stg_pet_tag (pet_code, tag_name)
FROM '/data/csv/pet_tags.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');
INSERT INTO pet_tag (pet_code, tag_name)
SELECT pet_code, tag_name FROM stg_pet_tag
ON CONFLICT (pet_code, tag_name) DO NOTHING;
COMMIT;

-- -------------------------------------------------------------
-- 7. PRODUCT
-- -------------------------------------------------------------
BEGIN;
CREATE TEMP TABLE stg_product (LIKE product) ON COMMIT DROP;
COPY stg_product (product_code, product_name, category_name, supplier_name, unit_price, stock_qty, unit)
FROM '/data/csv/products.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');
INSERT INTO product (product_code, product_name, category_name, supplier_name, unit_price, stock_qty, unit)
SELECT product_code, product_name, category_name, supplier_name, unit_price, stock_qty, unit
FROM stg_product
ON CONFLICT (product_code) DO NOTHING;
COMMIT;

-- -------------------------------------------------------------
-- 8. CUSTOMER
-- -------------------------------------------------------------
BEGIN;
CREATE TEMP TABLE stg_customer (LIKE customer) ON COMMIT DROP;
COPY stg_customer (email, first_name, last_name, phone, city, country, registered_at)
FROM '/data/csv/customers.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');
INSERT INTO customer (email, first_name, last_name, phone, city, country, registered_at)
SELECT email, first_name, last_name, phone, city, country, registered_at
FROM stg_customer
ON CONFLICT (email) DO NOTHING;
COMMIT;

-- -------------------------------------------------------------
-- 9. ORDER
-- -------------------------------------------------------------
BEGIN;
CREATE TEMP TABLE stg_order (LIKE "order") ON COMMIT DROP;
COPY stg_order (order_code, customer_email, order_date, status, payment_method,
                total_amount, shipping_city, shipping_country)
FROM '/data/csv/orders.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');
INSERT INTO "order" (order_code, customer_email, order_date, status, payment_method,
                     total_amount, shipping_city, shipping_country)
SELECT order_code, customer_email, order_date, status, payment_method,
       total_amount, shipping_city, shipping_country
FROM stg_order
ON CONFLICT (order_code) DO NOTHING;
COMMIT;

-- -------------------------------------------------------------
-- 10. ORDER_PET
-- -------------------------------------------------------------
BEGIN;
CREATE TEMP TABLE stg_order_pet (LIKE order_pet) ON COMMIT DROP;
COPY stg_order_pet (order_code, pet_code, sale_price)
FROM '/data/csv/order_pets.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');
INSERT INTO order_pet (order_code, pet_code, sale_price)
SELECT order_code, pet_code, sale_price FROM stg_order_pet
ON CONFLICT (order_code, pet_code) DO NOTHING;
COMMIT;

-- -------------------------------------------------------------
-- 11. ORDER_PRODUCT
-- -------------------------------------------------------------
BEGIN;
CREATE TEMP TABLE stg_order_product (LIKE order_product) ON COMMIT DROP;
COPY stg_order_product (order_code, product_code, quantity, unit_price)
FROM '/data/csv/order_products.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');
INSERT INTO order_product (order_code, product_code, quantity, unit_price)
SELECT order_code, product_code, quantity, unit_price FROM stg_order_product
ON CONFLICT (order_code, product_code) DO NOTHING;
COMMIT;

-- -------------------------------------------------------------
-- VERIFICATION
-- -------------------------------------------------------------
SELECT 'category'      AS tbl, COUNT(*) AS rows FROM category
UNION ALL SELECT 'breed',         COUNT(*) FROM breed
UNION ALL SELECT 'tag',           COUNT(*) FROM tag
UNION ALL SELECT 'supplier',      COUNT(*) FROM supplier
UNION ALL SELECT 'pet',           COUNT(*) FROM pet
UNION ALL SELECT 'pet_tag',       COUNT(*) FROM pet_tag
UNION ALL SELECT 'product',       COUNT(*) FROM product
UNION ALL SELECT 'customer',      COUNT(*) FROM customer
UNION ALL SELECT 'order',         COUNT(*) FROM "order"
UNION ALL SELECT 'order_pet',     COUNT(*) FROM order_pet
UNION ALL SELECT 'order_product', COUNT(*) FROM order_product
ORDER BY tbl;
