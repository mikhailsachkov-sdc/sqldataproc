# Petstore Application — Database Course Work

---

## 1. Project Overview

This course work implements a full database solution for an online pet store inspired by the OpenAPI Petstore specification, extended to meet all coursework requirements. The application allows customers to browse and purchase pets and pet-related products, while administrators can manage inventory, track orders, and analyse sales performance.

The solution consists of:

- An **OLTP** relational database (`petstore_oltp`) storing operational data in 3NF with 11 tables
- **CSV source files** with realistic seed data for all entities (60 pets, 30 customers, 50 orders, 25 products)
- An **idempotent SQL loader** that imports CSV data without overwriting existing records
- A **snowflake OLAP** data warehouse (`petstore_olap`) with 2 fact tables, SCD Type 2, and a bridge table
- An **ETL script** that moves data from OLTP to OLAP incrementally
- **SQL queries** for both OLTP and OLAP analytical use cases

---

## 2. OLTP Database

### 2.1 Context — What is stored

The OLTP schema (`petstore_oltp`) models the day-to-day operations of an online pet store. It stores:

- The **pet catalogue**: categories, breeds, individual pets and their descriptive tags
- The **product catalogue**: accessories, food, and toys supplied by external suppliers
- **Customer accounts**: personal details and registration information
- **Orders**: each order links a customer to one or more pets and/or products, with payment and shipping details

The schema is in **Third Normal Form (3NF)**: every non-key attribute depends only on the primary key of its table, with no transitive dependencies. Natural business keys are used as primary keys throughout — no surrogate integer sequences appear in the OLTP layer.

### 2.2 Tables

| Table | Purpose |
|-------|---------|
| `category` | Top-level grouping for pets and products (Dogs, Cats, Food, Toys…). PK: `category_name` |
| `breed` | Specific breed within a category. PK: `breed_name`. FK → `category` |
| `tag` | Descriptive labels for pets: vaccinated, pedigree, rescue, etc. PK: `tag_name` |
| `pet` | Core entity: an individual animal listed for sale. PK: `pet_code` (e.g. `PET-00042`). Attributes: name, breed, age, gender, price, status, listed_at |
| `pet_tag` | Many-to-many bridge between `pet` and `tag`. Composite PK: `(pet_code, tag_name)` |
| `supplier` | Companies that supply products. PK: `supplier_name`. Includes contact email, phone, country |
| `product` | Items sold in the store. PK: `product_code` (e.g. `PRD-00101`). FK → `category`, `supplier` |
| `customer` | Registered buyers. PK: `email`. Includes name, phone, city, country, registered_at |
| `order` | A purchase transaction. PK: `order_code` (e.g. `ORD-2024-0001`). FK → `customer`. Tracks status, payment method, totals, shipping details |
| `order_pet` | Line items linking an order to a specific pet sold. Composite PK: `(order_code, pet_code)`. Records actual sale price |
| `order_product` | Line items linking an order to a product. Composite PK: `(order_code, product_code)`. Records quantity and unit price at time of sale |

### 2.3 Key Constraints and Relationships

- `category` → `breed` (one category has many breeds)
- `category` → `product` (one category classifies many products)
- `breed` → `pet` (one breed has many pets)
- `tag` ↔ `pet` via `pet_tag` (many-to-many)
- `supplier` → `product` (one supplier provides many products)
- `customer` → `order` (one customer places many orders)
- `order` → `order_pet` / `order_product` (one order contains many line items)
- `pet.status` constrained to: `available`, `pending`, `sold`
- `order.status` constrained to: `placed`, `processing`, `shipped`, `delivered`, `cancelled`
- `payment_method` constrained to: `card`, `paypal`, `bank_transfer`, `cash`
- All prices and quantities have `CHECK` constraints preventing negative values

---

## 3. OLAP Database

### 3.1 Context — Analytical Questions

The OLAP schema (`petstore_olap`) is stored in a separate schema and answers the following business questions:

- What is the revenue trend by month, quarter, and year across pet and product sales?
- Which pet categories and breeds generate the most revenue?
- Which customers have the highest lifetime spend?
- Which supplier countries contribute most to product revenue by period?
- How quickly do different pet breeds sell, and does price correlate with days to sell?
- Do pet tags (vaccinated, pedigree, etc.) correlate with higher sale prices?
- Which shipping countries and payment methods dominate transactions?

The OLAP schema does not mirror the OLTP structure. It pre-aggregates line totals (`line_total = quantity × unit_price`) in `fact_product_sales` and derives analytical keys like `days_to_sell`. Dimensions contain descriptive attributes optimised for slicing and filtering.

### 3.2 Schema Overview

| Object | Type | Description |
|--------|------|-------------|
| `dim_date` | Dimension | Date dimension with day, week, month, quarter, year, weekend flag. Pre-populated 2023–2026 |
| `dim_category` | Dimension | Category dimension shared by pet and product hierarchies |
| `dim_breed` | Dimension | References `dim_category` — creates the snowflake hierarchy |
| `dim_supplier` | Dimension | Supplier name and country |
| `dim_customer` | **SCD Type 2** | Tracks changes to city and country over time using `valid_from`, `valid_to`, `is_current` |
| `dim_pet` | Dimension | Pet descriptive attributes at time of listing |
| `dim_product` | Dimension | References `dim_category` and `dim_supplier` — snowflake |
| `bridge_pet_tag` | **Bridge table** | Resolves M:N between `dim_pet` and tags |
| `fact_pet_sales` | **Fact** | Grain: one row per pet sold. Measures: `sale_price`, `days_to_sell` |
| `fact_product_sales` | **Fact** | Grain: one row per order-product line. Measures: `quantity`, `unit_price`, `line_total` |

