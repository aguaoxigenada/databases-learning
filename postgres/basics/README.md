# PostgreSQL — Basics

Parallel to `../../sqlite/basics/`. The SQL you'll write here is 95% identical — this folder's job is to show you the 5% that differs, and to get you comfortable talking to a real server instead of a file.

## Files

1. `01-concepts.md` — what changes when you go from SQLite (a file) to Postgres (a server). Read this first.
2. `02-basics.sql` — `users` table: CRUD.
3. `03-relationships.sql` — `authors` + `books`: foreign keys, joins.
4. `04-queries.sql` — filters, aggregates, grouping. **New thing**: `ILIKE` vs `LIKE`.
5. `05-transactions.sql` — transactions. **New thing**: statement-level vs transaction-level error behaviour.

## Prerequisite

A running Postgres. See `../README.md` — you should already have a `pg-learn` Docker container and a `learn_pg` database.

## How to run a script

We pipe the file through `docker exec`'s stdin into `psql` running inside the container:

```bash
# from inside postgres/basics/
docker exec -i pg-learn psql -U postgres -d learn_pg < 02-basics.sql
```

## How to explore interactively

```bash
docker exec -it pg-learn psql -U postgres -d learn_pg
```

Inside the `learn_pg=#` prompt:

```
\dt                  -- list tables   (Postgres equivalent of SQLite's .tables)
\d users             -- describe a table's schema
SELECT * FROM users; -- run a query (don't forget the ; at the end)
\q                   -- quit
```

## Reset

Drop and recreate the database:

```bash
docker exec pg-learn dropdb -U postgres learn_pg
docker exec pg-learn createdb -U postgres learn_pg
```
