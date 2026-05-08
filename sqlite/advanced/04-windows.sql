-- 04-windows.sql
-- Goal: use window functions — aggregates that DON'T collapse rows.
-- The moment you need "for each row, also tell me something about its
-- neighbours", reach for a window function.
-- Run with:  sqlite3 advanced.db < 04-windows.sql
-- sqlite3 -header -column advanced.db < 04-windows.sql

DROP TABLE IF EXISTS sales;

CREATE TABLE sales (
    id      INTEGER PRIMARY KEY,
    product TEXT    NOT NULL,
    region  TEXT    NOT NULL,
    amount  INTEGER NOT NULL,
    sold_on TEXT    NOT NULL
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

-- ---------------------------------------------------------------------------
-- GROUP BY collapses rows ("for each region, give me the total").
-- Window functions preserve rows ("for each sale, ALSO show me the
-- region's total"). The magic word is OVER.
-- ---------------------------------------------------------------------------

-- SUM() OVER (PARTITION BY region) gives each row its region's total,
-- without losing the row. PARTITION BY = "group the window", not the output.
SELECT '--- each sale, plus its region total ---' AS section;
SELECT product, region, amount,
       SUM(amount) OVER (PARTITION BY region) AS region_total
FROM sales
ORDER BY region, amount DESC;

-- ---------------------------------------------------------------------------
-- ROW_NUMBER / RANK / DENSE_RANK — numbering rows within a partition.
-- Classic use: "top N per group".
-- ---------------------------------------------------------------------------
SELECT '--- top 2 sales per region ---' AS section;
WITH ranked AS (
    SELECT product, region, amount,
           ROW_NUMBER() OVER (PARTITION BY region ORDER BY amount DESC) AS rn
    FROM sales
)
SELECT region, product, amount
FROM ranked
WHERE rn <= 2
ORDER BY region, amount DESC;

-- Difference between the three:
--   ROW_NUMBER — always 1,2,3,4,... even on ties.
--   RANK       — ties share a rank, then the next rank SKIPS: 1,2,2,4.
--   DENSE_RANK — ties share a rank, no skip:                 1,2,2,3.
SELECT '--- row_number vs rank vs dense_rank on ties ---' AS section;
SELECT amount,
       ROW_NUMBER() OVER (ORDER BY amount DESC) AS rn,
       RANK()       OVER (ORDER BY amount DESC) AS rk,
       DENSE_RANK() OVER (ORDER BY amount DESC) AS drk
FROM sales;

-- ---------------------------------------------------------------------------
-- Running totals. Add ORDER BY inside OVER to turn the window into
-- "everything up to and including this row, in order".
-- ---------------------------------------------------------------------------
SELECT '--- running total per region, by date ---' AS section;
SELECT region, sold_on, amount,
       SUM(amount) OVER (
           PARTITION BY region
           ORDER BY sold_on
       ) AS running_total
FROM sales
ORDER BY region, sold_on;

-- ---------------------------------------------------------------------------
-- Moving averages. Explicit frame: "this row plus the previous 2".
-- Frames are the most powerful (and most confusing) part of windowing.
-- ---------------------------------------------------------------------------
SELECT '--- 3-row moving average of amount per region ---' AS section;
SELECT region, sold_on, amount,
       AVG(amount) OVER (
           PARTITION BY region
           ORDER BY sold_on
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ) AS moving_avg_3
FROM sales
ORDER BY region, sold_on;

-- ---------------------------------------------------------------------------
-- LAG / LEAD — peek at the previous or next row's value. Perfect for
-- "difference from last period".
-- ---------------------------------------------------------------------------
SELECT '--- each sale vs the previous sale in the same region ---' AS section;
SELECT region, sold_on, amount,
       LAG(amount) OVER (PARTITION BY region ORDER BY sold_on)           AS prev_amount,
       amount - LAG(amount) OVER (PARTITION BY region ORDER BY sold_on)  AS delta
FROM sales
ORDER BY region, sold_on;

-- ---------------------------------------------------------------------------
-- When window functions earn their keep
-- ---------------------------------------------------------------------------
-- Anything that starts with "for each row, compare it to..." or "cumulative
-- something over time" would otherwise need a self-join or app-code loop.
-- Window functions do it in one pass, in SQL, and are portable (Postgres,
-- MySQL 8+, SQL Server all support these).
