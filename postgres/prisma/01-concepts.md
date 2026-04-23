# Prisma on Postgres — the one-line change

You already saw Prisma in `../../sqlite/prisma/`. This folder exists to make one point stick: **switching engines is a one-line change in `schema.prisma`.**

## The diff against `sqlite/prisma/`

```diff
 datasource db {
-  provider = "sqlite"
-  url      = "file:./dev.db"
+  provider = "postgresql"
+  url      = env("DATABASE_URL")
 }
```

That's it. The models, the TypeScript, the Prisma Client calls — all identical. This folder's 4 lesson `.ts` files are byte-for-byte copies of the SQLite versions. **This is the point of an ORM.**

## What does change, even if you don't see it

Behind the scenes, the Prisma team does the work:

- **SQL dialect translation.** When you call `prisma.user.create()`, Prisma generates SQL. For SQLite it emits SQLite SQL; for Postgres it emits Postgres SQL. You see neither.
- **Type mapping.** Prisma's `DateTime` maps to SQLite TEXT (no native type) and to Postgres `TIMESTAMP(3)`. Prisma handles the conversion on read/write.
- **Migrations.** `prisma migrate dev` on SQLite writes different SQL from Postgres — same schema.prisma, different `migration.sql`. Check `prisma/migrations/` after you run it.

## One leaky abstraction you'll hit in lesson 04

Even though the `.ts` files are byte-identical, the **results can differ** when the underlying SQL semantics differ. The clearest case:

```ts
await prisma.book.findMany({
  where: { title: { contains: "the" } },
});
```

- On **SQLite**, this matches "The Dispossessed" and "The Fifth Season". SQLite's `LIKE` is case-insensitive on ASCII.
- On **Postgres**, this returns `[]`. Postgres's `LIKE` is case-sensitive.

Fix (Postgres-only):

```ts
where: { title: { contains: "the", mode: "insensitive" } }
```

`mode: "insensitive"` is the standard Prisma incantation for case-insensitive text search on Postgres. It's the same lesson as `LIKE` vs `ILIKE` from `../basics/04-queries.sql`, now surfacing through the ORM. Watch for similar leaks: the ORM hides most differences, but semantics sometimes bleed through.

## What you SHOULD do differently in Postgres projects

Two habits Postgres enables that SQLite can't:

1. **Use `env("DATABASE_URL")` from day one.** SQLite's `"file:./dev.db"` is a hardcoded path and that's fine because SQLite lives inside your repo. Postgres lives somewhere (localhost? Docker? Neon?) — that "somewhere" changes between dev, CI, and prod. The env var is the lever that switches it.

2. **Never commit `.env`.** It holds credentials. Ship `.env.example` (with placeholder values) so new contributors know which vars to set.

## Workflow — same as SQLite

```bash
npm install                    # install deps
npx prisma migrate dev         # create tables in Postgres, generate client
npx tsx 02-basics.ts           # run a lesson
npx prisma studio              # browse data in a GUI
```

## Connection string anatomy

Your `.env` contains:

```
DATABASE_URL="postgresql://postgres:learn@localhost:5432/prisma_learn_pg?schema=public"
```

Decoded:

```
postgresql://           protocol — tells Prisma which adapter to use
postgres                user
:learn                  password
@localhost              host (Docker forwards 5432 to this container)
:5432                   port
/prisma_learn_pg        database name on the server
?schema=public          Postgres "schema" (namespace inside the DB; default is `public`)
```

When you move to a cloud Postgres, the only thing that changes is this string. Everything else in the project is portable as-is.
