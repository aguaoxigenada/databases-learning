# Indexes & `EXPLAIN QUERY PLAN`

Companion notes for `01-indexes-and-explain.sql`. Goal: understand **why a query is slow**, **how an index fixes it**, and **how to verify the fix** instead of guessing.

## The setup

The script builds a `products` table and bulk-loads 10,000 rows so the planner's choice actually matters:

| id | name        | category_id | price |
|----|-------------|-------------|-------|
| 1  | Product 1   | 2           | 11    |
| 2  | Product 2   | 3           | 12    |
| ...| ...         | ...         | ...   |
|10000| Product 10000| 1         | 10    |

`category_id` cycles 1..20, `price` cycles 10..109. Rows are spread across categories and price bands so filters are realistic.

## How the 10 000 rows are generated

SQLite has no `generate_series`, so the script uses a **recursive CTE** as a number generator, then a regular `INSERT ... SELECT` to turn each number into a row.

```sql
WITH RECURSIVE seq(n) AS (
    SELECT 1                              -- anchor: seed row
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 10000 -- recursive step + stop guard
)
INSERT INTO products (id, name, category_id, price)
SELECT n,
       'Product ' || n,    -- || is SQLite string concat
       (n % 20) + 1,       -- cycles 1..20  → category_id
       (n % 100) + 10      -- cycles 10..109 → price
FROM seq;
```

Two ideas at work:

1. **Recursive CTE = a `for` loop in SQL.** A seed row, a rule for the next row, and a stop condition. `seq` ends up holding `1, 2, …, 10000`.

   | Recursive CTE part            | `for` loop equivalent     |
   |-------------------------------|---------------------------|
   | `SELECT 1` (anchor)           | `int i = 1` — initial value |
   | `WHERE n < 10000`             | loop condition            |
   | `SELECT n + 1` (recursive)    | `i++`                     |
   | `UNION ALL`                   | collecting each iteration's value into the result set |

   So `SELECT 1` is just the **base case**: it seeds the CTE with one row where `n = 1`. Change it to `SELECT 5` and `seq` would hold `5, 6, …, 10000`.
2. **`SELECT … FROM seq` is a row factory.** Each `n` walks in; four columns walk out. Arithmetic on `n` shapes the fake data — concatenation builds names, modulo builds cycling categorical/numeric values.

| Expression          | Type    | Range/shape       | Becomes      |
|---------------------|---------|-------------------|--------------|
| `n`                 | INTEGER | 1..10000, unique  | `id` (also PK) |
| `'Product ' \|\| n` | TEXT    | unique per row    | `name`       |
| `(n % 20) + 1`      | INTEGER | 1..20, cycles     | `category_id` |
| `(n % 100) + 10`    | INTEGER | 10..109, cycles   | `price`      |

> Refresher on `%` (modulo): see [`modulus-cheatsheet.md`](./modulus-cheatsheet.md). Short version: `a % b` = the leftover after stuffing `a` items into bags of `b`.

Why bother spreading data across 20 categories? So the planner's `SCAN` vs `SEARCH USING INDEX` choice actually matters in the next sections — with ~500 products per category, an index on `category_id` lets SQLite skip ~9 500 rows per lookup.

## What `EXPLAIN QUERY PLAN` tells you

Prefix any `SELECT`/`UPDATE`/`DELETE` with `EXPLAIN QUERY PLAN` and SQLite prints **how it intends to retrieve rows** — without actually running the query. Two keywords matter:

| Keyword  | Meaning                                          | Cost      |
|----------|--------------------------------------------------|-----------|
| `SCAN`   | Walk every row of the table                      | O(n)      |
| `SEARCH` | Jump straight to matching rows via an index      | O(log n)  |

On 10,000 rows the wall-clock difference is small. On 10,000,000 it's the difference between **2 ms and 2 minutes**.

## Walkthrough

### 1. Query without an index

```sql
EXPLAIN QUERY PLAN
SELECT * FROM products WHERE category_id = 5;
```

Output:

```
SCAN products
```

No index on `category_id` exists, so SQLite reads every row and checks the condition.

### 2. Add an index

```sql
CREATE INDEX idx_products_category ON products(category_id);
```

An index is a **separate B-tree on disk** mapping `(indexed value) -> (row location)`. SQLite keeps it in sync automatically on every `INSERT`/`UPDATE`/`DELETE`.

