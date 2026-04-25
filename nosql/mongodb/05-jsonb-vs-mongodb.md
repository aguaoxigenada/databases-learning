# Postgres JSONB vs MongoDB — side by side

Now that you've worked through both, here's the same tasks expressed in each. The pattern to notice: MongoDB's syntax is more ergonomic for document-shaped problems; Postgres's shines the moment you need joins, types, or transactions across entities.

Reference files for each row:
- Postgres: `../../postgres/advanced/05-jsonb-and-arrays.sql`
- MongoDB: this folder's `03-nested-and-arrays.js` and `04-queries-and-aggregation.js`

## Task 1 — Insert a nested document

**Postgres + JSONB**

```sql
INSERT INTO events (type, payload) VALUES
    ('signup', '{"user": "alice", "plan": "pro", "source": {"campaign": "spring25"}}');
```

**MongoDB**

```js
db.events.insertOne({
    type: "signup",
    user: "alice",
    plan: "pro",
    source: { campaign: "spring25" }
});
```

Mongo's flatter: there's no "the payload column" vs "the other columns" distinction. The entire document is queryable fields.

## Task 2 — Filter on a nested value

**Postgres**

```sql
SELECT payload ->> 'user'
FROM events
WHERE payload ->> 'plan' = 'pro';
```

**MongoDB**

```js
db.events.find({ plan: "pro" }, { user: 1, _id: 0 });
```

Mongo is terser here. But note: if you wanted to filter `plan` AND join to a typed `users` table with the rest of the user's info, Postgres does that natively while Mongo needs `$lookup`.

## Task 3 — Containment ("matches this shape at any nesting depth")

**Postgres**

```sql
SELECT id FROM events WHERE payload @> '{"source": {"campaign": "spring25"}}';
```

**MongoDB**

```js
db.events.find({ "source.campaign": "spring25" });
```

Different tools — Postgres's `@>` matches any sub-shape; Mongo uses a dotted path for a specific nested field. Equal power, different idiom.

## Task 4 — Unfold an array of items

**Postgres**

```sql
SELECT e.id, item ->> 'sku' AS sku, (item ->> 'qty')::INTEGER AS qty
FROM events e, jsonb_array_elements(e.payload -> 'items') AS item
WHERE e.type = 'purchase';
```

**MongoDB**

```js
db.events.aggregate([
    { $match: { type: "purchase" } },
    { $unwind: "$items" },
    { $project: { _id: 1, sku: "$items.sku", qty: "$items.qty" } }
]);
```

Both express the same shape. Mongo's aggregation pipeline is more discoverable once you know the stage names; Postgres leans on the `SELECT ... FROM ...` grammar you already know.

## Task 5 — Aggregate

**Postgres**

```sql
SELECT payload ->> 'user' AS user, COUNT(*) AS n
FROM events
WHERE type = 'signup'
GROUP BY payload ->> 'user';
```

**MongoDB**

```js
db.events.aggregate([
    { $match: { type: "signup" } },
    { $group: { _id: "$user", n: { $sum: 1 } } }
]);
```

## Task 6 — Index a nested field

**Postgres**

```sql
CREATE INDEX idx_events_user ON events ((payload ->> 'user'));
-- or, for anything inside payload:
CREATE INDEX idx_events_payload_gin ON events USING GIN (payload);
```

**MongoDB**

```js
db.events.createIndex({ user: 1 });
```

Mongo wins on ergonomics. Postgres wins on "one big index (`GIN`) accelerates *any* `@>` query", without needing to know in advance which paths you'll query.

## Task 7 — Join to another entity

**Postgres**

```sql
SELECT u.email, COUNT(e.id) AS events
FROM users u
LEFT JOIN events e ON e.payload ->> 'user' = u.handle
GROUP BY u.id;
```

**MongoDB**

```js
db.events.aggregate([
    { $lookup: { from: "users", localField: "user", foreignField: "handle", as: "u" } },
    { $unwind: "$u" },
    { $group: { _id: "$u.email", events: { $sum: 1 } } }
]);
```

This is where Postgres pulls ahead. `$lookup` works but costs more, and you'll quickly want types and foreign-key integrity on that users table — which Mongo doesn't provide.

## Picking between them — the honest version

**Pick Postgres + JSONB if:**
- Most of your data is relational and you have *some* semi-structured bits.
- You need SQL JOINs, strict types, ACID transactions across tables.
- You want one system instead of two.
- You already know SQL. (This is most people.)

**Pick MongoDB if:**
- Your data is *mostly* documents with varying shapes — IoT events, product catalogs with wildly different attributes, analytics logs.
- Deep cross-entity queries are rare.
- You need horizontal sharding baked in from day one.
- Your team is already fluent in the aggregation pipeline.

**Skip both and pick something else if:**
- You want a cache or ephemeral state → **Redis.**
- You want ranked full-text search first and foremost → **Elasticsearch** / **Meilisearch**.
- You want a graph → **Neo4j.**

For most new projects in 2026, "Postgres + JSONB for the flexible fields + Redis for the hot path" beats reaching for MongoDB. Know MongoDB because you'll meet it; prefer Postgres unless you have a specific reason.
