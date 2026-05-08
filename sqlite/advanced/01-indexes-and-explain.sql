-- 01-indexes-and-explain.sql
-- Goal: understand why some queries are slow, how an index fixes them,
-- and how to *verify* the fix by reading the query plan.
-- Run with:  sqlite3 advanced.db < 01-indexes-and-explain.sql
-- sqlite3 -header -column advanced.db < 01-indexes-and-explain.sql

DROP TABLE IF EXISTS products;
CREATE TABLE products (
    id          INTEGER PRIMARY KEY,
    name        TEXT    NOT NULL,
    category_id INTEGER NOT NULL,
    price       INTEGER NOT NULL
);

-- Generate 10 000 rows so the plan difference is visible.
-- Recursive CTE is SQLite's idiom for a number sequence (you'll see more of
-- these in 03-ctes.sql).
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 10000
)
INSERT INTO products (id, name, category_id, price)
SELECT n, 'Product ' || n, (n % 20) + 1, (n % 100) + 10
FROM seq;

-- ---------------------------------------------------------------------------
-- What EXPLAIN QUERY PLAN tells you
-- ---------------------------------------------------------------------------
-- SQLite prints, for each step of your query, HOW it plans to retrieve rows.
-- The two words to watch for:
--   SCAN  — walk every row of the table. O(n). Fine for small tables.
--   SEARCH — jump straight to matching rows via an index. O(log n).
-- On 10 000 rows the difference is small; on 10 000 000 it's the difference
-- between 2ms and 2 minutes.

SELECT '--- plan WITHOUT an index on category_id ---' AS section;
EXPLAIN QUERY PLAN
SELECT * FROM products WHERE category_id = 5;
-- You'll see something like: SCAN products

SELECT '--- rows: category_id = 5 (no index — count + first 5) ---' AS section;
SELECT COUNT(*) AS matching_rows FROM products WHERE category_id = 5;
SELECT * FROM products WHERE category_id = 5 LIMIT 5;

-- ---------------------------------------------------------------------------
-- Create an index. Indexes are a separate B-tree structure on disk that maps
-- (indexed value) -> (row location). They're auto-updated on INSERT/UPDATE.
-- Cost: extra disk space + slightly slower writes. Benefit: fast reads.
-- ---------------------------------------------------------------------------
CREATE INDEX idx_products_category ON products(category_id);

SELECT '--- plan WITH the index ---' AS section;
EXPLAIN QUERY PLAN
SELECT * FROM products WHERE category_id = 5;
-- Now: SEARCH products USING INDEX idx_products_category

SELECT '--- rows: category_id = 5 (with index — count + first 5, same data, faster) ---' AS section;
SELECT COUNT(*) AS matching_rows FROM products WHERE category_id = 5;
SELECT * FROM products WHERE category_id = 5 LIMIT 5;

-- ---------------------------------------------------------------------------
-- Composite indexes — order matters.
-- An index on (category_id, price) helps queries that filter by category_id
-- alone, or by BOTH category_id and price — but NOT by price alone.
-- Think "phone book": sorted by last name, then first name. Useless for
-- looking up people by first name only.
-- ---------------------------------------------------------------------------
CREATE INDEX idx_products_cat_price ON products(category_id, price);

SELECT '--- composite index DOES help (filter matches its leading column) ---' AS section;
EXPLAIN QUERY PLAN
SELECT * FROM products WHERE category_id = 5 AND price > 50;

SELECT '--- rows: category_id = 5 AND price > 50 (count + first 5) ---' AS section;
SELECT COUNT(*) AS matching_rows FROM products WHERE category_id = 5 AND price > 50;
SELECT * FROM products WHERE category_id = 5 AND price > 50 LIMIT 5;

SELECT '--- composite index DOES NOT help (filter skips the leading column) ---' AS section;
EXPLAIN QUERY PLAN
SELECT * FROM products WHERE price > 50;
-- Back to SCAN — the index on (category_id, price) is unusable here.

SELECT '--- rows: price > 50 (count + first 5) ---' AS section;
SELECT COUNT(*) AS matching_rows FROM products WHERE price > 50;
SELECT * FROM products WHERE price > 50 LIMIT 5;

-- ---------------------------------------------------------------------------
-- UNIQUE indexes — double duty: speed AND a constraint.
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX idx_products_name ON products(name);
-- Now INSERT INTO products (...) VALUES ('Product 1', ...) will fail.

-- ---------------------------------------------------------------------------
-- When NOT to index
-- ---------------------------------------------------------------------------
-- - Tiny tables (< a few thousand rows) — scan is faster than index lookup.
-- - Columns you rarely filter or join on.
-- - Columns with very few distinct values (boolean-like): the index barely
--   narrows the search.
-- Writes get slightly slower with every index. Measure, don't guess.

SELECT '--- list all indexes on products ---' AS section;
SELECT name, sql FROM sqlite_master WHERE type = 'index' AND tbl_name = 'products';
