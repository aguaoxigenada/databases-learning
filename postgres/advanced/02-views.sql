-- 02-views.sql (Postgres)
-- Port of ../../sqlite/advanced/02-views.sql, plus the Postgres-only
-- MATERIALIZED VIEW (a view whose result is cached on disk).
-- Run with:  docker exec -i pg-learn psql -U postgres -d learn_pg < 02-views.sql

DROP MATERIALIZED VIEW IF EXISTS customer_lifetime_value_mat;
DROP VIEW IF EXISTS customer_lifetime_value;
DROP VIEW IF EXISTS active_orders;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    id    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name  TEXT    NOT NULL,
    email TEXT    NOT NULL UNIQUE
);

CREATE TABLE orders (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id),
    total       INTEGER NOT NULL,
    status      TEXT    NOT NULL
);

INSERT INTO customers (name, email) VALUES
    ('Alice', 'alice@example.com'),
    ('Bob',   'bob@example.com'),
    ('Carol', 'carol@example.com');

INSERT INTO orders (customer_id, total, status) VALUES
    (1, 100, 'shipped'),
    (1,  50, 'shipped'),
    (1,  80, 'cancelled'),
    (2, 200, 'shipped'),
    (2,  30, 'pending'),
    (3,  75, 'pending');

-- ---------------------------------------------------------------------------
-- Regular view — same semantics as SQLite. Stores the query, not the data.
-- ---------------------------------------------------------------------------
CREATE VIEW active_orders AS
SELECT id, customer_id, total, status
FROM orders
WHERE status <> 'cancelled';

\echo '--- all active orders ---'
SELECT * FROM active_orders;

\echo '--- active orders with customer names ---'
SELECT c.name, o.total, o.status
FROM active_orders AS o
JOIN customers AS c ON c.id = o.customer_id;

-- ---------------------------------------------------------------------------
-- View for an aggregation — hide the JOIN + GROUP BY + SUM behind a name.
-- FILTER (WHERE ...) is a Postgres/SQL-standard tidier alternative to
-- SUM(CASE WHEN ... THEN ... END). Works in Postgres, not in SQLite.
-- ---------------------------------------------------------------------------
CREATE VIEW customer_lifetime_value AS
SELECT
    c.id,
    c.name,
    COALESCE(SUM(o.total) FILTER (WHERE o.status = 'shipped'), 0) AS lifetime_value,
    COUNT(*) FILTER (WHERE o.status = 'shipped')                  AS shipped_orders
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.id
GROUP BY c.id, c.name;

\echo '--- customer lifetime value (via view) ---'
SELECT * FROM customer_lifetime_value ORDER BY lifetime_value DESC;

-- ---------------------------------------------------------------------------
-- MATERIALIZED VIEW — Postgres only.
-- The query runs ONCE at creation time; results are stored on disk.
-- Subsequent reads are table-speed, no joins re-executed.
-- You must REFRESH MATERIALIZED VIEW <name> to pick up data changes.
-- ---------------------------------------------------------------------------
CREATE MATERIALIZED VIEW customer_lifetime_value_mat AS
SELECT
    c.id,
    c.name,
    COALESCE(SUM(o.total) FILTER (WHERE o.status = 'shipped'), 0) AS lifetime_value
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.id
GROUP BY c.id, c.name;

\echo '--- materialized view result (first read) ---'
SELECT * FROM customer_lifetime_value_mat ORDER BY lifetime_value DESC;

-- Simulate new data.
INSERT INTO orders (customer_id, total, status) VALUES (3, 1000, 'shipped');

\echo '--- regular view sees the new row immediately ---'
SELECT * FROM customer_lifetime_value WHERE name = 'Carol';

\echo '--- materialized view does NOT (stale) ---'
SELECT * FROM customer_lifetime_value_mat WHERE name = 'Carol';

-- Refresh the cache.
REFRESH MATERIALIZED VIEW customer_lifetime_value_mat;

\echo '--- materialized view after REFRESH ---'
SELECT * FROM customer_lifetime_value_mat WHERE name = 'Carol';

-- ---------------------------------------------------------------------------
-- When to reach for each
-- ---------------------------------------------------------------------------
-- VIEW                — the query is cheap, and you want always-fresh data.
-- MATERIALIZED VIEW   — the query is expensive, staleness is acceptable,
--                       you can schedule refreshes (nightly, hourly, etc.).
--                       Common use: reporting dashboards off a huge fact table.
--
-- Materialized views can have their own indexes — treat them like tables.
--
-- CREATE INDEX idx_mv_customer ON customer_lifetime_value_mat(id);

\echo '--- all views and materialized views in this schema ---'
SELECT table_name, table_type FROM information_schema.tables
WHERE table_schema = 'public' AND table_type IN ('VIEW', 'BASE TABLE')
  AND table_name LIKE 'customer%' OR table_name = 'active_orders';
