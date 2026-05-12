# SQLite — Advanced SQL

The basics folder taught you *what* SQL does. This folder teaches the features that separate beginner from intermediate: making queries **fast**, making them **reusable**, and expressing the kind of logic that used to require application code.

Everything here is standard SQL — almost all of it works identically in PostgreSQL, MySQL, and SQL Server.

## Files

1. `01-indexes-and-explain.sql` — why queries get slow, how indexes fix that, and how to read `EXPLAIN QUERY PLAN` to verify.
2. `02-views.sql` — saving queries under a name so the rest of the schema can use them like tables.
3. `03-ctes.sql` — `WITH` clauses: readable multi-step queries, and recursive CTEs for hierarchies and sequence generation.
4. `04-windows.sql` — window functions: ranking, running totals, moving averages, and looking at neighbouring rows — all without collapsing rows like `GROUP BY` does.

## Running

```bash
# from inside sqlite/advanced/
sqlite3 advanced.db < 01-indexes-and-explain.sql
```

Each script recreates the tables it needs, so order doesn't matter and re-runs are safe. The file `advanced.db` is separate from `../basics/learn.db`.

## Reset

```bash
rm -f advanced.db
```

## Prerequisite

You should be comfortable with everything in `../basics/` — JOINs, GROUP BY, aggregates. If `SELECT COUNT(*) ... GROUP BY author_id HAVING ...` makes sense to you, you're ready.

## Deep dive: 3-row moving average (from `04-windows.sql`)

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

### What the data looks like, sorted

```
NORTH partition                  SOUTH partition
  2025-01-05  Widget  100          2025-01-10  Widget  200
  2025-01-11  Gadget   80          2025-02-08  Widget  180
  2025-01-18  Widget  150          2025-02-20  Gadget  120
  2025-02-02  Widget  120          2025-03-02  Gadget   95
  2025-02-19  Gadget  110
```

`PARTITION BY region` means each region is processed independently — the window never crosses the boundary.

### Watch the window slide down NORTH

The frame `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` = "the 2 rows before me + me." Watch the `[ ]` window slide down through the partition:

```
Row 1 (current = 100)
  [ 100 ]                        ← only 1 row available
   80                            avg = 100/1     = 100.0
   150
   120
   110

Row 2 (current = 80)
  [ 100                          ← 2 rows available
    80 ]                         avg = (100+80)/2 = 90.0
   150
   120
   110

Row 3 (current = 150)
  [ 100                          ← full 3-row window now
    80
    150 ]                        avg = (100+80+150)/3 = 110.0
   120
   110

Row 4 (current = 120)
   100                           ← oldest (100) falls out
  [ 80
    150
    120 ]                        avg = (80+150+120)/3 ≈ 116.7
   110

Row 5 (current = 110)
   100
   80                            ← 80 falls out
  [ 150
    120
    110 ]                        avg = (150+120+110)/3 ≈ 126.7
```

At the start of a partition the frame just shrinks (1 row, then 2, then 3 from there on). When we cross into South, the window resets.

### Final result

```
region  sold_on     amount  moving_avg_3
North   2025-01-05    100     100.0
North   2025-01-11     80      90.0
North   2025-01-18    150     110.0
North   2025-02-02    120     116.7
North   2025-02-19    110     126.7
South   2025-01-10    200     200.0
South   2025-02-08    180     190.0
South   2025-02-20    120     166.7
South   2025-03-02     95     131.7
```

Every original row is preserved — that's the whole point of window functions.

### Window function vs `GROUP BY`

| | `GROUP BY region` | `AVG(amount) OVER (PARTITION BY region ...)` |
|---|---|---|
| Rows out | one per region | one per input row |
| Sees neighbours? | no — collapses them | yes — frame defines which |
| Mix with raw columns? | only the grouped ones | any column |
| Good for | totals/counts per group | moving averages, running totals, rank, lag |

### Frame cheat sheet

Same query, different `ROWS BETWEEN ...`, very different metric:

| Frame | Window for row 4 (North, 120) | Use case |
|---|---|---|
| `2 PRECEDING AND CURRENT ROW` | 80, 150, **120** | trailing 3-row average *(this query)* |
| `1 PRECEDING AND 1 FOLLOWING` | 150, **120**, 110 | centered smoothing |
| `UNBOUNDED PRECEDING AND CURRENT ROW` | 100, 80, 150, **120** | running total / cumulative avg |
| `UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` | 100, 80, 150, **120**, 110 | each row gets its region's overall avg |

