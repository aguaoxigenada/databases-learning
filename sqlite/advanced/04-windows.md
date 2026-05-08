# Window Functions

Companion notes for `04-windows.sql`. Goal: use **window functions** — aggregates that **don't collapse rows**. The moment you need *"for each row, also tell me something about its neighbours"*, reach for a window function.

## What is a window function?

A regular aggregate (`SUM`, `AVG`, `COUNT`) used with `GROUP BY` **collapses** rows: many rows in, one row out per group. A window function applies the same kind of aggregate but **preserves every row** and stamps the answer beside it. The magic word is `OVER`.

> Mental shortcut: `GROUP BY` *folds* the table; `OVER (...)` *annotates* it.

| Concept | Rows in / out | Detail visible? | Use when |
|---------|---------------|-----------------|----------|
| `GROUP BY` | N → one per group | No — collapsed | "Give me the totals" |
| `OVER (PARTITION BY ...)` | N → N | Yes — preserved | "For each row, **also** show its group's total" |
| `OVER (PARTITION BY ... ORDER BY ...)` | N → N | Yes — preserved | "Running things" — running total, rank, lag |

## The setup

The script uses a single fact table:

`sales` — flat sales log:

| id | product | region | amount | sold_on    |
|----|---------|--------|--------|------------|
| 1  | Widget  | North  | 100    | 2025-01-05 |
| 2  | Widget  | North  | 150    | 2025-01-18 |
| 3  | Widget  | North  | 120    | 2025-02-02 |
| 4  | Widget  | South  | 200    | 2025-01-10 |
| 5  | Widget  | South  | 180    | 2025-02-08 |
| 6  | Gadget  | North  | 80     | 2025-01-11 |
| 7  | Gadget  | North  | 110    | 2025-02-19 |
| 8  | Gadget  | South  | 120    | 2025-02-20 |
| 9  | Gadget  | South  | 95     | 2025-03-02 |

Useful pre-computed totals:

- North total = 100 + 150 + 120 + 80 + 110 = **560**
- South total = 200 + 180 + 120 + 95 = **595**

## Anatomy of `OVER (...)`

Every window function reads the same way:

```
  aggregate( column )  OVER ( PARTITION BY ...   ORDER BY ...   <frame> )
        │                       │                  │              │
        │                       │                  │              └── which rows count (default: from first row to current)
        │                       │                  └────────────────  the order *within* the partition
        │                       └───────────────────────────────────  who you're competing/grouping with
        └───────────────────────────────────────────────────────────  what to compute
```

Three knobs to memorise:

| Knob | Job | Default if omitted |
|------|-----|--------------------|
| `PARTITION BY` | Split rows into independent groups (the "windows") | Whole table is one group |
| `ORDER BY` | Sort *inside* each partition — turns the window into a sequence | Unordered, frame defaults differ |
| `ROWS BETWEEN ...` | Pick a sub-range of the partition relative to the current row | Whole partition (or up-to-current with `ORDER BY`) |

## Example 1 — `SUM OVER PARTITION BY`: stamp the group total on every row

```sql
SELECT product, region, amount,
       SUM(amount) OVER (PARTITION BY region) AS region_total
FROM sales
ORDER BY region, amount DESC;
```

### What it produces

9 rows in, 9 rows out — every sale keeps its detail and gains a `region_total` column:

| product | region | amount | region_total |
|---------|--------|--------|--------------|
| Widget  | North  | 150    | 560          |
| Widget  | North  | 120    | 560          |
| Gadget  | North  | 110    | 560          |
| Widget  | North  | 100    | 560          |
| Gadget  | North  | 80     | 560          |
| Widget  | South  | 200    | 595          |
| Widget  | South  | 180    | 595          |
| Gadget  | South  | 120    | 595          |
| Gadget  | South  | 95     | 595          |

### Line by line

#### `SUM(amount) OVER (PARTITION BY region) AS region_total`

For each row, the window is *"all rows sharing my region"*. SQLite sums `amount` over that window and pastes the result beside the row. The same number repeats for every row in the same region — that's expected.

### `GROUP BY` vs window — same `SUM`, different shape

```sql
-- GROUP BY: 2 rows out
SELECT region, SUM(amount) FROM sales GROUP BY region;

-- Window: 9 rows out
SELECT region, amount, SUM(amount) OVER (PARTITION BY region) FROM sales;
```