### 3.3 SCD Type 2 — `dim_customer`

`dim_customer` tracks historical changes in customer location. The ETL script compares each incoming customer record against the current active row (`is_current = TRUE`). If the city or country differs:

1. The old record is **closed**: `valid_to` set to yesterday, `is_current = FALSE`
2. A **new row** is inserted with updated values and `is_current = TRUE`

If no change is detected, nothing happens. This allows historical analysis of where customers were located *when* they made a purchase.

### 3.4 Bridge Table — `bridge_pet_tag`

Because a pet can carry multiple tags (e.g. `vaccinated` AND `pedigree` AND `trained`), a direct FK from the fact table to a single tag would lose data. `bridge_pet_tag` holds all `(pet_key, tag_name)` combinations. Analytical queries join `fact_pet_sales` → `bridge_pet_tag` on `pet_key` to filter or group by tag.

---

## 4. Scripts — How to Run

### 4.1 Prerequisites

- PostgreSQL 18 or later installed and running
- A database created: `CREATE DATABASE petstore;`
- `psql` available on the command line (or pgAdmin / DBeaver)
- CSV files accessible on disk (update paths in `02_load_csv.sql` if needed)

### 4.2 Execution Order

| Step | File | What it does |
|------|------|-------------|
| 1 | `oltp/01_oltp_schema.sql` | Drops and recreates `petstore_oltp` with all tables, constraints, indexes |
| 2 | `oltp/02_load_csv.sql` | Loads all CSV files via staging tables + `ON CONFLICT DO NOTHING` |
| 3 | `olap/03_olap_schema.sql` | Drops and recreates `petstore_olap` with dimensions, bridge table, fact tables |
| 4 | `etl/04_etl_oltp_to_olap.sql` | Populates OLAP from OLTP: date spine, all dims (SCD Type 2), bridge, both facts |
| 5 | `queries/05_oltp_queries.sql` | Six analytical queries against the OLTP schema |
| 6 | `queries/06_olap_queries.sql` | Six analytical queries against the OLAP schema |

### 4.3 Running via psql

```bash
psql -U postgres -d petstore -f oltp/01_oltp_schema.sql
psql -U postgres -d petstore -f oltp/02_load_csv.sql
psql -U postgres -d petstore -f olap/03_olap_schema.sql
psql -U postgres -d petstore -f etl/04_etl_oltp_to_olap.sql
```

> Scripts are **safe to re-run**. The loader uses `ON CONFLICT DO NOTHING`; the ETL uses `NOT EXISTS` guards on both fact tables. No data is duplicated or overwritten on subsequent runs.

### 4.4 CSV Files

| File | Contents |
|------|----------|
| `categories.csv` | 9 pet and product categories |
| `breeds.csv` | 38 breeds across all categories |
| `tags.csv` | 14 descriptive pet tags |
| `suppliers.csv` | 8 international suppliers |
| `pets.csv` | 60 individual pets with codes, prices, statuses |
| `pet_tags.csv` | Tag assignments for all 60 pets |
| `products.csv` | 25 products across food, accessories, toys |
| `customers.csv` | 30 registered customers from 20+ countries |
| `orders.csv` | 50 orders spanning 2023–2024 |
| `order_pets.csv` | Pet line items for relevant orders |
| `order_products.csv` | Product line items for relevant orders |

---

## 5. Analytical Queries

### 5.1 OLTP Queries (`queries/05_oltp_queries.sql`)

| Query | Business question |
|-------|-------------------|
| Q1 | Top 5 best-selling pet breeds by total revenue |
| Q2 | Monthly order volume and revenue split: pets vs products |
| Q3 | Customers who made mixed orders (pet + products in one order) |
| Q4 | Most popular product categories by units sold and revenue |
| Q5 | Pet inventory status per category (available / pending / sold) |
| Q6 | Tags on sold pets and their average sale price |

### 5.2 OLAP Queries (`queries/06_olap_queries.sql`)

| Query | Business question |
|-------|-------------------|
| Q1 | Annual and quarterly pet revenue by category with % of quarter total |
| Q2 | Top 10 customers by lifetime spend (pets + products combined) |
| Q3 | Monthly product sales by supplier country |
| Q4 | Pet sell-time analysis by breed: avg / min / max days to sell |
| Q5 | Revenue by shipping country and payment method |
| Q6 | Tag influence on sale price via the bridge table |

---

## 7. Repository Structure

```
├── oltp/
│   ├── 01_oltp_schema.sql       # OLTP schema: all tables, constraints, indexes
│   └── 02_load_csv.sql          # CSV loader: idempotent, staging + ON CONFLICT
├── olap/
│   └── 03_olap_schema.sql       # OLAP schema: dims, bridge, fact tables, indexes
├── etl/
│   └── 04_etl_oltp_to_olap.sql  # ETL: date spine, SCD Type 2, NOT EXISTS guards
├── queries/
│   ├── 05_oltp_queries.sql      # 6 OLTP analytical queries
│   └── 06_olap_queries.sql      # 6 OLAP analytical queries
├── csv/
│   ├── categories.csv
│   ├── breeds.csv
│   ├── tags.csv
│   ├── suppliers.csv
│   ├── pets.csv
│   ├── pet_tags.csv
│   ├── products.csv
│   ├── customers.csv
│   ├── orders.csv
│   ├── order_pets.csv
│   └── order_products.csv
└── README.md                     # This file
```

