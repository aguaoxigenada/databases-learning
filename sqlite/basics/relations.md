# Relations: foreign keys vs joins

How tables connect to each other, and how you read across them. Two ideas that get confused all the time but do completely different jobs.

## The setup

Two tables that know about each other through one shared number.

`authors` — one row per author:

```
id  name
--  -----------------
1   Ursula K. Le Guin
2   Ted Chiang
3   N. K. Jemisin
```

`books` — one row per book. The `author_id` column is a *pointer* back to `authors.id`:

```
id  title                 year  author_id
--  --------------------  ----  ---------
1   A Wizard of Earthsea  1968  1   ← points at Ursula
2   The Dispossessed      1974  1   ← also Ursula
3   Stories of Your Life  2002  2   ← Ted
4   Exhalation            2019  2   ← Ted
5   The Fifth Season      2015  3   ← Jemisin
```

Author names are **not** repeated in `books` — only the id. That's the whole point of relational design: store each fact once.

## Foreign key — the integrity rule

```sql
CREATE TABLE books (
    id        INTEGER PRIMARY KEY,
    title     TEXT NOT NULL,
    year      INTEGER,
    author_id INTEGER NOT NULL,
    FOREIGN KEY (author_id) REFERENCES authors(id)
);
```

The `FOREIGN KEY` line is a **constraint**. It tells SQLite: *"refuse any `books.author_id` value that doesn't exist in `authors.id`."*

It runs on **writes** (`INSERT`, `UPDATE`, `DELETE`). It does three things:

1. **Prevents orphans.** Inserting a book with `author_id = 999` fails if no such author exists.
2. **Enables cascades.** Add `ON DELETE CASCADE` and deleting an author also deletes their books.
3. **Documents the relationship.** Schema readers and tools (Prisma, ORMs, ER diagrammers) instantly see the link.

In SQLite specifically: foreign keys are off by default. You enable them per connection with:

```sql
PRAGMA foreign_keys = ON;
```

## JOIN — the read-time stitcher

```sql
SELECT b.title, b.year, a.name AS author
FROM books AS b
INNER JOIN authors AS a ON a.id = b.author_id
ORDER BY b.year;
```

Read it like this:

1. **`FROM books AS b`** — start with the `books` table, alias it `b`.
2. **`INNER JOIN authors AS a ON a.id = b.author_id`** — also pull in `authors` (alias `a`) and pair each book with the author whose `id` equals that book's `author_id`.
3. **`SELECT b.title, b.year, a.name AS author`** — pick three columns from the combined view; rename `a.name` to `author` for nicer output.
4. **`ORDER BY b.year`** — sort by year (ascending is the default).

The database conceptually builds a temporary combined table:

```
b.title                b.year  b.author_id   a.id   a.name
---------------------  ------  -----------   ----   -----------------
A Wizard of Earthsea   1968    1             1      Ursula K. Le Guin
The Dispossessed       1974    1             1      Ursula K. Le Guin
Stories of Your Life   2002    2             2      Ted Chiang
Exhalation             2019    2             2      Ted Chiang
The Fifth Season       2015    3             3      N. K. Jemisin
```

Then `SELECT` keeps the columns you asked for, `ORDER BY` sorts.

## INNER vs LEFT JOIN

- **INNER JOIN** — keep rows only when the match succeeds on **both** sides. Books with no author? Dropped. Authors with no books? Dropped.
- **LEFT JOIN** — keep every row from the **left** table, even when there's no match on the right. Missing right-side columns come back as `NULL`.

That's why `03-relationships.sql` adds an "Unpublished Author" with zero books and uses `LEFT JOIN` to count books per author — INNER JOIN would silently drop them.

```sql
SELECT a.name, COUNT(b.id) AS book_count
FROM authors AS a
LEFT JOIN books AS b ON b.author_id = a.id
GROUP BY a.id
ORDER BY book_count DESC;
```

`COUNT(b.id)` returns `0` for the unpublished author because the joined `b.id` is `NULL` for them, and `COUNT` ignores `NULL`s.

## The big point: foreign keys do NOT enable joins

Common confusion: *"the `FOREIGN KEY` line is what makes the join work, right?"* No.

| | Foreign key | JOIN |
| - | - | - |
| **What it does** | Validates writes — rejects orphan rows | Combines rows from two tables at read time |
| **When it runs** | On every `INSERT` / `UPDATE` / `DELETE` | On every `SELECT` that uses it |
| **Without it** | You can insert `author_id = 999` even if no such author exists | You'd have to fetch each table separately and stitch them in your app code |

You can join *any* two columns that share values — declared as a foreign key or not:

```sql
-- No FK declared, still works fine
SELECT u.name, o.total
FROM users u
JOIN orders o ON o.customer_email = u.email;
```

Mental model:

- **Foreign key** = *"rule about what values are allowed in this column."*
- **JOIN's `ON` clause** = *"rule for matching rows when I read across tables."*

They often use the same columns in well-designed schemas — but they answer different questions: *"is this data valid?"* vs *"how do I read it back together?"*

## One-to-many, the shape you'll see most

This whole example is a **one-to-many** relationship: one author has many books, each book has exactly one author. The pattern:

- The "many" side (`books`) holds the foreign key.
- The "one" side (`authors`) is referenced by it.

Other shapes:

- **One-to-one** — same idea, plus a `UNIQUE` constraint on the FK column.
- **Many-to-many** — needs a third "join table" with two FKs (e.g. `books`, `tags`, `book_tags`).

