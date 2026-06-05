# 03-relationships.ts — Relations with Prisma Client (Postgres)

Verbatim copy of the SQLite lesson. The full walkthrough — nested writes,
`include` as the JOIN equivalent, `_count`, and referential integrity — lives
in [`../../sqlite/prisma/03-relationships.md`](../../sqlite/prisma/03-relationships.md).

This page only records what's different on Postgres.

Run with:

```bash
npx tsx 03-relationships.ts
```

---

## What's different: foreign-key enforcement is free

The delete-child-before-parent rule is identical, and Prisma throws the same
typed error before a bad query reaches the database. The one footnote:

| | SQLite | Postgres |
|---|---|---|
| When are FKs enforced? | only when `PRAGMA foreign_keys = ON` (Prisma sets it for you) | always — there is no switch to forget |
| Risk of orphaned rows | possible in a raw SQLite session that forgot the pragma | impossible |

So the behavior you see in this lesson is the same; Postgres just makes the
guarantee unconditional.

---

## Mental model

Relations, nested writes, and `include` are 100% portable. The foreign-key
guarantee is simply sturdier on Postgres — enforced by the engine itself, not
by a session setting.
