# Transactions in Postgres: all-or-nothing, and recovering with SAVEPOINTs

Companion to `05-transactions.sql`. A **transaction** groups several statements so they either *all* take effect or *none* do. The new ideas here: `BEGIN` / `COMMIT` / `ROLLBACK`, the `CHECK` constraint, the big **Postgres-vs-SQLite difference** in how errors abort a transaction, and `SAVEPOINT` for partial recovery.

## The setup

```sql
CREATE TABLE accounts (
    id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner   TEXT    NOT NULL,
    balance INTEGER NOT NULL CHECK (balance >= 0)
);
```

The key line is **`CHECK (balance >= 0)`** — a constraint that *rejects any write* leaving a balance below zero. It's the guardrail the whole lesson plays against: you can't overdraw an account, and any statement that tries will error.

Starting balances:

```
┌────┬───────┬─────────┐
│ id │ owner │ balance │
├────┼───────┼─────────┤
│ 1  │ Alice │ 100     │
│ 2  │ Bob   │ 50      │
└────┴───────┴─────────┘
```

## Why transactions exist: the money-transfer problem

Moving $30 from Alice to Bob is **two** statements:

```sql
UPDATE accounts SET balance = balance - 30 WHERE owner = 'Alice';
UPDATE accounts SET balance = balance + 30 WHERE owner = 'Bob';
```

If the database crashed *between* these two, Alice would be down $30 and Bob would never receive it — $30 vanishes. A transaction makes the pair **atomic**: both land, or neither does.

## 1. A successful transaction

```sql
BEGIN;
    UPDATE accounts SET balance = balance - 30 WHERE owner = 'Alice';
    UPDATE accounts SET balance = balance + 30 WHERE owner = 'Bob';
COMMIT;
```

- **`BEGIN`** — open a transaction. From here, changes are provisional: held in your session, not yet permanent, invisible to others.
- The two `UPDATE`s run.
- **`COMMIT`** — make everything since `BEGIN` permanent and visible, all at once.

After commit:

```
┌────┬───────┬─────────┐
│ id │ owner │ balance │
├────┼───────┼─────────┤
│ 1  │ Alice │ 70      │   ← 100 − 30
│ 2  │ Bob   │ 80      │   ← 50 + 30
└────┴───────┴─────────┘
```

## 2. A failed transaction — and the big Postgres difference

```sql
BEGIN;
    UPDATE accounts SET balance = balance - 200 WHERE owner = 'Alice';
    -- ERROR: new row violates check constraint "accounts_balance_check"
ROLLBACK;
```

Alice only has 70; subtracting 200 would make her balance −130, which the `CHECK (balance >= 0)` rejects. The statement errors.

- **`ROLLBACK`** — discard *everything* since `BEGIN`, as if the transaction never happened. Balances stay 70 / 80.

### ⚠️ This is where Postgres differs sharply from SQLite

> In Postgres, the moment **any** statement errors inside a transaction, the **entire transaction is poisoned**. Every statement after it returns:
>
> ```
> ERROR: current transaction is aborted, commands ignored until end of transaction block
> ```
>
> Nothing more will run until you `ROLLBACK` (or `COMMIT`, which Postgres turns into a rollback for an aborted transaction).

| | SQLite | Postgres |
|---|--------|----------|
| One statement in a transaction errors | only *that* statement rolls back; the rest keep working | the **whole transaction** aborts; all later statements are refused |
| Recovery | optional | **mandatory** `ROLLBACK` before you can do anything else |

This is stricter, and in practice **safer**: it makes it impossible to "limp along" after a half-done transaction and accidentally commit inconsistent data. You're forced to explicitly decide how to recover.

## 3. SAVEPOINT — partial recovery without losing everything

Sometimes you *don't* want one failed step to nuke the whole transaction. A **`SAVEPOINT`** is a bookmark you can roll back to, keeping the work before it intact.

```sql
BEGIN;
    UPDATE accounts SET balance = balance - 10 WHERE owner = 'Alice';   -- (A) keep this

    SAVEPOINT before_risky;
        UPDATE accounts SET balance = balance - 9999 WHERE owner = 'Alice';  -- (B) will fail
    ROLLBACK TO SAVEPOINT before_risky;   -- undo only (B), un-poison the transaction

    UPDATE accounts SET balance = balance + 10 WHERE owner = 'Bob';     -- (C) carry on
COMMIT;
```

Step by step:

1. **(A)** Alice 70 → 60. This is the work we want to keep.
2. **`SAVEPOINT before_risky`** — drop a bookmark here.
3. **(B)** subtract 9999 → violates `CHECK`, errors, and *aborts the transaction* — but only back **to the savepoint**, not all the way to `BEGIN`.
4. **`ROLLBACK TO SAVEPOINT before_risky`** — rewind to the bookmark. This undoes (B) **and** clears the aborted state, so the transaction is usable again. Step (A)'s −10 is still in effect.
5. **(C)** Bob 80 → 90.
6. **`COMMIT`** — make (A) and (C) permanent.

Final balances:

```
┌────┬───────┬─────────┐
│ id │ owner │ balance │
├────┼───────┼─────────┤
│ 1  │ Alice │ 60      │   ← (A) applied, (B) rolled back
│ 2  │ Bob   │ 90      │   ← (C) applied
└────┴───────┴─────────┘
```

`ROLLBACK TO SAVEPOINT` is the escape hatch from the "whole transaction aborts" rule: it lets you contain a failure to just the risky slice and keep the rest. (SQLite has savepoints too, but you rarely see them — because its per-statement rollback already softens the blow.)

## Mental model

> A transaction is a **draft you haven't published yet.** `BEGIN` opens the draft, your statements edit it privately, `COMMIT` publishes it all at once, `ROLLBACK` shreds it. In Postgres, one error tears the *whole* draft — unless you dropped a `SAVEPOINT` bookmark, which lets you tear out just the bad paragraph and keep writing.

| Command | Does |
|---------|------|
| `BEGIN` | start a transaction (changes become provisional) |
| `COMMIT` | make all changes since `BEGIN` permanent |
| `ROLLBACK` | discard all changes since `BEGIN` |
| `SAVEPOINT name` | bookmark a point inside the transaction |
| `ROLLBACK TO SAVEPOINT name` | undo back to the bookmark *and* un-abort; keep earlier work |

And the one rule to remember crossing over from SQLite: **in Postgres, an error aborts the entire transaction — `ROLLBACK` is not optional.**