| | `GROUP BY region` | `OVER (PARTITION BY region)` |
|---|---|---|
| Rows out | One per region | One per sale |
| Detail visible? | No | Yes |
| Use when | "Give me the totals" | "Compare each sale to its region's total" |

### Mental model

> `OVER (PARTITION BY x)` = **compute the aggregate per group, but paste the answer next to every row in that group instead of collapsing them.**

## Example 2 — `ROW_NUMBER`: top-N per group

The classic "top-N per group" problem — the textbook reason window functions exist.

```sql
WITH ranked AS (
    SELECT product, region, amount,
           ROW_NUMBER() OVER (PARTITION BY region ORDER BY amount DESC) AS rn
    FROM sales
)
SELECT region, product, amount
FROM ranked
WHERE rn <= 2
ORDER BY region, amount DESC;
```

### The CTE's intermediate table

Before the outer query filters anything, the CTE produces this:

| product | region | amount | rn |
|---------|--------|--------|----|
| Widget  | North  | 150    | 1  |
| Widget  | North  | 120    | 2  |
| Gadget  | North  | 110    | 3  |
| Widget  | North  | 100    | 4  |
| Gadget  | North  | 80     | 5  |
| Widget  | South  | 200    | 1  |
| Widget  | South  | 180    | 2  |
| Gadget  | South  | 120    | 3  |
| Gadget  | South  | 95     | 4  |

Notice `rn` **restarts at 1** for each region — that's `PARTITION BY` doing its job.

### Final output (after `WHERE rn <= 2`)

| region | product | amount |
|--------|---------|--------|
| North  | Widget  | 150    |
| North  | Widget  | 120    |
| South  | Widget  | 200    |
| South  | Widget  | 180    |

### Why the CTE is mandatory

Window functions are evaluated **after** `WHERE`. So this is illegal:

```sql
-- ❌ won't work
SELECT product, region, amount
FROM sales
WHERE ROW_NUMBER() OVER (PARTITION BY region ORDER BY amount DESC) <= 2;
```

A CTE (or subquery) **freezes `rn` into a regular column**, so the outer `WHERE` can filter on it like any other value.

### "But `rn` doesn't appear in the output — was it created?"

Yes. The CTE always builds `rn`. The outer `SELECT` simply doesn't list it, so it's hidden. It's still **used** in `WHERE rn <= 2`. Add `rn` back to the outer `SELECT` and it'll appear.

> Two-stage mental model: the CTE is the **kitchen prep** (every column gets built, even temporary ones); the outer `SELECT` is the **plate** (you choose which to show). `WHERE` filters using prep-stage columns regardless.

## Example 3 — `ROW_NUMBER` vs `RANK` vs `DENSE_RANK`

Three near-identical functions that differ **only on ties**:

```sql
SELECT amount,
       ROW_NUMBER() OVER (ORDER BY amount DESC) AS rn,
       RANK()       OVER (ORDER BY amount DESC) AS rk,
       DENSE_RANK() OVER (ORDER BY amount DESC) AS drk
FROM sales;
```

If two rows tie on `amount`:

| amount | ROW_NUMBER | RANK | DENSE_RANK |
|--------|------------|------|------------|
| 200    | 1          | 1    | 1          |
| 180    | 2          | 2    | 2          |
| 150    | 3          | 3    | 3          |
| 120    | 4          | **4**| **4**      |
| 120    | 5          | **4**| **4**      |
| 110    | 6          | **6**| **5**      |
| 100    | 7          | 7    | 6          |

| Function | Behaviour on ties | Sequence shape |
|----------|-------------------|----------------|
| `ROW_NUMBER` | Arbitrary tiebreak; always unique | 1, 2, 3, 4, 5, … |
| `RANK` | Ties share, then **skip** | 1, 2, 2, **4**, 5 |
| `DENSE_RANK` | Ties share, **no skip** | 1, 2, 2, 3, 4 |

Pick by intent:

- **Exactly N rows, deterministic** → `ROW_NUMBER`
- **"Top N including ties"** → `RANK` or `DENSE_RANK` (use `WHERE rk <= N`)
- **Continuous ranking** (no gaps) → `DENSE_RANK`

## Example 4 — running totals

Add `ORDER BY` *inside* `OVER` and the window becomes a **sequence** — the implicit frame is now "everything from the first row up to and including the current row".

```sql
SELECT region, sold_on, amount,
       SUM(amount) OVER (
           PARTITION BY region
           ORDER BY sold_on
       ) AS running_total
FROM sales
ORDER BY region, sold_on;
```

