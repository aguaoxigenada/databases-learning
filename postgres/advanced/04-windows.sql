-- 04-windows.sql (Postgres)
-- Port of ../../sqlite/advanced/04-windows.sql. Window functions are
-- standard SQL; this file is nearly identical to the SQLite version.
-- Run with:  docker exec -i pg-learn psql -U postgres -d learn_pg < 04-windows.sql

DROP TABLE IF EXISTS sales_archive;
DROP TABLE IF EXISTS sales;

CREATE TABLE sales (
    id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product TEXT    NOT NULL,
    region  TEXT    NOT NULL,
    amount  INTEGER NOT NULL,
    sold_on DATE    NOT NULL
);

INSERT INTO sales (product, region, amount, sold_on) VALUES
    ('Widget', 'North', 100, '2025-01-05'),
    ('Widget', 'North', 150, '2025-01-18'),
    ('Widget', 'North', 120, '2025-02-02'),
    ('Widget', 'South', 200, '2025-01-10'),
    ('Widget', 'South', 180, '2025-02-08'),
    ('Gadget', 'North',  80, '2025-01-11'),
    ('Gadget', 'North', 110, '2025-02-19'),
    ('Gadget', 'South', 120, '2025-02-20'),
    ('Gadget', 'South',  95, '2025-03-02');

-- GROUP BY collapses rows. Window functions preserve them.
\echo '--- each sale, plus its region total ---'
SELECT product, region, amount,
       SUM(amount) OVER (PARTITION BY region) AS region_total
FROM sales
ORDER BY region, amount DESC;

-- Top N per group — the classic use of ROW_NUMBER.
\echo '--- top 2 sales per region ---'
WITH ranked AS (
    SELECT product, region, amount,
           ROW_NUMBER() OVER (PARTITION BY region ORDER BY amount DESC) AS rn
    FROM sales
)
SELECT region, product, amount
FROM ranked
WHERE rn <= 2
ORDER BY region, amount DESC;

-- ROW_NUMBER / RANK / DENSE_RANK tie-breaking.
\echo '--- row_number vs rank vs dense_rank on ties ---'
SELECT amount,
       ROW_NUMBER() OVER (ORDER BY amount DESC) AS rn,
       RANK()       OVER (ORDER BY amount DESC) AS rk,
       DENSE_RANK() OVER (ORDER BY amount DESC) AS drk
FROM sales;

-- Running total.
\echo '--- running total per region, by date ---'
SELECT region, sold_on, amount,
       SUM(amount) OVER (
           PARTITION BY region
           ORDER BY sold_on
       ) AS running_total
FROM sales
ORDER BY region, sold_on;

-- Moving average with an explicit frame.
\echo '--- 3-row moving average of amount per region ---'
SELECT region, sold_on, amount,
       ROUND(
           AVG(amount) OVER (
               PARTITION BY region
               ORDER BY sold_on
               ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
           ),
           1
       ) AS moving_avg_3
FROM sales
ORDER BY region, sold_on;

-- LAG / LEAD — peek at neighbouring rows.
\echo '--- each sale vs the previous sale in the same region ---'
SELECT region, sold_on, amount,
       LAG(amount) OVER (PARTITION BY region ORDER BY sold_on)          AS prev_amount,
       amount - LAG(amount) OVER (PARTITION BY region ORDER BY sold_on) AS delta
FROM sales
ORDER BY region, sold_on;

-- ---------------------------------------------------------------------------
-- Postgres tip: name the window once and reuse it with WINDOW.
-- Shorter and less error-prone when multiple functions share a window.
-- ---------------------------------------------------------------------------
\echo '--- three window functions, one named window ---'
SELECT region, sold_on, amount,
       SUM(amount)         OVER w AS running_total,
       ROW_NUMBER()        OVER w AS row_in_region,
       LAG(amount)         OVER w AS prev_amount
FROM sales
WINDOW w AS (PARTITION BY region ORDER BY sold_on)
ORDER BY region, sold_on;
