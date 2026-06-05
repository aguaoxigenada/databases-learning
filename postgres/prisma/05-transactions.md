# 05-transactions.ts — Transactions (Postgres)

Verbatim copy of the SQLite lesson. Both `$transaction` forms (array and
callback), the `tx` transaction-scoped client, throw-to-rollback /
return-to-commit, and the `async` / `await` / `Promise.all` primer are all
covered in full in
[`../../sqlite/prisma/05-transactions.md`](../../sqlite/prisma/05-transactions.md).

This page only records what's different on Postgres.

Run with:

```bash
npx tsx 05-transactions.ts
```

---

## What's different: real isolation levels

`$transaction` itself behaves identically. The Postgres-only bonus is that you
can set an **isolation level** — the rule for how concurrent transactions see
each other's uncommitted work:

```ts
import { Prisma, PrismaClient } from "@prisma/client";

await prisma.$transaction(
  async (tx) => {
    // ... read, decide, write ...
  },
  { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
);
```

| | SQLite | Postgres |
|---|---|---|
| Concurrency model | one writer at a time (whole-file lock) | MVCC — many concurrent writers |
| `isolationLevel` option | not supported | `ReadCommitted` (default), `RepeatableRead`, `Serializable` |

You don't need it for this single-process lesson, but it's the knob that starts
to matter once multiple clients hit the same rows at once (e.g. two transfers
draining the same account concurrently).

---

## Mental model

**Atomicity** (all-or-nothing) is identical everywhere — that's what
`$transaction` guarantees. **Isolation** — what concurrent transactions are
allowed to see — is where Postgres gives you real controls that SQLite's
single-writer model never needed.