### What it produces

| region | sold_on    | amount | running_total |
|--------|------------|--------|---------------|
| North  | 2025-01-05 | 100    | 100           |
| North  | 2025-01-11 | 80     | 180           |
| North  | 2025-01-18 | 150    | 330           |
| North  | 2025-02-02 | 120    | 450           |
| North  | 2025-02-19 | 110    | 560           |
| South  | 2025-01-10 | 200    | 200           |
| South  | 2025-02-08 | 180    | 380           |
| South  | 2025-02-20 | 120    | 500           |
| South  | 2025-03-02 | 95     | 595           |

The running total **resets** at each new region — that's `PARTITION BY` again.

### Two `ORDER BY` clauses, two different jobs

This query has **two** `ORDER BY` clauses, doing unrelated things:

| Where | Job |
|-------|-----|
| Inside `OVER (...)` | Defines the *order of accumulation* — used to compute `running_total` |
| At the end of the query | Defines the *order rows print* on screen |

They happen to match here, but they don't have to. Drop the outer one and the running totals are still computed correctly — they just print in arbitrary order, which makes them look wrong. Drop the inner one and `SUM` collapses back to the flat group total.

### The hidden frame

`SUM(...) OVER (PARTITION BY region ORDER BY sold_on)` is shorthand for:

```sql
SUM(...) OVER (
    PARTITION BY region
    ORDER BY sold_on
    RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW   -- ← implicit
)
```

Drop the `ORDER BY` and the frame defaults to the *whole partition* → you get the region total instead of a running total. **Adding `ORDER BY` is what makes it cumulative.**

| Inside `OVER` | What `SUM(amount)` produces |
|---|---|
| `PARTITION BY region` | **Group total** — same number on every row in the region (560 / 595) |
| `PARTITION BY region ORDER BY sold_on` | **Running total** — grows row by row through the region |

### The "running anything" recipe

Swap the aggregate to get a different cumulative metric — same `OVER (...)` shape:

| Aggregate | What it produces |
|-----------|-----------------|
| `SUM(amount)` | Running total |
| `COUNT(*)` | Running count (1, 2, 3, …) |
| `AVG(amount)` | Running (expanding) average |
| `MAX(amount)` | Running max — best so far |
| `MIN(amount)` | Running min — worst so far |

Omit `PARTITION BY` for a *global* running value across the whole table.

## Example 5 — moving averages with explicit frames

For a windowed slice that isn't "all rows so far", spell out the frame with `ROWS BETWEEN`.

```sql
SELECT region, sold_on, amount,
       AVG(amount) OVER (
           PARTITION BY region
           ORDER BY sold_on
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ) AS moving_avg_3
FROM sales
ORDER BY region, sold_on;
```

For each row, average **this row + the 2 before it** in date order, within the same region.

### Trace for North

| sold_on    | amount | window of rows averaged | moving_avg_3 |
|------------|--------|--------------------------|--------------|
| 2025-01-05 | 100    | {100}                   | 100.0        |
| 2025-01-11 | 80     | {100, 80}               | 90.0         |
| 2025-01-18 | 150    | {100, 80, 150}          | 110.0        |
| 2025-02-02 | 120    | {80, 150, 120}          | 116.67       |
| 2025-02-19 | 110    | {150, 120, 110}         | 126.67       |

Notice the early rows have **fewer than 3 values** — the frame just uses what's available. No padding, no nulls.

### Frame vocabulary

| Phrase | Meaning |
|--------|---------|
| `UNBOUNDED PRECEDING` | First row of the partition |
| `N PRECEDING` | N rows before the current row |
| `CURRENT ROW` | This row |
| `N FOLLOWING` | N rows after the current row |
| `UNBOUNDED FOLLOWING` | Last row of the partition |
| `ROWS` vs `RANGE` | `ROWS` = positional (count rows); `RANGE` = value-based (rows whose `ORDER BY` value is within a range) |

> Frames are the most powerful — and most error-prone — part of windowing. When in doubt, write the frame explicitly instead of trusting the default.

## Example 6 — `LAG` / `LEAD`: peek at neighbouring rows

```sql
SELECT region, sold_on, amount,
       LAG(amount) OVER (PARTITION BY region ORDER BY sold_on)          AS prev_amount,
       amount - LAG(amount) OVER (PARTITION BY region ORDER BY sold_on) AS delta
FROM sales
ORDER BY region, sold_on;
```

