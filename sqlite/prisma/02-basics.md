# 02-basics.ts — CRUD with Prisma Client

Mirrors `../basics/02-basics.sql` but driven entirely by TypeScript method calls
instead of SQL strings. All operations target the `User` model.

Run with:

```bash
npx tsx 02-basics.ts
```

---

## Methods covered

### `deleteMany()`

```ts
await prisma.user.deleteMany()
```

Deletes all rows that match the (optional) `where` clause. Called with no
arguments at the top of the script to wipe the table before each run — this
keeps the script re-runnable without hitting the `email UNIQUE` constraint.

Equivalent SQL: `DELETE FROM users`

---

### `createMany()`

```ts
await prisma.user.createMany({
  data: [
    { name: "Alice", email: "alice@example.com", age: 30 },
    ...
  ],
})
```

Bulk-inserts multiple rows in one statement. Faster than calling `create()`
in a loop. Note: SQLite's driver does not return the created records from
`createMany`, so you need a separate `findMany()` to read them back.

Equivalent SQL: `INSERT INTO users (name, email, age) VALUES (...), (...)`

---

### `findMany()`

```ts
await prisma.user.findMany({
  where:   { age: { gt: 27 } },   // WHERE age > 27
  orderBy: { age: "desc" },        // ORDER BY age DESC
  select:  { name: true, age: true }, // SELECT name, age  (omit the rest)
})
```

Returns an array of records. All clauses are optional — bare `findMany()`
returns every row. Common `where` operators:

| Operator | Meaning |
|---|---|
| `gt` | `>` |
| `gte` | `>=` |
| `lt` | `<` |
| `lte` | `<=` |
| `not` | `!=` |
| `in` | `IN (...)` |
| `contains` | `LIKE '%value%'` |

---

### `update()`

```ts
await prisma.user.update({
  where: { email: "alice@example.com" },
  data:  { age: 31 },
})
```

Updates a single row matched by a **unique** field (like `id` or `email`).
Use `updateMany()` when you want to update by non-unique criteria (e.g. all
users older than 30).

Equivalent SQL: `UPDATE users SET age = 31 WHERE email = 'alice@example.com'`

---

### `delete()`

```ts
await prisma.user.delete({ where: { email: "bob@example.com" } })
```

Deletes a single row by a unique field. Use `deleteMany({ where: {...} })`
to delete by criteria instead.

Equivalent SQL: `DELETE FROM users WHERE email = 'bob@example.com'`

---

## The `$disconnect()` pattern

```ts
main()
  .catch((e) => { console.error(e); process.exit(1) })
  .finally(async () => { await prisma.$disconnect() })
```

Prisma Client holds an open connection pool. Without `$disconnect()` the
Node.js process hangs after `main()` finishes. This try/catch/finally wrapper
is the standard boilerplate for standalone scripts.

---

## Mental model

| SQL | Prisma |
|---|---|
| `INSERT INTO` | `create()` / `createMany()` |
| `SELECT *` | `findMany()` |
| `SELECT` with filter | `findMany({ where: {...} })` |
| `UPDATE ... WHERE unique` | `update()` |
| `UPDATE ... WHERE criteria` | `updateMany()` |
| `DELETE ... WHERE unique` | `delete()` |
| `DELETE ... WHERE criteria` | `deleteMany()` |
