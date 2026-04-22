-- =============================================================
-- PETSTORE OLTP SCHEMA
-- PostgreSQL
-- 3NF | 10 tables
-- =============================================================

-- Drop schema if exists for clean re-run
DROP SCHEMA IF EXISTS petstore_oltp CASCADE;
CREATE SCHEMA petstore_oltp;
SET search_path = petstore_oltp;

-- -------------------------------------------------------------
-- 1. CATEGORY
-- Top-level grouping: Dogs, Cats, Birds, Fish, Reptiles, etc.
-- -------------------------------------------------------------
CREATE TABLE category (
    category_name   VARCHAR(100) PRIMARY KEY,
    description     TEXT
);

-- -------------------------------------------------------------
-- 2. BREED
-- Specific breed within a category
-- -------------------------------------------------------------
CREATE TABLE breed (
    breed_name      VARCHAR(100) PRIMARY KEY,
    category_name   VARCHAR(100) NOT NULL REFERENCES category(category_name),
    description     TEXT
);

-- -------------------------------------------------------------
-- 3. TAG
-- Descriptive tags: vaccinated, hypoallergenic, trained, etc.
-- -------------------------------------------------------------
CREATE TABLE tag (
    tag_name        VARCHAR(100) PRIMARY KEY,
    description     TEXT
);

-- -------------------------------------------------------------
-- 4. PET
-- Core entity. status: available | pending | sold
-- -------------------------------------------------------------
CREATE TABLE pet (
    pet_code        VARCHAR(50)  PRIMARY KEY,   -- e.g. PET-00042
    pet_name        VARCHAR(100) NOT NULL,
    breed_name      VARCHAR(100) NOT NULL REFERENCES breed(breed_name),
    age_months      INT          NOT NULL CHECK (age_months >= 0),
    gender          CHAR(1)      NOT NULL CHECK (gender IN ('M','F')),
    price           NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    status          VARCHAR(20)  NOT NULL DEFAULT 'available'
                                 CHECK (status IN ('available','pending','sold')),
    listed_at       TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------
-- 5. PET_TAG  (M:N between pet and tag)
-- -------------------------------------------------------------
CREATE TABLE pet_tag (
    pet_code        VARCHAR(50)  NOT NULL REFERENCES pet(pet_code),
    tag_name        VARCHAR(100) NOT NULL REFERENCES tag(tag_name),
    PRIMARY KEY (pet_code, tag_name)
);

-- -------------------------------------------------------------
-- 6. SUPPLIER
-- Who supplies products (food, toys, accessories)
-- -------------------------------------------------------------
CREATE TABLE supplier (
    supplier_name   VARCHAR(150) PRIMARY KEY,
    contact_email   VARCHAR(255) NOT NULL UNIQUE,
    phone           VARCHAR(30),
    country         VARCHAR(100) NOT NULL
);

-- -------------------------------------------------------------
-- 7. PRODUCT
-- Items sold in the store (food, toys, accessories, etc.)
-- -------------------------------------------------------------
CREATE TABLE product (
    product_code    VARCHAR(50)  PRIMARY KEY,   -- e.g. PRD-00101
    product_name    VARCHAR(200) NOT NULL,
    category_name   VARCHAR(100) NOT NULL REFERENCES category(category_name),
    supplier_name   VARCHAR(150) NOT NULL REFERENCES supplier(supplier_name),
    unit_price      NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    stock_qty       INT          NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    unit            VARCHAR(30)  NOT NULL DEFAULT 'piece'  -- piece, kg, litre, etc.
);

-- -------------------------------------------------------------
-- 8. CUSTOMER
-- Registered users / buyers
-- -------------------------------------------------------------
CREATE TABLE customer (
    email           VARCHAR(255) PRIMARY KEY,
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    phone           VARCHAR(30),
    city            VARCHAR(100),
    country         VARCHAR(100) NOT NULL,
    registered_at   TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------
-- 9. ORDER
-- A single transaction by a customer.
-- type: pet_purchase | product_purchase | mixed
-- -------------------------------------------------------------
CREATE TABLE "order" (
    order_code      VARCHAR(50)  PRIMARY KEY,   -- e.g. ORD-20240001
    customer_email  VARCHAR(255) NOT NULL REFERENCES customer(email),
    order_date      TIMESTAMP    NOT NULL DEFAULT NOW(),
    status          VARCHAR(30)  NOT NULL DEFAULT 'placed'
                                 CHECK (status IN ('placed','processing','shipped','delivered','cancelled')),
    payment_method  VARCHAR(30)  NOT NULL CHECK (payment_method IN ('card','paypal','bank_transfer','cash')),
    total_amount    NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0),
    shipping_city   VARCHAR(100),
    shipping_country VARCHAR(100)
);

-- -------------------------------------------------------------
-- 10a. ORDER_PET  – line items for pets
-- -------------------------------------------------------------
CREATE TABLE order_pet (
    order_code      VARCHAR(50)  NOT NULL REFERENCES "order"(order_code),
    pet_code        VARCHAR(50)  NOT NULL REFERENCES pet(pet_code),
    sale_price      NUMERIC(10,2) NOT NULL CHECK (sale_price >= 0),
    PRIMARY KEY (order_code, pet_code)
);

-- -------------------------------------------------------------
-- 10b. ORDER_PRODUCT – line items for products
-- -------------------------------------------------------------
CREATE TABLE order_product (
    order_code      VARCHAR(50)  NOT NULL REFERENCES "order"(order_code),
    product_code    VARCHAR(50)  NOT NULL REFERENCES product(product_code),
    quantity        INT          NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    PRIMARY KEY (order_code, product_code)
);

-- -------------------------------------------------------------
-- INDEXES for common lookups
-- -------------------------------------------------------------
CREATE INDEX idx_pet_status       ON pet(status);
CREATE INDEX idx_pet_breed        ON pet(breed_name);
CREATE INDEX idx_product_category ON product(category_name);
CREATE INDEX idx_order_customer   ON "order"(customer_email);
CREATE INDEX idx_order_date       ON "order"(order_date);
