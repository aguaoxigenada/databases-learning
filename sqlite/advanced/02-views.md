# Views

Companion notes for `02-views.sql`. Goal: understand **what a view actually is**, **how to read its query body**, and **when to reach for one** instead of copy-pasting the same `SELECT` everywhere.

## What is a view?

A **view is a named `SELECT`**. It stores the **query**, not the data — every read re-runs the underlying query against live tables.

> Mental shortcut: a view is a **macro for SQL**. `CREATE VIEW name AS <query>` defines a name; every `SELECT FROM name` expands inline at read time.

| Concept | What it stores | When it computes |
|---------|----------------|------------------|
| **Table** | Rows | Once, on `INSERT` |
| **View** | A query | Every time you read from it |
| **Materialized view** (Postgres) | Cached rows + the query | On `REFRESH MATERIALIZED VIEW` |
| **CTE** (`WITH … AS`) | A query, scoped to one statement | Once per query that uses it |

SQLite has no native materialized view — you'd emulate one with a real table populated by a scheduled `INSERT INTO … SELECT …`.

## The setup

Two tables plus six rows of fake order data:

`customers`:

| id | name  | email             |
|----|-------|-------------------|
| 1  | Alice | alice@example.com |
| 2  | Bob   | bob@example.com   |
| 3  | Carol | carol@example.com |

`orders`:

| id | customer_id | total | status     |
|----|-------------|-------|------------|
| 1  | 1           | 100   | shipped    |
| 2  | 1           | 50    | shipped    |
| 3  | 1           | 80    | cancelled  |
| 4  | 2           | 200   | shipped    |
| 5  | 2           | 30    | pending    |
| 6  | 3           | 75    | pending    |

> Note: the `id` column on each table is `INTEGER PRIMARY KEY`, which in SQLite is an alias for the built-in `ROWID`. Skip the column in your `INSERT` and SQLite auto-assigns the next integer — that's why the inserts only list `(name, email)` yet the rows end up with `id = 1, 2, 3`.

## View 1 — `active_orders`: hide a filter behind a name

```sql
CREATE VIEW active_orders AS
SELECT id, customer_id, total, status
FROM orders
WHERE status != 'cancelled';
```

Now `SELECT * FROM active_orders;` returns:

| id | customer_id | total | status   |
|----|-------------|-------|----------|
| 1  | 1           | 100   | shipped  |
| 2  | 1           | 50    | shipped  |
| 4  | 2           | 200   | shipped  |
| 5  | 2           | 30    | pending  |
| 6  | 3           | 75    | pending  |

Cancelled orders disappear — but **only from the view's perspective**. The underlying `orders` table is untouched.

### "Stores the query, not the data" — what that really means

| Action | Effect on next `SELECT * FROM active_orders` |
|--------|-----------------------------------------------|
| `INSERT INTO orders (...) VALUES (..., 'shipped')` | new row **appears immediately** |
| `UPDATE orders SET status = 'cancelled' WHERE id = 4` | row **disappears immediately** |
| `DROP TABLE orders` | view is **broken** — there's nothing to query |

There's no "refresh" because there's nothing cached. Every read re-cooks the recipe.

### Views compose

You can `JOIN`, `WHERE`, `ORDER BY` a view exactly like a table:

```sql
SELECT c.name, o.total, o.status
FROM active_orders AS o
JOIN customers AS c ON c.id = o.customer_id;
```

SQLite expands the view inline, then runs the combined query — so composing on top of a view doesn't add a scan, it just adds extra `WHERE`/`JOIN` clauses to the same underlying query.

## View 2 — `customer_lifetime_value`: hide a JOIN + GROUP BY + conditional aggregate

```sql
CREATE VIEW customer_lifetime_value AS
SELECT
    c.id,
    c.name,
    COALESCE(SUM(CASE WHEN o.status = 'shipped' THEN o.total END), 0) AS lifetime_value,
    COUNT(CASE WHEN o.status = 'shipped' THEN 1 END)                   AS shipped_orders
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.id
GROUP BY c.id;
```

Output:

| id | name  | lifetime_value | shipped_orders |
|----|-------|----------------|----------------|
| 1  | Alice | 150            | 2              |
| 2  | Bob   | 200            | 1              |
| 3  | Carol | 0              | 0              |

This is where views earn their keep. Without it, every report that wants per-customer revenue has to copy-paste these 7 lines. With it, callers write `SELECT * FROM customer_lifetime_value WHERE lifetime_value > 100;` and move on.

### Line by line

#### `CREATE VIEW customer_lifetime_value AS`

Save the following query under that name. Nothing runs yet — this just registers the recipe in SQLite's catalog.

#### `SELECT c.id, c.name,`

Pick the customer's id and name. The `c.` prefix refers to the alias defined later (`customers AS c`).

#### `COALESCE(SUM(CASE WHEN o.status = 'shipped' THEN o.total END), 0) AS lifetime_value`

Three nested ideas. Read **inside-out**:

| Layer | What it does |
|-------|--------------|
| `CASE WHEN o.status = 'shipped' THEN o.total END` | For each joined row, return `o.total` if shipped, else `NULL` (no `ELSE` ⇒ implicit NULL). |
| `SUM(...)` | Add those numbers up. **`NULL`s are ignored by `SUM`**, so cancelled / pending orders contribute zero. |
| `COALESCE(..., 0)` | If the whole sum came back `NULL` (a customer with no orders at all), replace with `0`. |
| `AS lifetime_value` | Name the resulting column. |

This is the classic **conditional aggregation** pattern: filter inside the aggregate so you can compute multiple "sliced" totals from one pass over the data.

#### `COUNT(CASE WHEN o.status = 'shipped' THEN 1 END) AS shipped_orders`

Same trick, different aggregate:

- `CASE WHEN o.status = 'shipped' THEN 1 END` — yields `1` for shipped rows, `NULL` for everything else.
- `COUNT(...)` counts **only non-NULL values**, so it's effectively "count of shipped orders."

A subtle point: `COUNT(*)` would have counted *all* rows in the group, including cancelled and pending. `COUNT(CASE …)` lets you count a subset.

#### `FROM customers AS c`

Start with the customers table, aliased `c`.

#### `LEFT JOIN orders AS o ON o.customer_id = c.id`

For every customer, attach all their orders. **`LEFT JOIN`** is the key choice: customers with **zero matching orders still appear**, with `NULL` for every `o.*` column. A plain `JOIN` would silently drop them.

#### `GROUP BY c.id`

Collapse the joined rows back down to **one row per customer**. The aggregates (`SUM`, `COUNT`) compute their values *within* each group.

> Why group by `c.id` and not `c.name`? Two customers could share a name; `id` is unique. Selecting `c.name` alongside it works because `name` is functionally dependent on `id` — SQLite (and modern Postgres) is fine with this.

### Stepwise trace

Imagine the engine evaluates it in this order:

**1. FROM + LEFT JOIN** — produce the joined rowset:

| c.id | c.name | o.status   | o.total |
|------|--------|------------|---------|
| 1    | Alice  | shipped    | 100     |
| 1    | Alice  | shipped    | 50      |
| 1    | Alice  | cancelled  | 80      |
| 2    | Bob    | shipped    | 200     |
| 2    | Bob    | pending    | 30      |
| 3    | Carol  | pending    | 75      |

**2. GROUP BY c.id** — partition into three groups (Alice: 3 rows, Bob: 2 rows, Carol: 1 row).

**3. Aggregate within each group** — apply the `CASE` to each row, then `SUM` / `COUNT`:

| Group | totals after CASE | SUM | "1"s after CASE | COUNT |
|-------|-------------------|-----|-----------------|-------|
| Alice | 100, 50, NULL     | 150 | 1, 1, NULL      | 2     |
| Bob   | 200, NULL         | 200 | 1, NULL         | 1     |
| Carol | NULL              | NULL → **COALESCE → 0** | NULL | 0 |

**4. Project the output columns** — `c.id, c.name, lifetime_value, shipped_orders`. Done.

### Why these specific tools?

