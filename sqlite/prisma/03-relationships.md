# 03-relationships.ts — Relations with Prisma Client

Mirrors `../basics/03-relationships.sql`: a one-to-many relation between
`Author` and `Book`. Covers nested writes, `include`, `_count`, and
referential integrity.

Run with:

```bash
npx tsx 03-relationships.ts
```

---

## Delete order matters (foreign keys)

```ts
await prisma.book.deleteMany()    // child first
await prisma.author.deleteMany()  // parent second
```

You must delete the child table (`Book`) before the parent (`Author`) because
each book holds an `authorId` that references an author. Deleting the parent
first would leave orphaned foreign keys — SQLite rejects it.

Equivalent SQL: `DELETE FROM books` then `DELETE FROM authors`

---

## Nested writes

```ts
await prisma.author.create({
  data: {
    name: "Ursula K. Le Guin",
    books: {
      create: [
        { title: "A Wizard of Earthsea", year: 1968 },
        { title: "The Dispossessed",      year: 1974 },
      ],
    },
  },
})
```

Creates the author and their books in a single call. You don't specify
`authorId` on each book — Prisma inserts the author first, gets the new `id`,
then uses it automatically when inserting the books.

Manual equivalent (without nested writes):

```ts
const author = await prisma.author.create({ data: { name: "Ursula K. Le Guin" } })
await prisma.book.createMany({
  data: [
    { title: "A Wizard of Earthsea", year: 1968, authorId: author.id },
    { title: "The Dispossessed",      year: 1974, authorId: author.id },
  ],
})
```

Both produce identical rows. The nested write is just a shortcut.

---

## `include` — the JOIN equivalent

```ts
const books = await prisma.book.findMany({
  include: { author: true },
  orderBy: { year: "asc" },
})

for (const b of books) {
  console.log(`${b.title} (${b.year}) — ${b.author.name}`)
}
```

`include: { author: true }` tells Prisma to also fetch the related `Author`
row for each book and nest it as an object on the result. No manual JOIN
required.

Result shape:

```ts
{
  id: 1,
  title: "A Wizard of Earthsea",
  year: 1968,
  authorId: 1,
  author: { id: 1, name: "Ursula K. Le Guin" }  // ← included
}
```

Equivalent SQL: `SELECT books.*, authors.* FROM books INNER JOIN authors ON books.authorId = authors.id`

---

## `_count` — the GROUP BY COUNT equivalent

```ts
const authors = await prisma.author.findMany({
  include: { _count: { select: { books: true } } },
  orderBy: { books: { _count: "desc" } },
})

for (const a of authors) {
  console.log(`${a.name}: ${a._count.books}`)
}
```

`_count` is a special Prisma field that counts related records. Authors with
no books get a count of `0` — equivalent to a `LEFT JOIN` with `COUNT`.

Result shape:

```ts
{
  id: 3,
  name: "N. K. Jemisin",
  _count: { books: 1 }
}
```

Equivalent SQL:
```sql
SELECT authors.*, COUNT(books.id) AS book_count
FROM authors
LEFT JOIN books ON books.authorId = authors.id
GROUP BY authors.id
ORDER BY book_count DESC
```

---

## Referential integrity

```ts
// This throws — no author with id 999 exists.
await prisma.book.create({ data: { title: "Orphan", year: 2024, authorId: 999 } })
```

Prisma enforces foreign key constraints. If you try to insert a book pointing
at a non-existent author, you get a typed error before the query even reaches
the database.

---

## Mental model

| SQL | Prisma |
|---|---|
| `INSERT` parent then child with FK | nested `create` inside parent |
| `INNER JOIN` | `include: { relation: true }` |
| `LEFT JOIN` + `COUNT(*)` | `include: { _count: { select: { relation: true } } }` |
| `ORDER BY COUNT(...)` | `orderBy: { relation: { _count: "desc" } }` |
| FK violation error | Prisma throws before the query reaches the DB |
