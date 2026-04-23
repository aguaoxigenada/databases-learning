-- 01-indexes-and-explain.sql (Postgres)
-- Port of ../../sqlite/advanced/01-indexes-and-explain.sql, with two upgrades:
--   - EXPLAIN ANALYZE runs the query and reports REAL execution time per step.
--   - Postgres ships several index types SQLite doesn't (GIN, GiST, BRIN).
-- Run with:  docker exec -i pg-learn psql -U postgres -d learn_pg < 01-indexes-and-explain.sql

DROP TABLE IF EXISTS products;
CREATE TABLE products (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        TEXT    NOT NULL,
    category_id INTEGER NOT NULL,
    price       INTEGER NOT NULL
);

-- SQLite needed a recursive CTE to generate numbers. Postgres ships
-- `generate_series`, a set-returning function — much cleaner.
INSERT INTO products (name, category_id, price)
SELECT 'Product ' || n, (n % 20) + 1, (n % 100) + 10
FROM generate_series(1, 10000) AS n;

-- ---------------------------------------------------------------------------
-- EXPLAIN vs EXPLAIN ANALYZE
--   EXPLAIN          — show the plan only. Cheap. Same idea as SQLite's.
--   EXPLAIN ANALYZE  — run the query AND show the plan annotated with real
--                      timings and row counts. This is the debugging tool.
-- ---------------------------------------------------------------------------

\echo '--- plan WITHOUT an index on category_id ---'
EXPLAIN ANALYZE
SELECT * FROM products WHERE category_id = 5;
-- Expect "Seq Scan on products" with a "rows removed by filter" number.

-- Create an index. Postgres defaults to B-tree; name it explicitly when
-- learning so `\di` output is readable.
CREATE INDEX idx_products_category ON products(category_id);

-- Postgres uses statistics to pick a plan; tell it to refresh stats on our
-- new index so the planner knows it exists. (Usually autovacuum handles this;
-- for a freshly-loaded demo table we do it manually.)
ANALYZE products;

\echo '--- plan WITH the index ---'
EXPLAIN ANALYZE
SELECT * FROM products WHERE category_id = 5;
-- Now: "Index Scan" or "Bitmap Index Scan" — much cheaper.

-- ---------------------------------------------------------------------------
-- Composite indexes — same rule as SQLite: leading column is queen.
-- ---------------------------------------------------------------------------
CREATE INDEX idx_products_cat_price ON products(category_id, price);
ANALYZE products;

\echo '--- composite DOES help (matches leading column) ---'
EXPLAIN ANALYZE
SELECT * FROM products WHERE category_id = 5 AND price > 50;

\echo '--- composite does NOT help (skips leading column) ---'
EXPLAIN ANALYZE
SELECT * FROM products WHERE price > 50;
-- Back to Seq Scan — the (category_id, price) index can't accelerate
-- "price > 50" alone.

-- ---------------------------------------------------------------------------
-- UNIQUE indexes — same double duty as SQLite.
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX idx_products_name ON products(name);

-- ---------------------------------------------------------------------------
-- Index types Postgres has that SQLite doesn't
-- ---------------------------------------------------------------------------
-- B-TREE (default)  — equality + range. What you use 95% of the time.
-- HASH              — equality only. Slightly faster than B-tree for equality,
--                     rarely worth the loss of range support.
-- GIN               — "multi-value": JSONB contents, array contents,
--                     full-text search. You'll use this in 05-jsonb-and-arrays.
-- GiST              — geometry, ranges, trigram similarity. PostGIS relies on it.
-- BRIN              — tiny, coarse-grained index for huge tables with
--                     physical ordering (e.g. time-series with a sort-of-sorted
--                     created_at). 1000× smaller than B-tree, much less precise.

\echo '--- all indexes on products ---'
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'products';

-- ---------------------------------------------------------------------------
-- Reading EXPLAIN ANALYZE output — the cheat sheet
-- ---------------------------------------------------------------------------
-- Seq Scan              → reading every row. Fine for small tables, slow for big.
-- Index Scan            → jumping to matching rows via an index. Fast.
-- Bitmap Index Scan     → index finds row locations in bulk, then fetches
--                         them in disk order. Good when many rows match.
-- Nested Loop           → for each row on one side, probe the other. Fast for small sides.
-- Hash Join             → builds a hash of one side, probes with the other. Fast for big.
-- Merge Join            → sorts both sides, walks in lockstep. Good when already sorted.
-- "actual time=X..Y"    → wall-clock of that step, first-row..last-row, in ms.
-- "rows=N"              → how many rows the planner ESTIMATED. Wildly off means
--                         statistics are stale → run ANALYZE.
