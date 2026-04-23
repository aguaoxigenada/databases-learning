-- 03-ctes.sql
-- Goal: use CTEs ("Common Table Expressions", the `WITH` clause) to break
-- complex queries into readable named steps — and to do things a plain
-- SELECT can't, via recursion.
-- Run with:  sqlite3 advanced.db < 03-ctes.sql

DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS employees;

CREATE TABLE sales (
    id         INTEGER PRIMARY KEY,
    product    TEXT    NOT NULL,
    region     TEXT    NOT NULL,
    amount     INTEGER NOT NULL,
    sold_on    TEXT    NOT NULL  -- ISO date as text; SQLite has no DATE type
);

INSERT INTO sales (product, region, amount, sold_on) VALUES
    ('Widget',  'North', 100, '2025-01-05'),
    ('Widget',  'North', 150, '2025-01-18'),
    ('Widget',  'South', 200, '2025-02-02'),
    ('Gadget',  'North',  80, '2025-01-11'),
    ('Gadget',  'South', 120, '2025-02-20'),
    ('Gizmo',   'North',  50, '2025-03-07'),
    ('Gizmo',   'South',  90, '2025-03-15');

-- ---------------------------------------------------------------------------
-- Basic CTE: think of it as a temporary named table that exists only for the
-- duration of the query. Great for making multi-step logic readable.
-- ---------------------------------------------------------------------------
SELECT '--- above-average sales, by region ---' AS section;
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

-- ---------------------------------------------------------------------------
-- Multiple CTEs, chained — each one can reference earlier ones. This is
-- where CTEs start earning their keep: code you can read top-to-bottom.
-- ---------------------------------------------------------------------------
SELECT '--- regions whose total beat the overall average ---' AS section;
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
FROM region_totals AS rt, overall AS o
WHERE rt.total > o.avg_total;

-- ---------------------------------------------------------------------------
-- RECURSIVE CTE — the CTE references itself. Two uses you'll hit often:
--
--   1. Generating sequences (rows out of thin air) — shown above in
--      01-indexes-and-explain.sql to populate the products table.
--   2. Walking hierarchies (managers -> reports -> reports' reports -> ...).
-- ---------------------------------------------------------------------------

-- Hierarchy example: a tiny org chart.
CREATE TABLE employees (
    id         INTEGER PRIMARY KEY,
    name       TEXT    NOT NULL,
    manager_id INTEGER,             -- NULL = top of the tree
    FOREIGN KEY (manager_id) REFERENCES employees(id)
);

INSERT INTO employees (id, name, manager_id) VALUES
    (1, 'Ada',    NULL),
    (2, 'Bella',  1),
    (3, 'Cleo',   1),
    (4, 'Dev',    2),
    (5, 'Eli',    2),
    (6, 'Fatou',  4);

-- Find everyone in Ada's reporting chain — including reports of reports.
-- The recursive CTE has two parts joined by UNION ALL:
--   - the "anchor" row(s): where the walk starts.
--   - the "recursive" step: one level deeper, computed from the current set.
-- SQLite keeps iterating the recursive step until it produces no new rows.
SELECT '--- everyone under Ada (any depth) ---' AS section;
WITH RECURSIVE subordinates AS (
    -- anchor: direct reports of Ada
    SELECT id, name, manager_id, 1 AS depth
    FROM employees
    WHERE manager_id = 1

    UNION ALL

    -- recursive step: reports of anyone already in the set
    SELECT e.id, e.name, e.manager_id, s.depth + 1
    FROM employees AS e
    JOIN subordinates AS s ON e.manager_id = s.id
)
SELECT depth, name FROM subordinates ORDER BY depth, name;

-- ---------------------------------------------------------------------------
-- CTE vs subquery — they express the same thing, but CTEs:
--   + Can be referenced multiple times in the outer query.
--   + Can be recursive (subqueries can't).
--   + Read top-to-bottom, which matches how you think about the problem.
-- Use CTEs when the query has more than one meaningful step.
-- ---------------------------------------------------------------------------
