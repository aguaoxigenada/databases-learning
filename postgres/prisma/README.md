# Prisma + PostgreSQL Learning Project

Same arc as `../../sqlite/prisma/`. The `.ts` lesson files are byte-for-byte copies — the point is that Prisma Client's API doesn't care which SQL engine is underneath. The only change is one line in `schema.prisma`.

## Files

1. `01-concepts.md` — the one-line diff against `sqlite/prisma/`, and what `env("DATABASE_URL")` buys you.
2. `prisma/schema.prisma` — models; `provider = "postgresql"`.
3. `02-basics.ts` — CRUD against the `User` model.
4. `03-relationships.ts` — one-to-many Author/Books with nested writes and `include`.
5. `04-queries.ts` — filters, aggregates, `groupBy`, pagination.
6. `05-transactions.ts` — `$transaction` array form, and the callback form with rollback.

## First-time setup

A running Postgres — the `pg-learn` Docker container from `../README.md` — and a `prisma_learn_pg` database (already created if you ran the scaffolding):

```bash
docker exec pg-learn createdb -U postgres prisma_learn_pg
```

Then from inside `postgres/prisma/`:

```bash
cp .env.example .env        # fill in if your creds differ
npm install
npx prisma migrate dev --name init
```

`migrate dev` does three things at once:
1. Applies your schema to the Postgres database (creates the tables).
2. Writes a migration file to `prisma/migrations/` (check it in — it's how teammates and CI sync the schema).
3. Regenerates Prisma Client so the types in your editor match the schema.

## Running a lesson script

```bash
npx tsx 02-basics.ts
npx tsx 03-relationships.ts
npx tsx 04-queries.ts
npx tsx 05-transactions.ts
```

Or via npm shortcuts:

```bash
npm run basics
npm run relationships
npm run queries
npm run transactions
```

## Exploring the data visually

```bash
npx prisma studio
```

Opens `http://localhost:5555`.

## Reset

```bash
npx prisma migrate reset --force
```

Drops the database, recreates it, re-applies every migration.
