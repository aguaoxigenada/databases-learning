# Querying in Postgres: filters, aggregates, HAVING, and subqueries

Companion to `04-queries.sql`. This builds on `03-relationships.md` (joins, GROUP BY, COUNT). Here the new ideas are: `BETWEEN`, the **`LIKE` vs `ILIKE`** case-sensitivity trap, aggregate functions, **`HAVING`** (filtering groups), and **scalar subqueries** — plus a real non-determinism bug that bites with ties.

Assumes `03-relationships.sql` has been run, so you have `authors` + `books`.

## Sample data

**books**
| id | title | year | author_id |
|----|-------|------|-----------|
| 1 | A Wizard of Earthsea | 1968 | 1 (Ursula) |
| 2 | The Dispossessed | 1974 | 1 (Ursula) |
| 3 | Stories of Your Life | 2002 | 2 (Ted) |
| 4 | Exhalation | 2019 | 2 (Ted) |
| 5 | The Fifth Season | 2015 | 3 (Jemisin) |

## 1. Filtering a range: `BETWEEN`

```sql
SELECT title, year, a.name AS author
FROM books AS b
INNER JOIN authors AS a ON a.id = b.author_id
WHERE year BETWEEN 1970 AND 2010
ORDER BY year;
```

`WHERE year BETWEEN 1970 AND 2010` keeps rows where `year` is in that range — **inclusive of both ends** (it's shorthand for `year >= 1970 AND year <= 2010`). The `JOIN` pulls in each book's author name. Result:

| title | year | author |
|-------|------|--------|
| The Dispossessed | 1974 | Ursula K. Le Guin |
| Stories of Your Life | 2002 | Ted Chiang |

(1968 is below the range, 2015 and 2019 are above — all dropped.)

## 2. The `LIKE` vs `ILIKE` trap

```sql
SELECT title FROM books WHERE title LIKE '%the%';   -- case-SENSITIVE
SELECT title FROM books WHERE title ILIKE '%the%';  -- case-insensitive
```

`%` is a wildcard meaning "any run of characters", so `'%the%'` means "the letters t-h-e appearing anywhere."

The catch: **`LIKE` is case-sensitive in Postgres.** This is the single biggest surprise coming from SQLite, where `LIKE` is case-insensitive on ASCII.

| Query | Matches | Misses |
|-------|---------|--------|
| `LIKE '%the%'` | "The Dispossessed"? **No** — capital T | "A Wizard of **the** Earthsea"-style only if lowercase |
| `ILIKE '%the%'` | "**The** Dispossessed", "The Fifth Season" | nothing with those letters |

`ILIKE` (the **I** = case-Insensitive) is the Postgres extension you reach for when you want SQLite's old behavior. If you ported a working SQLite query and search results mysteriously dried up, this is almost always why.

## 3. Aggregates over the whole table

```sql
SELECT COUNT(*)         AS total_books,
       MIN(year)        AS oldest,
       MAX(year)        AS newest,
       ROUND(AVG(year)) AS avg_year
FROM books;
```

With **no `GROUP BY`**, the whole table is one single pile, so each aggregate returns one number for the entire table:

| total_books | oldest | newest | avg_year |
|-------------|--------|--------|----------|
| 5 | 1968 | 2019 | 1996 |

- `COUNT(*)` — number of rows.
- `MIN` / `MAX` — smallest / largest `year`.
- `AVG(year)` — the mean. **Postgres quirk:** `AVG` on an integer column returns `NUMERIC` (arbitrary precision), so you get something like `1995.6`. `ROUND()` trims it to a clean year. (In SQLite `AVG` returned a plain float.)

## 4. `GROUP BY` + `HAVING` — filtering groups

```sql
SELECT a.name, COUNT(b.id) AS n
FROM authors AS a
JOIN books AS b ON b.author_id = a.id
GROUP BY a.id, a.name
HAVING COUNT(b.id) > 1;
```

Stages:

1. **`JOIN`** (INNER — no LEFT) pairs authors with books. The unpublished author has no books, so they're dropped here.
2. **`GROUP BY a.id, a.name`** chops into one pile per author.
3. **`COUNT(b.id)`** per pile → Ursula 2, Ted 2, Jemisin 1.
4. **`HAVING COUNT(b.id) > 1`** throws away any pile whose count isn't > 1 → Jemisin's pile (1) is dropped.

Result:

| name | n |
|------|---|
| Ursula K. Le Guin | 2 |
| Ted Chiang | 2 |

### WHERE vs HAVING — the key distinction

| | `WHERE` | `HAVING` |
|---|---|---|
| Filters | individual **rows** | whole **piles** (groups) |
| Runs | *before* `GROUP BY` | *after* `GROUP BY` + aggregation |
| Can it see `COUNT(...)`? | ❌ groups don't exist yet | ✅ that's its whole job |

You **can't** write `WHERE COUNT(b.id) > 1` — at `WHERE` time the piles haven't formed, so the count doesn't exist. Filtering on an aggregate is exactly what `HAVING` is for.

> **Mental model:** `WHERE` filters *rows going in*; `HAVING` filters *groups coming out*.

**Portability note:** the script writes `HAVING COUNT(b.id) > 1`, not `HAVING n > 1`. SQLite lets you reuse the SELECT alias `n` here, but standard Postgres doesn't guarantee the alias exists at `HAVING` time — so spelling out the full aggregate always works.

## 5. Scalar subquery — "books by the most prolific author"

```sql
SELECT title, year
FROM books
WHERE author_id = (
    SELECT author_id
    FROM books
    GROUP BY author_id
    ORDER BY COUNT(*) DESC
    LIMIT 1
);
```

A **subquery** is a query nested inside another. Read it **inside-out**, because the outer query can't run until the inner one hands it a value.

### Inner query first

```sql
SELECT author_id
FROM books
GROUP BY author_id
ORDER BY COUNT(*) DESC
LIMIT 1
```

- `GROUP BY author_id` → counts per author: 1→2, 2→2, 3→1.
- `ORDER BY COUNT(*) DESC` → biggest first.
- `LIMIT 1` → keep just the top → a **single value**, e.g. `2`.

> Here `COUNT(*)` is fine (not `COUNT(b.id)`) because there's no LEFT JOIN — every row is a real book, no NULL placeholders.

### Substitute and run the outer query

The parenthesized block collapses to one number, then:

```sql
SELECT title, year FROM books WHERE author_id = 2;   -- subquery became "2"
```

It's called a **scalar subquery** because it must return exactly *one row, one column* — a single scalar — to sit on the right of `=`.

## 6. ⚠️ The tie bug — `ORDER BY ... LIMIT 1` is non-deterministic

This query has a lurking bug. Ursula (id 1) and Ted (id 2) **both** wrote 2 books:

| author_id | COUNT(*) |
|-----------|----------|
| 1 | 2 |
| 2 | 2 |
| 3 | 1 |

`ORDER BY COUNT(*) DESC` sorts by **count only**. Ursula and Ted are tied at 2, so SQL is free to put *either* on top — there's no rule. `LIMIT 1` then blindly grabs whichever landed there. On one machine you get Ursula's books; on another (or after a `VACUUM`, an index change, or table growth) you get Ted's. **The result is non-deterministic** — which is why running it may return:

```
        title         | year
----------------------+------
 Stories of Your Life | 2002
 Exhalation           | 2019
```

(Ted's books) even though Ursula is equally "the most prolific."

### Two fixes, depending on intent

**Want a *predictable* single winner?** Add a tiebreaker column to `ORDER BY`:

```sql
ORDER BY COUNT(*) DESC, author_id ASC   -- ties now broken by author_id → Ursula always wins
LIMIT 1
```

`ORDER BY` only breaks ties on columns you actually *name*. Add `author_id` and the coin flip becomes deterministic.

**Want *all* tied winners?** Switch `=` to `IN` and drop the `LIMIT`:

```sql
SELECT title, year
FROM books
WHERE author_id IN (
    SELECT author_id
    FROM books
    GROUP BY author_id
    HAVING COUNT(*) = (
        SELECT COUNT(*) FROM books
        GROUP BY author_id
        ORDER BY COUNT(*) DESC
        LIMIT 1
    )
);
```

This returns Ursula's **and** Ted's books. Note: `=` demands exactly one value (so it needs `LIMIT 1`), while `IN` accepts a list — and removing `LIMIT 1` from a `= (subquery)` that returns two rows would error with `more than one row returned by a subquery used as an expression`.

> **Mental model:** `LIMIT 1` on a tie is like asking "who's tallest?" in a room of two equally tall people and accepting whoever the camera framed first. Whenever you see `ORDER BY ... LIMIT 1`, ask: *"could there be a tie, and do I care which one I get?"*

## 7. Top-N: `ORDER BY ... LIMIT`

```sql
SELECT title, year FROM books ORDER BY year DESC LIMIT 2;
```

Sort newest-first, keep the top 2 → "Exhalation" (2019), "The Fifth Season" (2015). The everyday "give me the N biggest/newest/best" pattern. (Same tie caveat applies if two rows share the boundary `year`.)

## Cheat sheet

| Want to... | Use |
|------------|-----|
| Filter rows by a value/range | `WHERE` (+ `BETWEEN`, `LIKE`/`ILIKE`) |
| Case-insensitive text match | `ILIKE` (not `LIKE` — it's case-sensitive in PG) |
| One summary number over all rows | aggregate with no `GROUP BY` |
| One summary number per group | `GROUP BY` + aggregate |
| Filter *groups* by an aggregate | `HAVING` (not `WHERE`) |
| Use a computed value inside a filter | scalar subquery `= (SELECT ... LIMIT 1)` |
| Match against several computed values | `IN (SELECT ...)` |
| Top N rows | `ORDER BY ... LIMIT n` (name a tiebreaker!) |