`LAG(col)` = "the value of `col` from the **previous row** in this window". `LEAD(col)` = the next row. The first row of each partition has no predecessor → `prev_amount` is `NULL`.

### Output

| region | sold_on    | amount | prev_amount | delta |
|--------|------------|--------|-------------|-------|
| North  | 2025-01-05 | 100    | NULL        | NULL  |
| North  | 2025-01-11 | 80     | 100         | -20   |
| North  | 2025-01-18 | 150    | 80          | +70   |
| North  | 2025-02-02 | 120    | 150         | -30   |
| North  | 2025-02-19 | 110    | 120         | -10   |
| South  | 2025-01-10 | 200    | NULL        | NULL  |
| South  | 2025-02-08 | 180    | 200         | -20   |
| South  | 2025-02-20 | 120    | 180         | -60   |
| South  | 2025-03-02 | 95     | 120         | -25   |

### Use cases

- "Difference from last period" — exactly the `delta` column above
- "Did this row change from the previous?" — `LAG(col) <> col`
- "Time between events" — `julianday(sold_on) - julianday(LAG(sold_on))`

`LAG`/`LEAD` accept optional 2nd and 3rd arguments: `LAG(amount, 2, 0)` = "two rows back, default to 0 if there isn't one".

## When window functions earn their keep

| Phrase in the requirement | Window function |
|---------------------------|-----------------|
| "For each row, also show the group's total / average / max" | `SUM/AVG/MAX OVER (PARTITION BY ...)` |
| "Top N per group" | `ROW_NUMBER OVER (PARTITION BY group ORDER BY metric)` + `WHERE rn <= N` |
| "Running total / cumulative" | `SUM OVER (PARTITION BY ... ORDER BY ...)` |
| "Moving average / N-row trailing" | `AVG OVER (... ROWS BETWEEN N PRECEDING AND CURRENT ROW)` |
| "Difference from previous row" | `col - LAG(col) OVER (...)` |
| "Rank with ties handled deliberately" | `RANK` or `DENSE_RANK` |

Anything that starts with *"for each row, compare it to..."* or *"cumulative something over time"* would otherwise need a self-join or app-code loop. Window functions do it in one pass, in SQL.

## Watch out for

| Pitfall | Reality |
|---------|---------|
| Filtering on the window column directly | Illegal — `WHERE ROW_NUMBER() OVER (...) <= 2` won't parse. Use a CTE or subquery. |
| Forgetting `ORDER BY` inside `OVER` | Without it, "running total" silently becomes "group total". The frame default changes. |
| `ROWS` vs `RANGE` mix-ups | `ROWS BETWEEN 2 PRECEDING` counts rows; `RANGE BETWEEN INTERVAL '2 days' PRECEDING` counts by value. SQLite supports both but `ROWS` is the safe default. |
| Mixing window functions in `WHERE` / `HAVING` | Disallowed. Window functions are computed *after* both. Put them in `SELECT` and filter via an outer query. |
| Assuming a stable order | The query's overall `ORDER BY` is independent of the window's `ORDER BY`. You need both — one for the frame, one for the final result. |

## Mental model

> A window function is a **regular aggregate that didn't collapse the rows**. `OVER` says "compute this per group, but stamp the answer back onto every row." `PARTITION BY` defines the groups; `ORDER BY` (inside `OVER`) turns the group into a sequence; the frame slices that sequence.

## Engine comparison

| Concept | SQLite | PostgreSQL | MySQL |
|---------|--------|------------|-------|
| Basic window functions | 3.25+ | All supported versions | 8.0+ |
| `ROW_NUMBER`, `RANK`, `DENSE_RANK` | Yes | Yes | Yes (8.0+) |
| `LAG`, `LEAD`, `FIRST_VALUE`, `LAST_VALUE` | Yes | Yes | Yes (8.0+) |
| `ROWS BETWEEN ...` frames | Yes | Yes | Yes (8.0+) |
| `RANGE BETWEEN value PRECEDING` (numeric/date offsets) | Limited | Full | Limited |
| Named windows (`WINDOW w AS ...`) | Yes | Yes | Yes |

For MySQL ≤ 5.7, none of this works — emulate with self-joins or user variables.

## Running

```bash
# from inside sqlite/advanced/
sqlite3 advanced.db < 04-windows.sql
```

For aligned-column output:

```bash
sqlite3 -header -column advanced.db < 04-windows.sql
```

The script drops and recreates `sales` each run, so it's safe to re-execute.
