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
