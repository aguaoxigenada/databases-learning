# From SQLite to PostgreSQL — what actually changes

You already know relational databases from `sqlite/basics/`. This document is a diff, not a re-teach: only the things that *behave differently* when you move to Postgres.

## Mental model shift

| | SQLite | PostgreSQL |
|---|---|---|
| Physical form | one file on disk | a background server process |
| You connect via | opening a file path | host + port + user + password + database |
| Concurrent writers | one at a time (others wait) | many at once (MVCC handles them) |
| Per-query overhead | near zero | tiny TCP/socket round-trip |
| Users and permissions | none | full `GRANT`/`REVOKE`; every query runs as a role |
| Default type enforcement | loose ("type affinity") | strict: `INTEGER` column rejects `'hello'` |

## Schema syntax — the real differences

### Auto-incrementing IDs

SQLite:
```sql
id INTEGER PRIMARY KEY   -- auto-increments automatically
```

Postgres — three valid forms, modern one first:
```sql
id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY    -- SQL-standard, Postgres 10+
id SERIAL PRIMARY KEY                                  -- older, still very common
id BIGSERIAL PRIMARY KEY                               -- same but 64-bit (big tables)
```

We use `GENERATED ALWAYS AS IDENTITY` in these scripts — it's the standards-compliant form and doesn't leave a hidden sequence object in the way `SERIAL` does.

### Timestamps

```sql
-- SQLite: stored as TEXT, no timezone notion at all.
created_at TEXT DEFAULT CURRENT_TIMESTAMP

-- Postgres: real type, with timezone.
created_at TIMESTAMPTZ DEFAULT NOW()
```

`TIMESTAMPTZ` stores UTC internally and converts to the client's timezone on read. Use it by default — unzoned timestamps are almost always a bug waiting to happen.

### Foreign keys

SQLite required `PRAGMA foreign_keys = ON` every session. Postgres enforces them always. No incantation needed.

### `AUTOINCREMENT` / `PRAGMA` / `.tables`

None of those exist in Postgres. Equivalents:

| SQLite | Postgres |
|---|---|
| `.tables` | `\dt` |
| `.schema users` | `\d users` |
| `.quit` | `\q` |
| `PRAGMA foreign_keys = ON` | (not needed) |

## Query differences to watch for

- **`LIKE` is case-sensitive in Postgres** (case-insensitive on ASCII in SQLite). Use `ILIKE` for case-insensitive matching. You'll see this in `04-queries.sql`.
- **Single quotes only for strings.** `"Alice"` is an *identifier* (a column or table name) in Postgres — it'll error. Use `'Alice'`.
- **`||` concatenates strings** in both, but in Postgres mixing types (`'count: ' || 5`) needs explicit casts: `'count: ' || 5::TEXT`.

## Transaction behaviour — important

In SQLite, if one statement inside a transaction fails (e.g. a CHECK constraint), the other statements keep working; only the failed one is rolled back.

In **Postgres, the whole transaction is poisoned** the moment one statement errors. Every subsequent statement returns `ERROR: current transaction is aborted, commands ignored until end of transaction block`. You have to `ROLLBACK` (or `ROLLBACK TO SAVEPOINT`, covered later) before you can continue.

This is stricter and — in practice — safer: it forces you to explicitly decide how to recover.

## The rest

JOINs, GROUP BY, HAVING, subqueries, ORDER BY, LIMIT — all work identically. If your SQLite SQL ran, the Postgres port is mostly a matter of the schema snippets above.