### Mental model

> `PARTITION BY` = which group. `ORDER BY` (inside `OVER`) = in what sequence. `ROWS BETWEEN ...` = how wide a slice around "now."

## Deep dive: LAG / LEAD — peeking at neighbouring rows (from `04-windows.sql`)

```sql
SELECT region, sold_on, amount,
       LAG(amount) OVER (PARTITION BY region ORDER BY sold_on)           AS prev_amount,
       amount - LAG(amount) OVER (PARTITION BY region ORDER BY sold_on)  AS delta
FROM sales
ORDER BY region, sold_on;
```

### What LAG does in one picture

`LAG(amount)` says: **"give me the `amount` from the previous row, looking up the partition in the order I specified."** It peeks one row back without leaving the current row.

```
sold_on     amount       LAG(amount)
2025-01-05    100  ←┐    NULL    ← no row before the first
2025-01-11     80  ←┼─── 100     ← peeks up to row above
2025-01-18    150  ←┼─── 80
2025-02-02    120  ←┼─── 150
2025-02-19    110  ←┘    120
```

The partition resets the moment region changes — South starts fresh with `NULL`.

### Result, with the period-over-period delta

NORTH:

```
sold_on     amount  prev_amount  delta = amount - prev
2025-01-05    100    NULL         NULL    ← first row, nothing to compare to
2025-01-11     80     100          -20    ← sales dipped 20
2025-01-18    150      80          +70    ← rebounded 70
2025-02-02    120     150          -30    ← fell back 30
2025-02-19    110     120          -10    ← gentle decline
```

SOUTH:

```
sold_on     amount  prev_amount  delta
2025-01-10    200    NULL         NULL
2025-02-08    180     200          -20
2025-02-20    120     180          -60
2025-03-02     95     120          -25
```

### Line by line

- `LAG(amount)` — fetch `amount` from the previous row.
- `PARTITION BY region` — "previous" only means previous *within the same region*. The first row of each region gets `NULL`.
- `ORDER BY sold_on` — defines what "previous" means: the row with the next-earlier date.
- `amount - LAG(amount) ...` — subtract previous from current → period-over-period change. When `LAG` returns `NULL`, `amount - NULL = NULL`, so the first delta in each region is empty.

The same `OVER (...)` clause is repeated; SQL doesn't share it automatically (some engines let you name it with `WINDOW w AS (...)`).

### LAG vs LEAD — the obvious sibling

`LEAD` is the same thing, but peeks **forward** instead of back.

| Function | Peeks at | NULL when |
|---|---|---|
| `LAG(x)` | previous row | first row of partition |
| `LAG(x, 2)` | two rows back | first 2 rows of partition |
| `LAG(x, 1, 0)` | previous row, default `0` if missing | never — uses 0 instead |
| `LEAD(x)` | next row | last row of partition |
| `LEAD(x, 3)` | three rows ahead | last 3 rows of partition |

The 2nd argument is offset; the 3rd is a default value to use instead of `NULL` (handy if you want `0` for "no previous sale" instead of an empty cell).

### What you'd write *without* LAG

Same query without window functions needs an awkward self-join:

```sql
SELECT s.region, s.sold_on, s.amount,
       prev.amount AS prev_amount,
       s.amount - prev.amount AS delta
FROM sales s
LEFT JOIN sales prev
       ON prev.region = s.region
      AND prev.sold_on = (
          SELECT MAX(sold_on) FROM sales
          WHERE region = s.region AND sold_on < s.sold_on
      );
```

Three table scans, a correlated subquery, harder to read. `LAG` does it in one pass.

### When to reach for LAG / LEAD

Anything phrased as **"compared to last…"** or **"the change since previous…"**:

- daily revenue vs yesterday
- this login vs the user's previous login (session gap analysis)
- this stock price vs yesterday's close (returns)
- this version's deploy time vs the previous deploy
- detecting gaps in event sequences (`sold_on - LAG(sold_on)`)

### Mental model

> `LAG`/`LEAD` are window functions that **don't aggregate** — they just *teleport one cell from another row into the current row*, scoped by `PARTITION BY` and ordered by `ORDER BY`.
