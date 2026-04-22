# Database concepts

## What is a database?

An organized store of data you can query efficiently. Two big families:

### Relational (SQL)

- Data lives in **tables** (rows and columns), like a spreadsheet with a strict schema.
- Tables link to each other via **keys** (e.g. an `author_id` in a `books` table points at a row in `authors`).
- You query with **SQL**, a declarative language: you describe *what* you want, the engine figures out *how* to get it.
- Guarantees called **ACID** (Atomicity, Consistency, Isolation, Durability) make concurrent writes safe.
- Examples: **SQLite**, PostgreSQL, MySQL, SQL Server, Oracle.

### Non-relational (NoSQL)

Umbrella term for anything that isn't a relational table. Main flavors:

- **Document stores** (MongoDB, CouchDB): JSON-like documents, flexible schema.
- **Key-value stores** (Redis, DynamoDB): simple `key → value` lookups, very fast.
- **Column-family** (Cassandra, HBase): optimized for huge writes across clusters.
- **Graph** (Neo4j): nodes and edges, great for relationships like social networks.

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
