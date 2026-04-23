# PostgreSQL — Advanced

Same arc as `../../sqlite/advanced/`, plus two files that cover features SQLite can't offer.

## Files

1. `01-indexes-and-explain.sql` — indexes + `EXPLAIN ANALYZE` (real timings, not just the plan shape). Mentions index types Postgres ships that SQLite doesn't.
2. `02-views.sql` — views **and materialized views**, the cached-result kind SQLite lacks.
3. `03-ctes.sql` — CTEs; nearly identical to the SQLite version, since the standard is the standard.
4. `04-windows.sql` — window functions; also ~identical.
5. `05-jsonb-and-arrays.sql` — **Postgres-only**: `JSONB`, arrays, GIN indexes. This is the headline feature set that makes Postgres shine over SQLite for anything semi-structured.

## Prerequisite

The `learn_pg` database from `../basics/`. Each script drops and recreates the tables it uses — names don't collide with basics' tables, so everything coexists cleanly.

## Running

```bash
docker exec -i pg-learn psql -U postgres -d learn_pg < 01-indexes-and-explain.sql
```

## Reset

Same as basics — drop and recreate the database, or just re-run the scripts (each drops its own tables first).
