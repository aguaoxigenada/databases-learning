# Databases — A Hands-On Tour

A self-directed learning project. Each subfolder is a runnable walkthrough of a different kind of database, with numbered scripts you can execute and tweak.

## What is a database, really?

**An organized store of data you can query efficiently.** That's the whole job description. The interesting question is *how* a given database organizes your data — because that choice determines what it makes easy, what it makes hard, and when it'll burn you.

Databases split into two big families. The rest of this README is about telling them apart.

---

## Relational databases (SQL)

Data lives in **tables**: rows × columns, like a strict spreadsheet. Every row in a table has the same columns. Tables link to each other via **keys** (an `author_id` in `books` pointing at `authors.id`). You query them with **SQL**, a declarative language: *describe what you want, the engine figures out how to get it.* They give you **ACID** guarantees so concurrent writes stay safe.

**Examples:** SQLite, PostgreSQL, MySQL, SQL Server, Oracle.

**Shape — a tiny taste:**

```sql
CREATE TABLE authors (id INTEGER PRIMARY KEY, name TEXT);
CREATE TABLE books (
    id         INTEGER PRIMARY KEY,
    title      TEXT,
    author_id  INTEGER REFERENCES authors(id)
);

SELECT b.title, a.name
FROM books AS b
JOIN authors AS a ON a.id = b.author_id;
```

**When to reach for relational:**
- Your data has a clear, stable shape.
- You care about consistency (money, orders, inventory).
- You'll query it many different ways, not just one.
- Relationships between entities matter (customer → orders → items).
- **This is the right default for ~90% of applications.**

**When to avoid:**
- Your data shape changes constantly and doesn't fit rows/columns.
- You need to scale writes horizontally across dozens of machines.
- You only ever look things up by one key and need microsecond speed.

---

## Non-relational databases (NoSQL)

**"NoSQL" is not a thing — it's an umbrella.** It groups several unrelated database families whose only common trait is "not relational". Don't think of NoSQL as a single alternative to SQL; think of it as five different specialized tools.

### 1. Document stores — *flexible shape*

Data is stored as JSON-like documents. Each document can have a different structure.

**Examples:** MongoDB, CouchDB, Firestore.

```js
// A "users" collection — two documents, different shapes:
{ _id: "u1", name: "Alice", email: "alice@x.com" }
{ _id: "u2", name: "Bob",   email: "bob@x.com",   preferences: { theme: "dark" } }
```

**Use when:** data shape is irregular or evolves often, you ingest from many sources (webhooks, analytics), or your data is naturally nested (a blog post + its comments + tags + author).

**Postgres caveat:** Postgres's `JSONB` type covers ~80% of what teams historically reached for MongoDB for. Before picking MongoDB, ask "could I just use Postgres + JSONB?"

### 2. Key-value stores — *speed over everything*

Just `key → value` lookups. No schema, no joins, no queries beyond "give me the value for this key".

**Examples:** Redis, Memcached, DynamoDB.

```
SET user:42:session "abc123"   EX 3600     -- store with 1-hour TTL
GET user:42:session                         -- fetch
INCR page:hits:2026-04-22                   -- atomic counter
```

**Use when:** caching, session stores, rate limiting, leaderboards, job queues, pub/sub — anywhere you'd normally reach for "remember this thing for a little while, fetch it in microseconds". Not a primary database for most apps; a **companion** to one.

### 3. Column-family — *huge, distributed, write-heavy*

Wide rows split across many machines. Optimised for massive write volume.

**Examples:** Cassandra, HBase, ScyllaDB.

**Use when:** your single-machine Postgres genuinely can't keep up and you're past the point where sharding it yourself makes sense. For most projects: you won't need this.

### 4. Graph databases — *connections are the point*

Nodes (entities) and edges (relationships). Optimised for traversal.

**Examples:** Neo4j, ArangoDB.

```cypher
MATCH (alice:Person {name:"Alice"})-[:FOLLOWS*1..3]->(friend:Person)
RETURN friend.name
```

**Use when:** your data is mostly *connections* — social networks, recommendation engines, fraud rings, knowledge graphs. If every interesting query in your app is "walk the relationships from X", a graph DB earns its keep.

### 5. Search engines — *text, at scale*

Document stores with heavy full-text indexing built in.

**Examples:** Elasticsearch, OpenSearch, Meilisearch.

**Use when:** you need ranked full-text search, faceted filtering, or log analytics. Usually alongside a relational DB, not instead.

---

## Quick decision guide

| Your situation | What to reach for |
|---|---|
| Data has a clear shape, integrity matters | **Relational** (SQLite, Postgres) |
| One-file local DB, zero setup, embedded | **SQLite** |
| Multi-user production web/app backend | **PostgreSQL** |
| Need a fast cache / session store / counter | **Redis** |
| Schema wildly irregular and Postgres JSONB isn't enough | **MongoDB** |
| Core product *is* the graph (social, recs) | **Neo4j** |
| Ranked search over documents or logs | **Elasticsearch** |
| You're not sure | **Postgres**, almost always |

---

## What's in this repo

Each folder has its own `README.md` with setup steps — start there once you pick one.

```
sqlite/
├── basics/     — first SQL: CREATE TABLE, SELECT, JOIN, transactions
├── advanced/   — indexes + EXPLAIN, views, CTEs, window functions
└── prisma/     — same data, through a TypeScript ORM (Prisma)

postgres/
├── basics/     — same arc as SQLite, flagging what changes on a real server
├── advanced/   — EXPLAIN ANALYZE, materialized views, JSONB + arrays + GIN
└── prisma/     — identical .ts code as sqlite/prisma, one-line provider swap

nosql/
└── redis/      — key-value: strings, counters, hashes, lists, sets, sorted sets,
                  TTLs, cache patterns, pub/sub
```

## Reading order (suggested)

1. `sqlite/basics/01-concepts.md` — what SQL looks like in the smallest possible package.
2. `sqlite/basics/` scripts 02-05 — actually run them.
3. `sqlite/advanced/` — this is where SQL stops feeling like a spreadsheet.
4. `sqlite/prisma/` — what an ORM buys you.
5. `postgres/basics/01-concepts.md` — the SQLite → Postgres diff; then the rest of `postgres/`.
6. `nosql/redis/` — different tool, different mental model.

## Prerequisites

Listed per-folder. Broadly:
- `sqlite3` (for `sqlite/`) — `sudo apt install sqlite3`
- Docker (for `postgres/` and `nosql/redis/`) — see each folder's README
- Node 18+ (for either `prisma/` folder)
