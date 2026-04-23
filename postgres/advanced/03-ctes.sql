-- 03-ctes.sql (Postgres)
-- Port of ../../sqlite/advanced/03-ctes.sql. CTEs are standard SQL — what
-- worked there works here. One Postgres extra at the bottom: CTEs in DML.
-- Run with:  docker exec -i pg-learn psql -U postgres -d learn_pg < 03-ctes.sql

DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS employees;

CREATE TABLE sales (
    id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product TEXT    NOT NULL,
    region  TEXT    NOT NULL,
    amount  INTEGER NOT NULL,
    sold_on DATE    NOT NULL  -- Postgres has a real DATE type (SQLite uses TEXT)
);

INSERT INTO sales (product, region, amount, sold_on) VALUES
    ('Widget', 'North', 100, '2025-01-05'),
    ('Widget', 'North', 150, '2025-01-18'),
    ('Widget', 'South', 200, '2025-02-02'),
    ('Gadget', 'North',  80, '2025-01-11'),
    ('Gadget', 'South', 120, '2025-02-20'),
    ('Gizmo',  'North',  50, '2025-03-07'),
    ('Gizmo',  'South',  90, '2025-03-15');

-- Basic CTE.
\echo '--- above-average sales, by region ---'
WITH regional_averages AS (
    SELECT region, AVG(amount) AS avg_amount
    FROM sales
    GROUP BY region
)
SELECT s.product, s.region, s.amount, ra.avg_amount
FROM sales AS s
JOIN regional_averages AS ra ON ra.region = s.region
WHERE s.amount > ra.avg_amount
ORDER BY s.region, s.amount DESC;

-- Multiple CTEs — readable top-to-bottom.
\echo '--- regions whose total beat the overall average ---'
WITH
    region_totals AS (
        SELECT region, SUM(amount) AS total
        FROM sales
        GROUP BY region
    ),
    overall AS (
        SELECT AVG(total) AS avg_total FROM region_totals
    )
SELECT rt.region, rt.total
FROM region_totals AS rt
CROSS JOIN overall AS o
WHERE rt.total > o.avg_total;
-- Postgres requires `CROSS JOIN` (or an explicit JOIN clause) here —
-- "FROM a, b" works but triggers a warning in some linters. Pick the
-- explicit form.

-- Recursive CTE — walking an org chart, same as SQLite.
CREATE TABLE employees (
    id         INTEGER PRIMARY KEY,
    name       TEXT    NOT NULL,
    manager_id INTEGER REFERENCES employees(id)
);

INSERT INTO employees (id, name, manager_id) VALUES
    (1, 'Ada',    NULL),
    (2, 'Bella',  1),
    (3, 'Cleo',   1),
    (4, 'Dev',    2),
    (5, 'Eli',    2),
    (6, 'Fatou',  4);

\echo '--- everyone under Ada (any depth) ---'
WITH RECURSIVE subordinates AS (
    SELECT id, name, manager_id, 1 AS depth
    FROM employees
    WHERE manager_id = 1

    UNION ALL

    SELECT e.id, e.name, e.manager_id, s.depth + 1
    FROM employees AS e
    JOIN subordinates AS s ON e.manager_id = s.id
)
SELECT depth, name FROM subordinates ORDER BY depth, name;

-- ---------------------------------------------------------------------------
-- Postgres extra: CTEs in DML with RETURNING
-- You can chain INSERT/UPDATE/DELETE through CTEs. Each statement can
-- RETURN rows the next step consumes. Pure SQL data pipelines.
-- ---------------------------------------------------------------------------

-- Find Widget rows over 100, archive them into a shadow table, delete the
-- originals — all in ONE statement.
-- LIKE sales copies the columns only. INCLUDING ALL would copy the
-- GENERATED ALWAYS identity on id, and our INSERT below needs to preserve
-- the original ids from `sales`. Plain LIKE is what we want here.
CREATE TABLE IF NOT EXISTS sales_archive (LIKE sales);
TRUNCATE sales_archive;

\echo '--- moving Widget sales > 100 into archive in one statement ---'
WITH moved AS (
    DELETE FROM sales
    WHERE product = 'Widget' AND amount > 100
    RETURNING *
)
INSERT INTO sales_archive
SELECT * FROM moved
RETURNING id, product, amount;

\echo '--- remaining sales ---'
SELECT id, product, region, amount FROM sales ORDER BY id;

\echo '--- archive ---'
SELECT id, product, region, amount FROM sales_archive ORDER BY id;