## Aggregating across a join: LEFT JOIN + GROUP BY

Goal: list every author and how many books they have — including authors with zero.

```sql
SELECT a.name, COUNT(b.id) AS book_count
FROM authors AS a
LEFT JOIN books AS b ON b.author_id = a.id
GROUP BY a.id
ORDER BY book_count DESC;
```

### Stage 1: LEFT JOIN widens the data

One row per matching pair, plus unmatched left rows kept as NULL on the right:

```
a.id  a.name              b.id  b.title
----  ------------------  ----  --------------------
1     Ursula K. Le Guin   1     A Wizard of Earthsea
1     Ursula K. Le Guin   2     The Dispossessed
2     Ted Chiang          3     Stories of Your Life
2     Ted Chiang          4     Exhalation
3     N. K. Jemisin       5     The Fifth Season
4     Unpublished Author  NULL  NULL
```

### Stage 2: GROUP BY collapses rows into buckets

`GROUP BY a.id` squashes all rows with the same `a.id` into one output row. Once grouped, you can only `SELECT`:

1. The grouping column (`a.id`, `a.name`).
2. **Aggregate functions** that condense each bucket: `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`.

### Stage 3: COUNT(b.id) per bucket

`COUNT(b.id)` counts rows in each bucket *where `b.id` is not NULL*. That's the trick:

- Ursula's bucket: 2 non-null `b.id`s → `2`
- Ted's bucket: 2 → `2`
- Jemisin's bucket: 1 → `1`
- Unpublished's bucket: one row, `b.id` is NULL → `0`

`COUNT(*)` would count blindly and give the unpublished author `1`. **`COUNT(some_column)` ignores NULLs** — that's what makes this correct.

### Final output

```
name                book_count
------------------  ----------
Ursula K. Le Guin   2
Ted Chiang          2
N. K. Jemisin       1
Unpublished Author  0
```

### Common gotchas

| Pitfall | Why it bites |
| - | - |
| `COUNT(*)` instead of `COUNT(b.id)` | Counts the unmatched LEFT JOIN row; unpublished author becomes `1` instead of `0`. |
| `INNER JOIN` instead of `LEFT JOIN` | Drops authors with zero books before counting — they vanish entirely. |
| Selecting a non-aggregated column without putting it in `GROUP BY` | Ambiguous: which row's value to pick? Strict engines reject this; SQLite picks an arbitrary one (silent footgun). |
| `WHERE b.id IS NOT NULL` | Filters out the unpublished author *before* grouping, defeating the LEFT JOIN. Put right-table conditions in `ON`, not `WHERE`. |

**One-liner:** *"Keep every author (LEFT JOIN), bucket the rows by author (GROUP BY), and count their non-null books in each bucket (COUNT)."*

## Written order vs execution order

One of the most counterintuitive things about SQL: **the order you write a query is not the order the database runs it.**

**Written order** (the order the language forces on you):

```
1. SELECT     ← what columns I want
2. FROM       ← which table
3. JOIN       ← combine more tables
4. WHERE      ← filter rows
5. GROUP BY   ← bucket rows
6. HAVING     ← filter buckets
7. ORDER BY   ← sort
8. LIMIT      ← cut off
```

**Execution order** (how the engine logically processes it):

```
1. FROM       ← pick the starting table
2. JOIN       ← stitch in the other table
3. WHERE      ← throw out rows that fail the filter
4. GROUP BY   ← bucket what's left
5. HAVING     ← throw out whole buckets
6. SELECT     ← compute the columns + aggregates per bucket
7. ORDER BY   ← sort the final rows
8. LIMIT      ← cut off
```

`SELECT` is almost last because you can't compute `COUNT(b.id)` until you know which rows are in each bucket — and that doesn't happen until after `GROUP BY`.

Mapped onto the query above:

```sql
SELECT a.name, COUNT(b.id) AS book_count   -- written 1st, runs 6th
FROM authors AS a                           -- written 2nd, runs 1st
LEFT JOIN books AS b ON b.author_id = a.id  -- written 3rd, runs 2nd
GROUP BY a.id                               -- written 4th, runs 4th
ORDER BY book_count DESC;                   -- written 5th, runs 7th
```

### Why this matters in practice

- **You can't use a `SELECT` alias in `WHERE`.** `WHERE` runs before `SELECT`, so the alias doesn't exist yet:
  ```sql
  SELECT COUNT(b.id) AS book_count FROM ... WHERE book_count > 0;  -- ERROR
  ```
  Use `HAVING book_count > 0` — `HAVING` runs *after* `SELECT` computes aggregates.
- **You *can* use the alias in `ORDER BY`.** `ORDER BY` runs after `SELECT`, so `book_count` is defined by then.
- **`WHERE` filters individual rows; `HAVING` filters whole buckets.** Different stages, different jobs.

**Mental model:** SQL is **declarative** — you describe the result you want in a fixed grammatical order. The engine reorganizes it into an execution plan. `SELECT` appearing first is for *humans reading*, not for *the database running*.

## Quick reference

```sql
-- Enable FK enforcement (per connection in SQLite)
PRAGMA foreign_keys = ON;

-- Declare a FK
FOREIGN KEY (author_id) REFERENCES authors(id)

-- With cascade behaviors
FOREIGN KEY (author_id) REFERENCES authors(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE

-- Inner join (only matched rows)
SELECT ... FROM a JOIN b ON b.a_id = a.id;

-- Left join (keep all left rows; right side may be NULL)
SELECT ... FROM a LEFT JOIN b ON b.a_id = a.id;
```
