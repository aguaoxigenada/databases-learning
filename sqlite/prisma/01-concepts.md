# Prisma on top of SQLite

In `../basics/` you talked to SQLite directly using SQL. Here you use **Prisma**, a TypeScript ORM, to do the same work. Same database file format underneath; very different developer experience on top.

## What Prisma is (and isn't)

Prisma is three things that work together:

1. **Prisma Schema** (`prisma/schema.prisma`) — one file that describes every table and relationship in a declarative DSL. It's the single source of truth for your database shape.
2. **Prisma Migrate** — a CLI that diffs your schema against the live database and generates SQL migration files to bring them in sync. You never hand-write `CREATE TABLE`.
3. **Prisma Client** — a generated, fully-typed TypeScript client. `prisma.user.findMany({ where: { age: { gt: 27 } } })` replaces `SELECT * FROM users WHERE age > 27`. Your editor autocompletes every column name, and the result type is inferred.

Prisma is **not** a database. It's a layer that sits between your TypeScript code and the real database (SQLite here, but it can point at PostgreSQL, MySQL, etc., by changing the `datasource` block).

## ORM vs raw SQL — the tradeoff

| | Raw SQL (basics folder) | Prisma |
|---|---|---|
| Schema lives in | each script's `CREATE TABLE` | one `schema.prisma` file |
| Queries written as | SQL strings | TypeScript method calls |
| Type safety | none — typos fail at runtime | typos fail at *compile* time |
| Portability between DBs | low — dialects differ | high — same API for Postgres/MySQL/SQLite |
| Access to every SQL feature | total | most, but not all (e.g. CHECK constraints, window functions need raw SQL) |
| Build-time cost | zero | must run `prisma generate` after schema changes |

Rule of thumb: use an ORM when you want productivity and type safety on everyday CRUD; drop to raw SQL (Prisma supports this too, via `$queryRaw`) when you need something the ORM doesn't model.

## The workflow you'll use

1. Edit `prisma/schema.prisma` to describe what you want.
2. Run `npx prisma migrate dev` — Prisma diffs, generates a migration, applies it to `dev.db`, and regenerates Prisma Client with fresh types.
3. Import `PrismaClient` in a `.ts` file and run queries. Types just *work*.

One important conceptual shift from the basics folder:

> SQL scripts **recreated their tables every run** (`DROP TABLE IF EXISTS` at the top). Prisma scripts **assume the tables already exist** — they were created once by `prisma migrate dev`. Each script still resets its own *rows* (via `deleteMany`) so it's re-runnable, but the *schema* is managed out-of-band.

## Vocabulary shift

| SQL term | Prisma equivalent |
|---|---|
| Table | Model |
| Row | Record (an instance of a model) |
| Column | Field |
| `CREATE TABLE` | model block in `schema.prisma` + `prisma migrate` |
| `INSERT` | `prisma.user.create()` |
| `SELECT` | `prisma.user.findMany()` / `findUnique()` / `findFirst()` |
| `UPDATE` | `prisma.user.update()` / `updateMany()` |
| `DELETE` | `prisma.user.delete()` / `deleteMany()` |
| `JOIN` | `include: { books: true }` on the parent query |
| `BEGIN/COMMIT/ROLLBACK` | `prisma.$transaction([...])` |

Once your eye translates between the two columns, you'll see Prisma is just a convenient skin over the same SQL you already know — with a typechecker watching your back.