| Tool | Replaces what naive approach? | Why it's better |
|------|-------------------------------|-----------------|
| `LEFT JOIN` | `JOIN` | Keeps customers with no (matching) orders. |
| `CASE WHEN ... THEN ... END` | A `WHERE status = 'shipped'` filter | A `WHERE` would drop Carol entirely; the `CASE` keeps her row but contributes `NULL` to the aggregate. |
| `COALESCE(..., 0)` | Returning `NULL` | Reports look cleaner with `0` than `NULL`. |
| Conditional aggregation | Multiple separate queries | One pass over the data, multiple metrics. |

### The pivot-style power move

Once you've internalized `SUM(CASE WHEN cond THEN x END)`, you can compute many slices at once:

```sql
SELECT c.id, c.name,
    SUM(CASE WHEN o.status = 'shipped'   THEN o.total END) AS shipped_value,
    SUM(CASE WHEN o.status = 'pending'   THEN o.total END) AS pending_value,
    SUM(CASE WHEN o.status = 'cancelled' THEN o.total END) AS cancelled_value
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.id
GROUP BY c.id;
```

One scan, three metrics, clean output. This is essentially a hand-rolled **pivot table**.

## Filtering on top of a view

The view is just a named subquery, so you can stack `WHERE` on top:

```sql
SELECT name, lifetime_value
FROM customer_lifetime_value
WHERE lifetime_value > 100;
```

SQLite expands this to the equivalent of:

```sql
SELECT name, lifetime_value
FROM (<the view's body>)
WHERE lifetime_value > 100;
```

…and the planner often pushes filters down efficiently.

## When to use views

| Reason | Example |
|--------|---------|
| **Readability** — give a complex query a meaningful name | `active_orders`, `customer_lifetime_value` |
| **DRY** — one place to change the definition | Add `'refunded'` to the exclusion list once, every consumer benefits |
| **API stability** — keep the public shape stable while you refactor underlying tables | Split `orders` into two tables, rebuild the view, callers don't notice |
| **Permissions** — grant access to a view instead of raw tables (Postgres/MySQL) | Expose `customer_lifetime_value` to analysts without exposing PII columns |

## Watch out for

| Pitfall | Reality |
|---------|---------|
| "Views speed up queries" | **No** — a view re-executes its body every read. A slow query is still slow when wrapped in a view. |
| "I can `INSERT` into a view" | In SQLite, **no** by default — views are read-only unless you write `INSTEAD OF` triggers. |
| "Views cache results" | They don't. **Materialized views** do; SQLite has no native materialized view, you'd fake one with a table + scheduled refresh. |

## Inspecting views

Same trick as inspecting indexes — query `sqlite_master`:

```sql
SELECT name FROM sqlite_master WHERE type = 'view';
SELECT sql  FROM sqlite_master WHERE type = 'view' AND name = 'customer_lifetime_value';
```

The `sql` column holds the original `CREATE VIEW …` statement, exactly as you typed it.

## Mental model

> A view is a **shortcut, not a snapshot**. It saves typing, not work. Every read re-runs the recipe against live data.

## Engine comparison

| Concept | SQLite | PostgreSQL | MySQL |
|---------|--------|------------|-------|
| Plain view | `CREATE VIEW` | `CREATE VIEW` | `CREATE VIEW` |
| Materialized view | Not native — emulate with table + scheduled refresh | `CREATE MATERIALIZED VIEW` + `REFRESH` | Not native |
| Updatable view | Read-only by default; `INSTEAD OF` triggers needed | Some auto-updatable; otherwise `INSTEAD OF` triggers | Updatable if simple (single-table, no aggregation) |
| Conditional aggregate | `SUM(CASE WHEN ... THEN x END)` | Same, **or** `SUM(x) FILTER (WHERE ...)` (cleaner) | `SUM(CASE WHEN ... THEN x END)` |

## Running

```bash
# from inside sqlite/advanced/
sqlite3 advanced.db < 02-views.sql
```

The script drops and recreates the views and tables each run, so it's safe to re-execute. For aligned-column output:

```bash
sqlite3 -header -column advanced.db < 02-views.sql
```