| Cost                     | Benefit                  |
|--------------------------|--------------------------|
| Extra disk space         | Fast equality lookups    |
| Slightly slower writes   | Fast range scans         |
| Slightly slower writes   | Helps `ORDER BY` / joins |

### 3. Same query, with the index

```sql
EXPLAIN QUERY PLAN
SELECT * FROM products WHERE category_id = 5;
```

Output:

```
SEARCH products USING INDEX idx_products_category (category_id=?)
```

`SCAN` → `SEARCH`. That's the win you're looking for.

### 4. Composite indexes — order matters

```sql
CREATE INDEX idx_products_cat_price ON products(category_id, price);
```

A composite index on `(A, B)` helps queries that:

- filter by `A` alone, **or**
- filter by `A` AND `B`.

It does **not** help queries that filter by `B` alone.

| Query filter                          | Uses `idx_products_cat_price`? |
|---------------------------------------|--------------------------------|
| `WHERE category_id = 5`               | Yes (leading column)           |
| `WHERE category_id = 5 AND price > 50`| Yes                            |
| `WHERE price > 50`                    | **No** — back to SCAN          |

#### Why: the phone-book analogy

A composite index on `(A, B)` is **physically sorted by A first, then by B within each A-group** — exactly like a paper phone book is sorted by last name, then first name within each last name. That single sort order is what makes some lookups instant and others useless.

Imagine these entries:

```
ADAMS, John       555-0001
ADAMS, Mary       555-0002
BROWN, Alice      555-0010
BROWN, John       555-0011
SMITH, Alice      555-0020
SMITH, John       555-0021
SMITH, Mary       555-0022
ZHANG, John       555-0099
```

Three lookups, three very different costs:

1. **"Find all Smiths"** — flip to `S`, read down until the last name changes. Fast. Leading column (`last_name`) matches → index works as designed.
2. **"Find John Smith"** — same, but within the `SMITH` block, first names are also sorted, so you binary-search to `John`. Even faster. Both columns match.
3. **"Find everyone named John"** — the Johns are scattered (`ADAMS, John`, `BROWN, John`, `SMITH, John`, `ZHANG, John`), each on a different page. You'd have to read the whole book. The index gives you **no** shortcut.

Mapped back to the script:

| Phone-book term | Your index term  |
|-----------------|------------------|
| Last name       | `category_id`    |
| First name      | `price`          |

| Query                                         | Phone-book equivalent                    | Index helps?       |
|-----------------------------------------------|------------------------------------------|--------------------|
| `WHERE category_id = 5`                       | "All Smiths"                             | Yes                |
| `WHERE category_id = 5 AND price > 50`        | "Smiths whose first name starts with M+" | Yes (best)         |
| `WHERE price > 50`                            | "Everyone named John"                    | **No** — back to SCAN |

#### The leftmost-prefix rule

A B-tree index is **one sort order, not two**. To jump straight to matching rows, your filter must constrain the **front** of that sort. As soon as you skip the leading column, matches are scattered — and scattered means scan.

| Index on `(A, B, C)` — query filters | Uses index? |
|--------------------------------------|-------------|
| `A`                                  | Yes         |
| `A, B`                               | Yes         |
| `A, B, C`                            | Yes (full)  |
| `B`                                  | No          |
| `B, C`                               | No          |
| `A, C` (skips B)                     | Partial — uses `A`, then filters `C` row-by-row |

If you genuinely need to filter by `price` alone often, the fix isn't to fight the rule — add a second index:

```sql
CREATE INDEX idx_products_price ON products(price);
```

That's a **different** B-tree, sorted by `price` first. Both lookup styles become cheap, at the cost of more disk space and slightly slower writes.

### 5. Unique indexes

```sql
CREATE UNIQUE INDEX idx_products_name ON products(name);
```

Double duty:

1. **Speeds up** lookups by `name`.
2. **Enforces uniqueness** — duplicate `INSERT` now fails.

### 6. Inspecting indexes

```sql
SELECT '--- list all indexes on products ---' AS section;
SELECT name, sql FROM sqlite_master
WHERE type = 'index' AND tbl_name = 'products';
```

Two small tricks here.

**The `SELECT '...' AS section` line** is a *printable* section header. Real SQL comments (`-- like this`) are stripped before execution, so they never appear in the output of a batch run. Selecting a string literal with an alias gives you a labeled divider in the output stream.

