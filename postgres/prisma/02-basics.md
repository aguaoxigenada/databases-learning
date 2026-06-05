# 02-basics.ts — CRUD with Prisma Client (Postgres)

The `.ts` file is a verbatim copy of the SQLite version. The full
method-by-method walkthrough — `deleteMany`, `createMany`, `findMany`,
`update`, `delete`, and the `$disconnect()` pattern — lives in
[`../../sqlite/prisma/02-basics.md`](../../sqlite/prisma/02-basics.md).

This page only records what's different on Postgres.

Run with:

```bash
npx tsx 02-basics.ts
```

---

## What's different: nothing you can see

Every method call behaves identically. The only change is underneath, and
Prisma hides it from you:

| What the schema declares | SQLite stores it as | Postgres stores it as |
|---|---|---|
| `createdAt DateTime @default(now())` | `TEXT` (no native date type) | `TIMESTAMP(3)` |
| `id Int @default(autoincrement())` | `INTEGER PRIMARY KEY` (rowid) | identity sequence (`SERIAL`-style) |

On read/write Prisma converts both directions, so your TypeScript still sees a
`Date` and a `number` no matter which engine is underneath.

---

## Mental model

This lesson is the proof of the ORM thesis: **everyday CRUD is fully
portable**. The first place behavior actually diverges at runtime is lesson 04
— see [`04-queries.md`](04-queries.md).
