# Common Table Expressions (CTEs)

Companion notes for `03-ctes.sql`. Goal: use CTEs (the `WITH` clause) to **break complex queries into readable named steps** — and to do things a plain `SELECT` can't, via **recursion**.

## What is a CTE?

A **CTE is a named, temporary result set** you define at the top of a query with `WITH`, then reference by name in the rest of the statement. Think of it as a **`let` binding for SQL**: define a name once, use it below.

> Mental shortcut: a CTE is a **named subquery** that reads top-to-bottom. `RECURSIVE` upgrades it to `let rec` — the definition can refer to itself.

| Concept | Scope | Can self-reference? | When it computes |
|---------|-------|---------------------|------------------|
| **Subquery** | Inline, anonymous | No | Once per outer query |
| **CTE** | Named, lives for one statement | No (plain) / Yes (recursive) | Once per outer query |
| **View** | Named, lives forever | No | Every time it's read |
| **Temp table** | Named, lives for the session | No | Once at insert |

## The setup

The script uses two tables.

`sales` — flat fact table:

| id | product | region | amount | sold_on    |
|----|---------|--------|--------|------------|
| 1  | Widget  | North  | 100    | 2025-01-05 |
| 2  | Widget  | North  | 150    | 2025-01-18 |
| 3  | Widget  | South  | 200    | 2025-02-02 |
| 4  | Gadget  | North  | 80     | 2025-01-11 |
| 5  | Gadget  | South  | 120    | 2025-02-20 |
| 6  | Gizmo   | North  | 50     | 2025-03-07 |
| 7  | Gizmo   | South  | 90     | 2025-03-15 |

`employees` — self-referencing tree (used for the recursive section):

| id | name  | manager_id |
|----|-------|------------|
| 1  | Ada   | NULL       |
| 2  | Bella | 1          |
| 3  | Cleo  | 1          |
| 4  | Dev   | 2          |
| 5  | Eli   | 2          |
| 6  | Fatou | 4          |

> Side note: SQLite has no `DATE` type, so `sold_on` is stored as ISO-8601 text (`'2025-01-05'`). Lexicographic sort of ISO strings happens to be chronological, which is why people get away with this.

## Example 1 — basic CTE: above-average sales by region

The goal: find the rows in `sales` where the `amount` is **above the average for that row's own region**. So a $150 sale in North only qualifies if it beats the North's average — not the global average.

```sql
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
```

### Per-region averages

| region | avg_amount |
|--------|------------|
| North  | (100 + 150 + 80 + 50) / 4 = **95** |
| South  | (200 + 120 + 90) / 3 ≈ **136.67** |

### Which rows qualify

| product | region | amount | beats avg? |
|---------|--------|--------|------------|
| Widget  | North  | 100    | 100 > 95 ✅ |
| Widget  | North  | 150    | 150 > 95 ✅ |
| Widget  | South  | 200    | 200 > 136.67 ✅ |
| Gadget  | North  | 80     | 80 > 95 ❌ |
| Gadget  | South  | 120    | 120 > 136.67 ❌ |
| Gizmo   | North  | 50     | 50 > 95 ❌ |
| Gizmo   | South  | 90     | 90 > 136.67 ❌ |

Three rows survive — that's the output.

### Line by line

#### `WITH regional_averages AS (`

Open the CTE. "From now on, the name `regional_averages` refers to the result of the query inside these parentheses." The CTE is **scoped to this single statement** — once the outer `SELECT` finishes, the name no longer exists.

#### `SELECT region, AVG(amount) AS avg_amount FROM sales GROUP BY region`

Compute the per-region average. Mentally treat the result as a tiny temporary table:

| region | avg_amount |
|--------|------------|
| North  | 95         |
| South  | 136.67     |

#### `)` — close the CTE definition

Below comes the **outer query**, which uses `regional_averages` as if it were a real table.

#### `FROM sales AS s JOIN regional_averages AS ra ON ra.region = s.region`

