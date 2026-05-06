# Database concepts

## What is a database?

An organized store of data you can query efficiently. Two big families:

### Relational (SQL)

- Data lives in **tables** (rows and columns), like a spreadsheet with a strict schema.
- Tables link to each other via **keys** (e.g. an `author_id` in a `books` table points at a row in `authors`).
- You query with **SQL**, a declarative language: you describe *what* you want, the engine figures out *how* to get it.
- Guarantees called **ACID** (Atomicity, Consistency, Isolation, Durability) make concurrent writes safe.
- Examples: **SQLite**, PostgreSQL, MySQL, SQL Server, Oracle.

What the data looks like — two related tables:

`authors`

| id | name           | country |
| -- | -------------- | ------- |
| 1  | Ursula Le Guin | USA     |
| 2  | Jorge Borges   | AR      |

`books`

| id  | title              | author_id | year |
| --- | ------------------ | --------- | ---- |
| 10  | The Dispossessed   | 1         | 1974 |
| 11  | A Wizard of Earthsea | 1       | 1968 |
| 12  | Ficciones          | 2         | 1944 |

A query joining them:

```sql
SELECT b.title, a.name
FROM books b
JOIN authors a ON a.id = b.author_id
WHERE a.country = 'USA';
```

### Non-relational (NoSQL)

Umbrella term for anything that isn't a relational table. Main flavors:

- **Document stores** (MongoDB, CouchDB): JSON-like documents, flexible schema.
- **Key-value stores** (Redis, DynamoDB): simple `key → value` lookups, very fast.
- **Column-family** (Cassandra, HBase): optimized for huge writes across clusters.
- **Graph** (Neo4j): nodes and edges, great for relationships like social networks.

What the data looks like in each flavor:

**Document store** (MongoDB) — the author and their books can live in one document, no join needed:

```json
{
  "_id": "author_1",
  "name": "Ursula Le Guin",
  "country": "USA",
  "books": [
    { "title": "The Dispossessed", "year": 1974 },
    { "title": "A Wizard of Earthsea", "year": 1968 }
  ]
}
```

**Key-value store** (Redis) — just opaque keys pointing at values; you look up by the exact key:

```
SET  session:abc123   '{"user_id":42,"expires":1714000000}'
GET  session:abc123
INCR page_views:home
```

**Column-family** (Cassandra) — rows grouped by a partition key, with wide, sparse columns optimized for huge write volumes:

```
partition: user:42
  ├─ login:2026-04-01T09:00  → "ok"
  ├─ login:2026-04-02T09:01  → "ok"
  └─ login:2026-04-03T08:58  → "failed"
```

**Graph** (Neo4j) — nodes and the edges between them are first-class:

```
(Ursula:Author)-[:WROTE]->(Dispossessed:Book)
(Ursula:Author)-[:WROTE]->(Earthsea:Book)
(Alice:User)-[:FOLLOWS]->(Bob:User)-[:FOLLOWS]->(Carol:User)
```

Use non-relational when your data is loosely structured, needs to scale horizontally across many machines, or its shape changes often.

## Where does SQLite fit?

**SQLite is a relational database.** But it's unusual in two ways:

1. **Embedded, not server-based.** The whole DB is a *single file* on disk. No server process, no network port, no configuration. Your program opens the file, reads/writes, and closes it.
2. **In-process.** The SQLite library runs inside your application. PostgreSQL/MySQL run as a separate server you connect to over a socket.

That makes it ideal for:

- Learning SQL (zero setup).
- Mobile apps, desktop apps, browser storage.
- Small-to-medium websites (SQLite can happily handle millions of rows).
- Local caches, test fixtures, config stores.

It's *not* ideal for:

- Many concurrent writers (only one writer at a time — readers are fine in parallel).
- Data that needs to live on a separate machine from the app.

## The vocabulary you'll see

| Term          | Meaning                                                             |
| ------------- | ------------------------------------------------------------------- |
| Table         | A named collection of rows with a fixed set of columns.             |
| Row / record  | One entry in a table.                                               |
| Column / field| One named attribute per row, with a type (INTEGER, TEXT, REAL…).    |
| Primary key   | A column whose value uniquely identifies a row.                     |
| Foreign key   | A column whose value refers to a primary key in another table.      |
| Schema        | The definition of your tables and their columns.                    |
| Query         | A SQL statement, usually `SELECT …`, that reads data.               |
| Transaction   | A group of statements that succeed or fail as one atomic unit.      |
| Index         | A lookup structure that makes reads on a column much faster.        |

## Relational vs non-relational — quick rule of thumb

- Your data has a clear shape and you care about consistency? → **Relational.**
- Your data is semi-structured, deeply nested, or the shape keeps changing? → **Document / NoSQL.**
- You only ever look things up by one key, and speed is everything? → **Key-value.**
- Your data is mostly *connections* (who follows whom, what leads to what)? → **Graph.**

For almost all learning and most real projects, starting with a relational DB like SQLite is the right call — you'll build intuition about data modeling that transfers everywhere.
