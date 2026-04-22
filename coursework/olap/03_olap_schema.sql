-- =============================================================
-- PETSTORE OLAP SCHEMA  –  Snowflake DWH
-- PostgreSQL
-- Separate schema: petstore_olap
-- 2 Facts | 1 SCD Type 2 | 1 Bridge Table
-- =============================================================

DROP SCHEMA IF EXISTS petstore_olap CASCADE;
CREATE SCHEMA petstore_olap;
SET search_path = petstore_olap;

-- =============================================================
-- DIMENSIONS
-- =============================================================

-- -------------------------------------------------------------
-- Dim_Date  –  standard date dimension
-- -------------------------------------------------------------
CREATE TABLE dim_date (
    date_key        INT          PRIMARY KEY,   -- YYYYMMDD
    full_date       DATE         NOT NULL UNIQUE,
    day_of_month    SMALLINT     NOT NULL,
    day_name        VARCHAR(10)  NOT NULL,
    week_of_year    SMALLINT     NOT NULL,
    month_num       SMALLINT     NOT NULL,
    month_name      VARCHAR(10)  NOT NULL,
    quarter         SMALLINT     NOT NULL,
    year            SMALLINT     NOT NULL,
    is_weekend      BOOLEAN      NOT NULL
);

-- -------------------------------------------------------------
-- Dim_Category  –  pet/product category
-- -------------------------------------------------------------
CREATE TABLE dim_category (
    category_key    SERIAL       PRIMARY KEY,
    category_name   VARCHAR(100) NOT NULL UNIQUE,
    description     TEXT
);

-- -------------------------------------------------------------
-- Dim_Breed  –  snowflake: references dim_category
-- -------------------------------------------------------------
CREATE TABLE dim_breed (
    breed_key       SERIAL       PRIMARY KEY,
    breed_name      VARCHAR(100) NOT NULL UNIQUE,
    category_key    INT          NOT NULL REFERENCES dim_category(category_key)
);

-- -------------------------------------------------------------
-- Dim_Customer  –  SCD Type 2
-- Tracks changes to city / country over time
-- -------------------------------------------------------------
CREATE TABLE dim_customer (
    customer_key    SERIAL       PRIMARY KEY,   -- surrogate
    email           VARCHAR(255) NOT NULL,
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    city            VARCHAR(100),
    country         VARCHAR(100) NOT NULL,
    -- SCD Type 2 fields
    valid_from      DATE         NOT NULL,
    valid_to        DATE,                       -- NULL = current record
    is_current      BOOLEAN      NOT NULL DEFAULT TRUE,
    UNIQUE (email, valid_from)
);

-- -------------------------------------------------------------
-- Dim_Supplier
-- -------------------------------------------------------------
CREATE TABLE dim_supplier (
    supplier_key    SERIAL       PRIMARY KEY,
    supplier_name   VARCHAR(150) NOT NULL UNIQUE,
    country         VARCHAR(100) NOT NULL
);

-- -------------------------------------------------------------
-- Dim_Pet  –  descriptive attributes at time of sale
-- -------------------------------------------------------------
CREATE TABLE dim_pet (
    pet_key         SERIAL       PRIMARY KEY,
    pet_code        VARCHAR(50)  NOT NULL UNIQUE,
    pet_name        VARCHAR(100) NOT NULL,
    breed_key       INT          NOT NULL REFERENCES dim_breed(breed_key),
    gender          CHAR(1)      NOT NULL,
    age_months      INT          NOT NULL
);

-- -------------------------------------------------------------
-- Dim_Product  –  snowflake: references dim_category & dim_supplier
-- -------------------------------------------------------------
CREATE TABLE dim_product (
    product_key     SERIAL       PRIMARY KEY,
    product_code    VARCHAR(50)  NOT NULL UNIQUE,
    product_name    VARCHAR(200) NOT NULL,
    category_key    INT          NOT NULL REFERENCES dim_category(category_key),
    supplier_key    INT          NOT NULL REFERENCES dim_supplier(supplier_key),
    unit            VARCHAR(30)  NOT NULL
);

-- -------------------------------------------------------------
-- Bridge_Pet_Tag  –  M:N between dim_pet and tags
-- A pet can have multiple tags; this is the bridge table
-- -------------------------------------------------------------
CREATE TABLE bridge_pet_tag (
    pet_key         INT          NOT NULL REFERENCES dim_pet(pet_key),
    tag_name        VARCHAR(100) NOT NULL,
    PRIMARY KEY (pet_key, tag_name)
);

-- =============================================================
-- FACT TABLES
-- =============================================================

-- -------------------------------------------------------------
-- Fact_Pet_Sales
-- Grain: one row per pet sold (one pet = one sale)
-- Measures: sale_price, age_at_sale_months, days_to_sell
-- -------------------------------------------------------------
CREATE TABLE fact_pet_sales (
    pet_sale_key    SERIAL       PRIMARY KEY,
    date_key        INT          NOT NULL REFERENCES dim_date(date_key),
    pet_key         INT          NOT NULL REFERENCES dim_pet(pet_key),
    customer_key    INT          NOT NULL REFERENCES dim_customer(customer_key),
    breed_key       INT          NOT NULL REFERENCES dim_breed(breed_key),
    order_code      VARCHAR(50)  NOT NULL,
    sale_price      NUMERIC(10,2) NOT NULL,
    days_to_sell    INT,                        -- days from listed_at to order_date
    payment_method  VARCHAR(30)  NOT NULL,
    shipping_country VARCHAR(100)
);

-- -------------------------------------------------------------
-- Fact_Product_Sales
-- Grain: one row per order-line of a product
-- Measures: quantity, unit_price, line_total, stock_before_sale
-- -------------------------------------------------------------
CREATE TABLE fact_product_sales (
    product_sale_key SERIAL      PRIMARY KEY,
    date_key         INT         NOT NULL REFERENCES dim_date(date_key),
    product_key      INT         NOT NULL REFERENCES dim_product(product_key),
    customer_key     INT         NOT NULL REFERENCES dim_customer(customer_key),
    supplier_key     INT         NOT NULL REFERENCES dim_supplier(supplier_key),
    order_code       VARCHAR(50) NOT NULL,
    quantity         INT         NOT NULL,
    unit_price       NUMERIC(10,2) NOT NULL,
    line_total       NUMERIC(10,2) NOT NULL,    -- pre-computed: quantity * unit_price
    payment_method   VARCHAR(30) NOT NULL,
    shipping_country VARCHAR(100)
);

-- =============================================================
-- INDEXES
-- =============================================================
CREATE INDEX idx_fps_date      ON fact_pet_sales(date_key);
CREATE INDEX idx_fps_pet       ON fact_pet_sales(pet_key);
CREATE INDEX idx_fps_customer  ON fact_pet_sales(customer_key);
CREATE INDEX idx_fps_breed     ON fact_pet_sales(breed_key);

CREATE INDEX idx_fpes_date     ON fact_product_sales(date_key);
CREATE INDEX idx_fpes_product  ON fact_product_sales(product_key);
CREATE INDEX idx_fpes_customer ON fact_product_sales(customer_key);
CREATE INDEX idx_fpes_supplier ON fact_product_sales(supplier_key);

CREATE INDEX idx_dc_email      ON dim_customer(email);
CREATE INDEX idx_dc_current    ON dim_customer(is_current);
CREATE INDEX idx_dd_year_month ON dim_date(year, month_num);
