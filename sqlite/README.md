# SQLite Learning Project

A hands-on tour of SQLite: concepts, relational modeling, and queries you can run.

## Files

1. `01-concepts.md` — what a database is, relational vs non-relational, where SQLite fits.
2. `02-basics.sql` — create a table, insert rows, read them back.
3. `03-relationships.sql` — multiple tables linked with foreign keys, joins.
4. `04-queries.sql` — filters, sorting, aggregates, grouping.
5. `05-transactions.sql` — atomicity in practice.

## Prerequisite

Install the SQLite CLI (one-time):

```bash
sudo apt install sqlite3
```

Verify:

```bash
sqlite3 --version
```

## How to run a script

Every script creates/uses a database file called `learn.db` in this folder.

```bash
# from inside ~/databases-learning/sqlite
sqlite3 learn.db < 02-basics.sql
```

## How to explore interactively

```bash
sqlite3 learn.db
```

Inside the prompt, try:

```
.tables              -- list tables
.schema users        -- show a table's definition
SELECT * FROM users; -- run a query (don't forget the ; at the end)
.quit                -- exit
```

## Reset

Starting fresh is just deleting the file:

```bash
rm -f learn.db
```
