# 04-queries.ts — Filters, Aggregates, Pagination (Postgres)

Mostly a verbatim copy of
[`../../sqlite/prisma/04-queries.md`](../../sqlite/prisma/04-queries.md) —
range filters, `aggregate()`, `groupBy` + the two-query/`Map` pattern, the
tie-safe variant, and `take`/`skip` pagination all behave the same. Read that
companion for the full breakdown.

**One query behaves differently on Postgres, and it's the whole reason this
folder exists.**

Run with:

```bash
npx tsx 04-queries.ts
```

---

## The leak: `contains` is case-sensitive on Postgres

The lesson runs this identical line on both engines:

```ts
await prisma.book.findMany({
  where: { title: { contains: "the" } },
});
```

The seeded titles include **T**he Dispossessed and **T**he Fifth Season
(capital T).

| Engine | What `contains: "the"` matches | Why |
|---|---|---|
| SQLite | *The Dispossessed*, *The Fifth Season* | SQLite's `LIKE` is case-insensitive for ASCII |
| Postgres | `[]` — nothing | Postgres's `LIKE` is case-**sensitive** |

> ⚠️ The inline comment in `04-queries.ts` still says *"SQLite's LIKE is
> case-insensitive…"*. That's deliberate: the file is a byte-for-byte copy of
> the SQLite version, so the comment describes the SQLite run, not the Postgres
> one you're looking at. **The empty result is the lesson** — identical code,
> different rows, because the SQL dialect underneath has different defaults.

---

## The fix: `mode: "insensitive"`

```ts
await prisma.book.findMany({
  where: { title: { contains: "the", mode: "insensitive" } },
});
```

`mode: "insensitive"` is Prisma's switch for case-insensitive text matching on
Postgres — it compiles to `ILIKE` instead of `LIKE`. This is the same
`LIKE` vs `ILIKE` distinction from
[`../basics/04-queries.sql`](../basics/04-queries.sql), now surfacing through
the ORM.

(`mode` is unsupported on SQLite, which is why the shared lesson file omits it.)

| Prisma | Postgres SQL |
|---|---|
| `contains: "x"` | `LIKE '%x%'` (case-sensitive) |
| `contains: "x", mode: "insensitive"` | `ILIKE '%x%'` (case-insensitive) |

---

## Mental model

The ORM hides *most* engine differences, but **collation and case semantics
bleed through**. When a text filter returns fewer rows than you expect on
Postgres, reach for `mode: "insensitive"`. Everything else in this lesson —
aggregates, `groupBy`, pagination — is fully portable.
