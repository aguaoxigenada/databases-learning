# MongoDB — concepts

You've seen relational (tables, rows, columns, joins) and key-value (Redis). MongoDB sits between them: **collections of documents**. A document is a JSON-ish object; a collection is an unordered bag of documents that don't have to share a shape.

## Mental model

| SQL term | MongoDB term |
|---|---|
| Database | Database |
| Table | **Collection** |
| Row | **Document** |
| Column | **Field** |
| Primary key | **`_id`** (auto-generated ObjectId unless you pass one) |
| Foreign key | A field holding another doc's `_id`. No referential integrity enforcement. |
| JOIN | **`$lookup`** stage in aggregation — slower and stricter than SQL JOINs |
| INDEX | Same idea: `db.collection.createIndex(...)` |

A document is plain JSON (technically BSON — Binary JSON — under the hood, adding types like `Date`, `ObjectId`, `Decimal128`). Example:

```json
{
  "_id": ObjectId("..."),
  "name": "Alice",
  "email": "alice@example.com",
  "age": 30,
  "preferences": { "theme": "dark", "notifications": false },
  "tags": ["pro", "beta"]
}
```

## The big pitch — and the big asterisk

### Pitch
- **Schemaless by default.** Add a field to one document, don't touch the others. No migration.
- **Natural nesting.** An order document can *contain* its line items. No separate `order_items` table. One read returns the whole thing.
- **Horizontal scaling built in.** Sharding is first-class; the protocol and tooling are designed for it.

### Asterisk
- **Schemaless means schema in your head and in your app code.** The moment two services read the same collection and assume different shapes, you have a real bug and no database error to catch it. Use schema validation (Mongoose, Zod, Mongo's own `$jsonSchema` validator) — don't go truly schemaless in production.
- **No real joins.** `$lookup` exists but is not cheap. If your data is deeply relational (orders → users → addresses → countries), MongoDB fights you.
- **Transactions across collections are possible but slower than single-document writes.** Design so most operations touch one document.

## MongoDB vs Postgres JSONB — the honest comparison

| Concern | Postgres + JSONB | MongoDB |
|---|---|---|
| Strict schema for most fields, flexible JSON blob for a few | ✅ natural — typed columns + one JSONB column | ⚠️ possible via validators, but going-against-grain |
| Everything is a document with different shapes | 😐 works, but awkward on a big JSONB table | ✅ natural |
| JOIN across entities | ✅ first-class, fast, any depth | ⚠️ `$lookup` works but is clumsier and slower |
| Transactions across entities | ✅ rock-solid MVCC | ⚠️ multi-doc transactions exist but are slower |
| Full-text search | ✅ built-in tsvector + GIN | ✅ built-in `$text` + Atlas Search |
| Index a nested field | ✅ expression index on `jsonb_path` | ✅ `db.col.createIndex({"a.b": 1})` — simpler |
| Horizontal scaling | ⚠️ requires external tooling (Citus, partitioning) | ✅ native sharding |
| Strong ecosystem, SQL skills transfer | ✅ | ❌ aggregation pipeline is its own language |
| Default choice for new apps in 2026 | ✅ | ⚠️ only if you have a reason |

### Rule of thumb

- Your data is **mostly relational** with a few flexible fields? → **Postgres + JSONB.** You get schemaless-where-you-need-it without giving up JOINs and types.
- Your data is **mostly documents** with rare cross-doc queries (IoT events, analytics logs, product catalogs with wildly varying attributes)? → **MongoDB.**
- You're not sure? → **Postgres + JSONB.** It's the more forgiving choice and can grow in either direction.

## What this folder teaches

- How documents look in practice (`02-basics.js`).
- How nesting and arrays replace child tables — and what queries you get against them (`03-nested-and-arrays.js`).
- The **aggregation pipeline** — Mongo's answer to `SELECT ... GROUP BY` (`04-queries-and-aggregation.js`). This is where Mongo starts to feel like its own thing rather than "JSON storage".
- A final doc (`05-jsonb-vs-mongodb.md`) lining up the same tasks side-by-side against `postgres/advanced/05-jsonb-and-arrays.sql` so you can see the daylight.

## How you'll actually use Mongo in an app

- **Driver:** official `mongodb` package for Node, plus `mongoose` (schema-ish ORM) layered on top if you want types and validation.
- **Connection:** `mongodb://user:pass@host:27017/dbname` — same shape as Postgres.
- The raw `mongosh` commands you'll write in this folder map 1:1 onto the driver's methods: `db.users.insertOne(...)` on the shell → `db.collection('users').insertOne(...)` in Node.
