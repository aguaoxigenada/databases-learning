-- 02-views.sql
-- Goal: use views to give complex queries a name, so the rest of your
-- code (or your brain) can treat them like tables.
-- Run with:  sqlite3 advanced.db < 02-views.sql

DROP VIEW IF EXISTS active_orders;
DROP VIEW IF EXISTS customer_lifetime_value;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    id    INTEGER PRIMARY KEY,
    name  TEXT    NOT NULL,
    email TEXT    NOT NULL UNIQUE
);

CREATE TABLE orders (
    id          INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    total       INTEGER NOT NULL,
    status      TEXT    NOT NULL,  -- 'pending' | 'shipped' | 'cancelled'
    FOREIGN KEY (customer_id) REFERENCES customers(id)
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
-- A view is a named SELECT. It stores the QUERY, not the data — every time
-- you read from it, SQLite re-runs the underlying query.
-- ---------------------------------------------------------------------------
CREATE VIEW active_orders AS
SELECT id, customer_id, total, status
FROM orders
WHERE status != 'cancelled';

-- Query a view exactly like a table:
SELECT '--- all active orders ---' AS section;
SELECT * FROM active_orders;

-- Views compose — you can SELECT / JOIN / filter a view just like any table.
SELECT '--- active orders with customer names ---' AS section;
SELECT c.name, o.total, o.status
FROM active_orders AS o
JOIN customers AS c ON c.id = o.customer_id;

-- ---------------------------------------------------------------------------
-- Views for aggregations — hide the JOIN + GROUP BY + SUM boilerplate behind
-- a clean name the rest of the app can use without re-learning the schema.
-- ---------------------------------------------------------------------------
CREATE VIEW customer_lifetime_value AS
SELECT
    c.id,
    c.name,
    COALESCE(SUM(CASE WHEN o.status = 'shipped' THEN o.total END), 0) AS lifetime_value,
    COUNT(CASE WHEN o.status = 'shipped' THEN 1 END)                   AS shipped_orders
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.id
GROUP BY c.id;

SELECT '--- customer lifetime value (via view) ---' AS section;
SELECT * FROM customer_lifetime_value ORDER BY lifetime_value DESC;

-- Filter on top of the view — the view is just a named subquery.
SELECT '--- customers with > $100 lifetime value ---' AS section;
SELECT name, lifetime_value
FROM customer_lifetime_value
WHERE lifetime_value > 100;

-- ---------------------------------------------------------------------------
-- When to use views
-- ---------------------------------------------------------------------------
-- + Hide complex JOINs/aggregations behind a readable name.
-- + Provide a stable "API" for reports even if the underlying tables change.
-- + Restrict access (GRANT on a view instead of the raw table) — more
--   relevant in Postgres/MySQL than SQLite, which doesn't really do roles.
--
-- Watch out:
-- - A view is re-executed on every query. A slow underlying query is still
--   slow. Postgres has MATERIALIZED VIEW (cached result); SQLite doesn't —
--   you'd emulate one with a real table + a scheduled refresh.
-- - SQLite views are read-only by default. INSERT/UPDATE/DELETE through a
--   view needs INSTEAD OF triggers (out of scope here).

SELECT '--- all views in this database ---' AS section;
SELECT name FROM sqlite_master WHERE type = 'view';