**`sqlite_master` is SQLite's system catalog** — a built-in table that SQLite maintains for you. Every table, index, view, and trigger you create gets a row in it.

| Column     | What it holds                                                  |
|------------|----------------------------------------------------------------|
| `type`     | `'table'`, `'index'`, `'view'`, or `'trigger'`                 |
| `name`     | The object's own name (e.g. `idx_products_category`)           |
| `tbl_name` | The underlying table the object belongs to                     |
| `sql`      | The original `CREATE …` statement, exactly as you wrote it     |

So the query above filters the catalog to "indexes on the `products` table" and projects the index name + its `CREATE` statement. Output:

```
idx_products_category|CREATE INDEX idx_products_category ON products(category_id)
idx_products_cat_price|CREATE INDEX idx_products_cat_price ON products(category_id, price)
idx_products_name|CREATE UNIQUE INDEX idx_products_name ON products(name)
```

> **Mental model:** SQLite eats its own dog food — instead of a special `SHOW INDEXES` command, your schema *is* a queryable table you can `SELECT` from like any other.

A few useful variations:

```sql
SELECT name FROM sqlite_master WHERE type='table';                  -- all tables
SELECT sql  FROM sqlite_master WHERE sql IS NOT NULL;               -- full schema as DDL
SELECT 1    FROM sqlite_master WHERE type='index' AND name='idx_foo'; -- "does this index exist?"
```

Engine equivalents:

| Engine     | "What indexes exist on products?"                                            |
|------------|------------------------------------------------------------------------------|
| SQLite     | `SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='products';` |
| PostgreSQL | `\d products` in `psql`, or `SELECT * FROM pg_indexes WHERE tablename='products';` |
| MySQL      | `SHOW INDEX FROM products;` or query `information_schema.statistics`         |

## When NOT to index

- **Tiny tables** (< a few thousand rows) — a full scan is faster than an index lookup.
- **Columns you rarely filter or join on** — the write overhead earns nothing back.
- **Low-cardinality columns** (boolean-like, ~2-3 distinct values) — the index barely narrows anything.
- **Write-heavy tables** where reads are infrequent — every index slows every write.

> Rule of thumb: **measure, don't guess**. Add an index, run `EXPLAIN QUERY PLAN`, confirm `SCAN` became `SEARCH`.

## Mental model

> An index is a **pre-sorted lookup table** the database maintains for you. You trade a little write speed and disk space for dramatically faster reads on the indexed columns.

## Engine comparison

| Concept               | SQLite                          | PostgreSQL                       | MySQL (InnoDB)                  |
|-----------------------|---------------------------------|----------------------------------|---------------------------------|
| Inspect plan          | `EXPLAIN QUERY PLAN <sql>`      | `EXPLAIN [ANALYZE] <sql>`        | `EXPLAIN <sql>`                 |
| Default index type    | B-tree                          | B-tree (also GIN, GiST, BRIN, …) | B-tree                          |
| Auto-index for PK     | Yes                             | Yes                              | Yes (clustered)                 |
| Composite index rules | Leftmost-prefix                 | Leftmost-prefix                  | Leftmost-prefix                 |
| Unique index          | `CREATE UNIQUE INDEX`           | `CREATE UNIQUE INDEX`            | `CREATE UNIQUE INDEX`           |

## Running

```bash
# from inside sqlite/advanced/
sqlite3 advanced.db < 01-indexes-and-explain.sql
```

The script drops and recreates `products` each run, so it's safe to re-execute.

### Why you don't see product rows in the output

Every query in the script is either `EXPLAIN QUERY PLAN` (which prints the **plan**, not rows) or the index listing at the end. There's no `SELECT * FROM products`, so no rows are printed — but they're in the table.

To browse the data, open the DB interactively:

```bash
sqlite3 advanced.db
```

Then at the `sqlite>` prompt:

```
.mode box
.headers on
SELECT * FROM products LIMIT 5;
```

`.mode box` gives the unicode-bordered table; the default `list` mode is the pipe-separated output you saw for the index listing.

| Mode      | Looks like                              |
|-----------|-----------------------------------------|
| `list` (default) | `1\|Product 1\|2\|11`               |
| `column`  | aligned columns, no borders             |
| `box`     | unicode borders                         |
| `table`   | markdown-ish table                      |
| `json`    | JSON array of objects                   |

Run `.help` inside `sqlite3` to see all dot-commands.
