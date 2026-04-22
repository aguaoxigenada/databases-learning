# Prisma + SQLite Learning Project

The same arc as `../basics/`, but driven by [Prisma](https://www.prisma.io/), a type-safe TypeScript ORM. Database file: `prisma/dev.db` (created on first migrate).

## Files

1. `01-concepts.md` — what an ORM is, how Prisma differs from raw SQL, the mental-model shift from `../basics/`.
2. `prisma/schema.prisma` — single source of truth for the database shape. All models live here.
3. `02-basics.ts` — CRUD against the `User` model.
4. `03-relationships.ts` — one-to-many Author / Books, with nested writes and `include`.
5. `04-queries.ts` — filters, aggregates, `groupBy`, pagination.
6. `05-transactions.ts` — `$transaction` for atomicity, both the array and callback forms.

## First-time setup

From inside `sqlite/prisma/`:

```bash
npm install
npx prisma migrate dev --name init
```

`migrate dev` does three things at once:
1. Creates `prisma/dev.db` if it doesn't exist.
2. Generates a migration file from `schema.prisma` and applies it.
3. Regenerates Prisma Client so the types in your editor match the schema.

## Running a lesson script

```bash
npx tsx 02-basics.ts
npx tsx 03-relationships.ts
npx tsx 04-queries.ts
npx tsx 05-transactions.ts
```

Or via the npm shortcuts in `package.json`:

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

Opens a local web UI at `http://localhost:5555` to browse/edit rows.

## Reset

Wipe the database and re-apply all migrations from scratch:

```bash
npx prisma migrate reset --force
```

Or just delete the file:

```bash
rm -f prisma/dev.db
```

(You'll need to `npx prisma migrate dev` again after a plain delete.)
