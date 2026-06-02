# 04-queries.ts — Filters, Aggregates, and Pagination

Mirrors `../basics/04-queries.sql`: range filters, text search, aggregates,
`groupBy`, and pagination. Assumes `03-relationships.ts` has been run first
(it needs the authors and books rows to exist).

Run with:

```bash
npx tsx 04-queries.ts
```

---

## Range filter — `BETWEEN` equivalent

```ts
await prisma.book.findMany({
  where: { year: { gte: 1970, lte: 2010 } },
  orderBy: { year: "asc" },
  select: { title: true, year: true },
})
```

You can combine multiple operators on the same field inside one `where` object.
`gte` + `lte` together produce a range — the same as SQL `BETWEEN`.

Equivalent SQL: `SELECT title, year FROM books WHERE year BETWEEN 1970 AND 2010 ORDER BY year ASC`

---

## Text search — `LIKE` equivalent

```ts
await prisma.book.findMany({
  where: { title: { contains: "the" } },
})
```

`contains` maps to `LIKE '%value%'`. SQLite's `LIKE` is case-insensitive for
ASCII by default, so this matches "the", "The", "THE", etc.

Other string operators:

| Prisma | SQL equivalent |
|---|---|
| `contains: "x"` | `LIKE '%x%'` |
| `startsWith: "x"` | `LIKE 'x%'` |
| `endsWith: "x"` | `LIKE '%x'` |

Equivalent SQL: `SELECT title FROM books WHERE title LIKE '%the%'`

---

## Aggregates — `aggregate()`

```ts
const stats = await prisma.book.aggregate({
  _count: { _all: true },
  _min:   { year: true },
  _max:   { year: true },
  _avg:   { year: true },
})
```

Returns a single object with all requested aggregates in one query.

| Prisma | SQL |
|---|---|
| `_count: { _all: true }` | `COUNT(*)` |
| `_min: { year: true }` | `MIN(year)` |
| `_max: { year: true }` | `MAX(year)` |
| `_avg: { year: true }` | `AVG(year)` |
| `_sum: { year: true }` | `SUM(year)` |

Equivalent SQL: `SELECT COUNT(*), MIN(year), MAX(year), AVG(year) FROM books`

---

## `groupBy` — `GROUP BY` + `HAVING` equivalent

```ts
const grouped = await prisma.book.groupBy({
  by: ["authorId"],
  _count: { _all: true },
  having: { authorId: { _count: { gt: 1 } } },
})
```

`by` declares the grouping key (like `GROUP BY authorId`). `having` filters
groups after aggregation — the same as SQL `HAVING COUNT(*) > 1`.

Important limitation: `groupBy` only returns the grouped field and aggregates
— not other columns like `author.name`. To print names you need three steps:

```ts
// 1. groupBy gives you objects with only the grouped field + aggregates:
// [ { authorId: 3, _count: { _all: 2 } }, { authorId: 7, _count: { _all: 2 } } ]

// 2. pull out a plain array of IDs with .map()
const authorIds = grouped.map((g) => g.authorId)
// => [3, 7]

// 3. fetch the author rows for those IDs
const authors = await prisma.author.findMany({
  where: { id: { in: authorIds } },
})
// => [ { id: 3, name: "Ursula K. Le Guin" }, { id: 7, name: "Ted Chiang" } ]

// 4. build a Map (hashmap) for O(1) name lookup by id
const nameById = new Map(authors.map((a) => [a.id, a.name]))
// Map { 3 => "Ursula K. Le Guin", 7 => "Ted Chiang" }

// 5. zip: look up each name while iterating grouped
for (const g of grouped) {
  console.log(`${nameById.get(g.authorId)}: ${g._count._all}`)
}
```

`Map` vs plain object: both are hashmaps, but `Map` keeps keys as their
original type (number). A plain object would coerce `3` → `"3"`.

In raw SQL you'd do this in one query:

```sql
SELECT a.name, COUNT(*) AS book_count
FROM books b
JOIN authors a ON a.id = b.author_id
GROUP BY a.id
HAVING COUNT(*) > 1;
```

Prisma's `groupBy` intentionally doesn't support `include`/`select` on
relations — the two-query + `Map` pattern is the standard workaround.

Equivalent SQL (groupBy alone):
```sql
SELECT authorId, COUNT(*) FROM books
GROUP BY authorId
HAVING COUNT(*) > 1
```

---

## Subquery pattern — two queries + `take: 1`

```ts
// step 1 — find the authorId with the most books
const top = await prisma.book.groupBy({
  by: ["authorId"],
  _count: { _all: true },
  orderBy: { _count: { authorId: "desc" } },
  take: 1,
})

// step 2 — fetch books for that author
await prisma.book.findMany({
  where: { authorId: top[0].authorId },
})
```

Prisma has no direct subquery syntax. The pattern is: run the inner query
first, grab the id, then use it in a second `findMany`. Same logic as a SQL
correlated subquery, just split across two calls.

---

## Pagination — `take` and `skip`

```ts
await prisma.book.findMany({
  orderBy: { year: "desc" },
  take: 2,     // LIMIT 2
  skip: 0,     // OFFSET 0  (omit if zero)
})
```

| Prisma | SQL |
|---|---|
| `take: N` | `LIMIT N` |
| `skip: N` | `OFFSET N` |

Always pair with `orderBy` — without it the page order is undefined.

Equivalent SQL: `SELECT * FROM books ORDER BY year DESC LIMIT 2`

---

## Mental model

| SQL | Prisma |
|---|---|
| `WHERE x BETWEEN a AND b` | `where: { x: { gte: a, lte: b } }` |
| `WHERE title LIKE '%x%'` | `where: { title: { contains: "x" } }` |
| `COUNT / MIN / MAX / AVG / SUM` | `aggregate({ _count, _min, _max, _avg, _sum })` |
| `GROUP BY` | `groupBy({ by: [...] })` |
| `HAVING` | `having: { ... }` inside `groupBy` |
| `LIMIT N` | `take: N` |
| `OFFSET N` | `skip: N` |
| Subquery | two separate queries, pass id between them |