For each sales row, look up the **single CTE row that matches its region** and attach `avg_amount`. After the join:

| s.product | s.region | s.amount | ra.avg_amount |
|-----------|----------|----------|---------------|
| Widget    | North    | 100      | 95            |
| Widget    | North    | 150      | 95            |
| Widget    | South    | 200      | 136.67        |
| Gadget    | North    | 80       | 95            |
| Gadget    | South    | 120      | 136.67        |
| Gizmo     | North    | 50       | 95            |
| Gizmo     | South    | 90       | 136.67        |

Same row count as `sales`, just one extra column. This is a **many-to-one join** — the single North row in the CTE matches all four North sales, the single South row matches all three South sales. The join *widens* the rows without changing the row count. (If a sale's region were absent from the CTE entirely, an inner `JOIN` would silently drop it; `LEFT JOIN` would keep it with `NULL` in `avg_amount`.)

#### `WHERE s.amount > ra.avg_amount`

Keep only rows where this sale beat its region's average.

#### `ORDER BY s.region, s.amount DESC`

Sort: alphabetically by region, then biggest amounts first within each region. Final output:

| product | region | amount | avg_amount |
|---------|--------|--------|------------|
| Widget  | North  | 150    | 95         |
| Widget  | North  | 100    | 95         |
| Widget  | South  | 200    | 136.67     |

### The pipeline as a picture

```
            ┌──────────────────┐
            │   sales (raw)    │  7 rows
            └────────┬─────────┘
                     │
       ┌─────────────┼──────────────┐
       │                            │
       ▼                            ▼
GROUP BY region              keep all rows
SUM/AVG                      (the outer FROM)
       │                            │
       ▼                            │
┌──────────────────┐                │
│ regional_averages│ 2 rows         │
│ (the CTE)        │◄───────JOIN────┤
└──────────────────┘   on region    │
                                    ▼
                          attach avg_amount
                                    │
                                    ▼
                       WHERE amount > avg_amount
                                    │
                                    ▼
                       ORDER BY region, amount DESC
```

The CTE **forks the data**: aggregate one branch, keep the other detailed, then **rejoin them on the grouping key** so each detail row carries its group's summary alongside it. This pattern shows up constantly in analytical SQL.

### CTE vs. inline subquery

Functionally identical to:

```sql
SELECT s.product, s.region, s.amount, ra.avg_amount
FROM sales AS s
JOIN (
    SELECT region, AVG(amount) AS avg_amount
    FROM sales
    GROUP BY region
) AS ra ON ra.region = s.region
WHERE s.amount > ra.avg_amount;
```

But:

| With CTE | Inline subquery |
|----------|-----------------|
| Reads top-to-bottom: "first compute averages, then use them" | Reads inside-out — pop the stack mentally |
| The intermediate result has a **name** (`regional_averages`) — documents intent | Anonymous nested block |
| Easy to add a second CTE that also uses it | Would need to repeat the subquery |

For one-shot use the difference is small. For multi-step queries (next example), CTEs keep the code linear and refactorable.

### Modern alternative: window functions

Same result without a self-join, using a **window function** (covered in `04-windows.sql`):

```sql
SELECT product, region, amount, avg_amount
FROM (
    SELECT product, region, amount,
           AVG(amount) OVER (PARTITION BY region) AS avg_amount
    FROM sales
)
WHERE amount > avg_amount
ORDER BY region, amount DESC;
```

`AVG(...) OVER (PARTITION BY region)` computes the per-region average **and attaches it to every row in one pass** — no `GROUP BY`, no join. Often faster, often cleaner. The CTE+JOIN approach is still useful when you need the aggregated result for other things too.

## Example 2 — chained CTEs: regions that beat the overall average

```sql
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
```

This is where CTEs really earn their keep — **each step builds on the previous one**, and you can read the logic top-to-bottom.

### What each CTE produces

`region_totals`:

| region | total |
|--------|-------|
| North  | 380   |
| South  | 410   |

`overall`:

| avg_total |
|-----------|
| 395       |

A single-row, single-column table — sometimes called a **scalar CTE**, since it's effectively just one number wrapped in table form. This pattern (compute one summary value, then use it as a comparison threshold) shows up a lot.

### The outer query

`FROM region_totals AS rt, overall AS o` — comma between two tables is shorthand for `CROSS JOIN`. Since `overall` has exactly one row, it just attaches `avg_total = 395` to every row of `region_totals`. Then `WHERE rt.total > o.avg_total` keeps regions whose total beat the overall average.

> The trick: scalar CTE + cross join = **stamp one value onto every row** so a row-by-row `WHERE` comparison becomes possible. Without this, you'd have nowhere to put the `395` for the comparison to reference.

Output:

| region | total |
|--------|-------|
| South  | 410   |

### Why this style scales

Imagine the same query as nested subqueries — three levels deep, hard to read. With CTEs each "step" gets a name, and the second CTE references the first by name (`FROM region_totals`), exactly as you'd describe the logic out loud.

## Example 3 — recursive CTEs: walking a hierarchy

A recursive CTE is a CTE that **references its own name in its definition**. SQLite repeatedly applies the recursive step until it produces no new rows, then stops.

The shape is always:

```
WITH RECURSIVE name(cols) AS (
    <anchor query>      -- seed: the starting rows
    UNION ALL
    <recursive query>   -- builds on what's already in `name`
)
SELECT ... FROM name;
```

Two huge use cases:

1. **Generating sequences from thin air** — used in `01-indexes-and-explain.sql` to produce 10,000 rows.
2. **Walking hierarchies** — managers → reports → reports' reports → …

### Org-chart example

The `employees` table is self-referencing (`manager_id` points back to `id`). To find everyone in Ada's reporting chain — at any depth — a single `JOIN` won't do, because the depth isn't fixed.

```sql
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
```

### Stepwise trace

| Iteration | What gets added to `subordinates` |
|-----------|-----------------------------------|
| Anchor    | Bella (depth 1), Cleo (depth 1) — direct reports of Ada |
| Step 1    | Dev (depth 2), Eli (depth 2) — reports of Bella |
| Step 2    | Fatou (depth 3) — report of Dev |
| Step 3    | (no new rows — recursion stops) |

Final output:

| depth | name  |
|-------|-------|
| 1     | Bella |
| 1     | Cleo  |
| 2     | Dev   |
| 2     | Eli   |
| 3     | Fatou |

The `depth` column is a hand-rolled counter — just `1` in the anchor, then `s.depth + 1` in the recursive step. It mirrors how you'd track recursion depth in any imperative language.

> Notice Ada isn't in the result. The anchor's `WHERE manager_id = 1` only matches employees whose manager is Ada — Ada herself has `manager_id = NULL`, so she's filtered out. If you wanted her included, you'd `UNION ALL` her in separately as part of the anchor.

### What `subordinates` actually means inside the recursive step

A subtle but crucial detail: when the recursive `SELECT` references `subordinates`, it does **not** mean "every row accumulated so far." It means **only the rows added by the previous iteration**.

SQLite maintains a sliding **working table** that gets replaced each loop:

| Iteration | Working table going in | Recursive step produces | Action |
|-----------|------------------------|-------------------------|--------|
| Anchor    | (none)                 | `{Bella, Cleo}`         | Seed both the result and the working table |
| 1         | `{Bella, Cleo}`        | `{Dev, Eli}`            | Append to result; **replace** working table with `{Dev, Eli}` |
| 2         | `{Dev, Eli}`           | `{Fatou}`               | Append to result; replace working table with `{Fatou}` |
| 3         | `{Fatou}`              | `{}` (empty)            | Stop |

That's why Bella and Cleo never get re-processed — by iteration 2 they've already been "consumed" out of the working table. The final `subordinates` table that the outer `SELECT` reads from is the **full accumulation across all iterations**, but the recursive step itself only ever sees the freshest layer.

Why this matters: without the working-table semantics, the join `e.manager_id = s.id` would re-find Dev and Eli every iteration (because Bella stays in the set), and you'd get an explosion of duplicate rows.

### `UNION ALL` vs `UNION`

Recursive CTEs almost always use `UNION ALL`, not `UNION`:

| | `UNION ALL` | `UNION` |
|---|---|---|
| Behavior | Appends rows blindly | Appends and **deduplicates** |
| Cost | Cheap | Extra work every iteration |
| When to use | Default — tree walks, sequence generation | Only if recursion can reach the same row via multiple paths and you want to collapse duplicates |

For a tree (each node has one parent), every row enters the result exactly once, so dedup is wasted effort.

### Recursive CTE = a `for` loop in SQL

| Recursive CTE part           | Imperative equivalent              |
|------------------------------|------------------------------------|
| Anchor `SELECT`              | initial value / seed               |
| `UNION ALL`                  | append each iteration's results    |
| Recursive `SELECT`           | the loop body                      |
| Self-join condition          | how to find the "next" rows        |
| (no new rows produced)       | loop exit condition                |

### Common pitfall: missing termination

If the recursive step always produces new rows, the CTE loops forever (or hits SQLite's depth limit). For sequences this is why the `WHERE n < 10000` guard exists. For hierarchies, the natural shape of the data (a finite tree) usually terminates by itself — but if your data has cycles (A is B's manager and B is A's manager), you'll loop. Defensive trick: add `WHERE depth < 100` to the recursive step.

## When to use CTEs

| Reason | Example |
|--------|---------|
| **The query has multiple meaningful steps** | "compute averages → join back → filter" |
| **The same intermediate result is referenced more than once** | Avoid repeating a subquery |
| **You need recursion** (sequences, trees, graphs) | Org chart, file system, category hierarchy, number generator |
| **Top-to-bottom readability matters** | Long analytical queries where reviewers need to follow the logic |

For a single trivial subquery, an inline subquery is fine — don't reach for a CTE just because you can.

## Watch out for

| Pitfall | Reality |
|---------|---------|
| "CTEs are always faster" | No — historically Postgres treated CTEs as **optimization fences** (computed once, materialized). 12+ inlines them by default. SQLite usually inlines. Either way, prefer clarity unless you've measured. |
| "I can use a CTE in another statement later" | No — CTE scope is **one statement only**. Use a view or temp table for cross-statement reuse. |
| "Recursive CTE always works" | Only if the recursive step eventually produces zero new rows. Cycles or missing guards = infinite loop. |

## Mental model

> A CTE is a **named subquery that reads top-to-bottom**. Use it when your query has multiple steps that deserve names — or when you need recursion, which subqueries can't do.

## Engine comparison

| Concept | SQLite | PostgreSQL | MySQL |
|---------|--------|------------|-------|
| Plain CTE | `WITH name AS (...)` (3.8.3+) | `WITH name AS (...)` | `WITH name AS (...)` (8.0+) |
| Recursive CTE | `WITH RECURSIVE name AS (...)` | `WITH RECURSIVE name AS (...)` | `WITH RECURSIVE name AS (...)` (8.0+) |
| Optimization hint | n/a (always inlined) | `WITH name AS [NOT] MATERIALIZED (...)` (12+) | n/a |
| Anchor / recursive separator | `UNION ALL` (or `UNION`) | Same | Same |
| Hierarchy alternative | recursive CTE only | recursive CTE; also `ltree` extension | recursive CTE only |

## Running

```bash
# from inside sqlite/advanced/
sqlite3 advanced.db < 03-ctes.sql
```

For aligned-column output:

```bash
sqlite3 -header -column advanced.db < 03-ctes.sql
```

The script drops and recreates the tables each run, so it's safe to re-execute.
