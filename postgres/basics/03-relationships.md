# Relationships in Postgres: joins, LEFT JOIN, and counting

Companion to `03-relationships.sql`. The SQL here is nearly identical to `../../sqlite/basics/relations.md` — read that for the deep dive on foreign keys vs joins and SQL's execution order. This file focuses on the two queries in the script and the **Postgres-specific** gotcha that bites you with `GROUP BY`.

## The setup

`authors` — one row per author:

```
id  name
--  ------------------
1   Ursula K. Le Guin
2   Ted Chiang
3   N. K. Jemisin
4   Unpublished Author   ← added later, has zero books
```

`books` — one row per book. `author_id` is a pointer back to `authors.id`:

```
id  title                 year  author_id
--  --------------------  ----  ---------
1   A Wizard of Earthsea  1968  1   ← Ursula
2   The Dispossessed      1974  1   ← Ursula
3   Stories of Your Life  2002  2   ← Ted
4   Exhalation            2019  2   ← Ted
5   The Fifth Season      2015  3   ← Jemisin
```

Author #4 has **no** matching book. That's deliberate — it's what makes the difference between INNER and LEFT JOIN visible.

## INNER JOIN — books with their authors

```sql
SELECT b.title, b.year, a.name AS author
FROM books AS b
INNER JOIN authors AS a ON a.id = b.author_id
ORDER BY b.year;
```

Line by line:

1. **`FROM books AS b`** — start from `books`, alias it `b`.
2. **`INNER JOIN authors AS a ON a.id = b.author_id`** — pair each book with the author whose `id` matches that book's `author_id`.
3. **`SELECT b.title, b.year, a.name AS author`** — pick three columns; rename `a.name` to `author`.
4. **`ORDER BY b.year`** — sort by year (ascending is the default).

INNER keeps a row only when the match succeeds on **both** sides. The "Unpublished Author" never appears — they have no book to pair with, so they're dropped.

## LEFT JOIN + GROUP BY — book count per author

Goal: list **every** author and how many books they have, *including* the one with zero.

```sql
SELECT a.name, COUNT(b.id) AS book_count
FROM authors AS a
LEFT JOIN books AS b ON b.author_id = a.id
GROUP BY a.id, a.name
ORDER BY book_count DESC;
```

This runs in three stages. The trick is that they happen in this order — *not* the order you read them.

### Stage 1: LEFT JOIN widens the data

`LEFT JOIN` keeps **every** row from the left table (`authors`), even when no book matches. Unmatched authors get NULL in the book columns:

```
a.id  a.name              b.id  b.author_id
----  ------------------  ----  -----------
1     Ursula K. Le Guin   1     1
1     Ursula K. Le Guin   2     1
2     Ted Chiang          3     2
2     Ted Chiang          4     2
3     N. K. Jemisin       5     3
4     Unpublished Author  NULL  NULL          ← kept alive, but no book
```

An `INNER JOIN` would drop that last row entirely. LEFT JOIN is what creates the NULL placeholder.

### Stage 2: GROUP BY chops the table into piles — *first*

This is the part people miss. `GROUP BY` runs **before** `COUNT`. It sorts the rows above into one pile per author:

**Pile A — Ursula (id 1)**

```
┌───────────────────┬──────┐
│ a.name            │ b.id │
├───────────────────┼──────┤
│ Ursula K. Le Guin │ 1    │
├───────────────────┼──────┤
│ Ursula K. Le Guin │ 2    │
└───────────────────┴──────┘
```

**Pile B — Ted (id 2)**

```
┌────────────┬──────┐
│ a.name     │ b.id │
├────────────┼──────┤
│ Ted Chiang │ 3    │
├────────────┼──────┤
│ Ted Chiang │ 4    │
└────────────┴──────┘
```

**Pile C — Jemisin (id 3)**

```
┌───────────────┬──────┐
│ a.name        │ b.id │
├───────────────┼──────┤
│ N. K. Jemisin │ 5    │
└───────────────┴──────┘
```

**Pile D — Unpublished Author (id 4)**

```
┌────────────────────┬──────┐
│ a.name             │ b.id │
├────────────────────┼──────┤
│ Unpublished Author │ NULL │
└────────────────────┴──────┘
```

The output will have **one row per pile**. The rows never get counted all together.

### Stage 3: COUNT(b.id) runs once *inside each pile*

`COUNT(b.id)` counts the non-NULL `b.id` values **within that pile only**:

- Pile A: 2 non-NULL → **2**
- Pile B: 2 non-NULL → **2**
- Pile C: 1 non-NULL → **1**
- Pile D: the single `b.id` is NULL → **0**

So you never get "5 books total" — the books live in different piles and are tallied separately.

> **Why not `COUNT(*)`?** `COUNT(*)` counts *rows*, NULL or not. Pile D has one row (the placeholder), so `COUNT(*)` would wrongly report **1** book for the unpublished author. `COUNT(b.id)` ignores the NULL and correctly reports **0**. Counting a specific column from the **right** table is what turns "no match" into a real zero.

### Final output

```
name                book_count
------------------  ----------
Ursula K. Le Guin   2
Ted Chiang          2
N. K. Jemisin       1
Unpublished Author  0
```

### No GROUP BY = one giant pile

Drop the `GROUP BY` and the whole table becomes a single pile:

```sql
SELECT COUNT(b.id)
FROM authors AS a
LEFT JOIN books AS b ON b.author_id = a.id;
-- → 5   (all the non-NULL book ids, counted together)
```

That's the same `COUNT(b.id)` rule — the only thing `GROUP BY` changed is the question: *"how many books total?"* (5) becomes *"how many books per author?"* (2, 2, 1, 0).

## The Postgres gotcha: GROUP BY must list every non-aggregated column

```sql
GROUP BY a.id, a.name      -- Postgres: required
GROUP BY a.id              -- SQLite: also fine
```

SQLite lets you `GROUP BY a.id` alone and select `a.name` anyway. **Postgres enforces the SQL standard:** every column in the `SELECT` that isn't wrapped in an aggregate must appear in `GROUP BY`. Since we select `a.name`, we have to group by it too — hence `GROUP BY a.id, a.name`.

(Adding `a.name` is safe here: each `a.id` always maps to exactly one `a.name`, so it doesn't create extra piles.)

## Foreign keys are always on

The script has no `PRAGMA foreign_keys = ON` — Postgres enforces foreign keys unconditionally. Try inserting a book pointing at a non-existent author and it fails hard:

```sql
INSERT INTO books (title, year, author_id) VALUES ('Orphan', 2024, 999);
-- ERROR: insert or update on table "books" violates foreign key constraint
```

## Mental model

> **LEFT JOIN** keeps every author alive (NULLs where there's no book) → **GROUP BY** chops the rows into one pile per author *first* → **COUNT(b.id)** counts non-NULL books *inside each pile*. No GROUP BY means one giant pile and one total.

| | Foreign key | JOIN's `ON` clause |
|---|---|---|
| Job | Rejects invalid writes (no orphan `author_id`) | Matches rows when reading across tables |
| Runs on | `INSERT` / `UPDATE` / `DELETE` | every `SELECT` that uses it |

| Choice | Unpublished Author (0 books) |
|---|---|
| `INNER JOIN` | disappears entirely |
| `LEFT JOIN` + `COUNT(b.id)` | shows **0** ✅ |
| `LEFT JOIN` + `COUNT(*)` | shows **1** ❌ (counts the NULL placeholder row) |
