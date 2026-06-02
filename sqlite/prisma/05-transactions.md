# 05 — Transactions

Mirrors `../basics/05-transactions.sql`. Atomicity via Prisma's `$transaction`.

---

## What is a transaction?

A transaction groups multiple queries so they either **all succeed** or **all fail together**. No partial states.

Two accounts, one transfer — both the debit and the credit must happen, or neither does.

---

## Two forms of `$transaction`

### 1. Array form — list of queries, all commit or none do

```ts
await prisma.$transaction([
  prisma.account.updateMany({ where: { owner: "Alice" }, data: { balance: { decrement: 30 } } }),
  prisma.account.updateMany({ where: { owner: "Bob"  }, data: { balance: { increment: 30 } } }),
]);
```

Use this when you already know all the queries upfront and don't need logic in between.

### 2. Callback form — needed when you have logic mid-transaction

```ts
await prisma.$transaction(async (tx) => {
  const alice = await tx.account.findFirstOrThrow({ where: { owner: "Alice" } });
  if (alice.balance - 200 < 0) throw new Error("insufficient funds");
  await tx.account.update({ where: { id: alice.id }, data: { balance: alice.balance - 200 } });
});
```

Use this when you need to **read, then decide, then write** — you can't know the second query until the first one returns.

---

## `tx` — the transaction-scoped client

`tx` is a leashed version of `prisma`. Every query made through `tx` is sent inside the same open transaction.

| `prisma.account.find(...)` | `tx.account.find(...)` |
|---|---|
| independent query, auto-committed | part of the open transaction |
| can't be rolled back as a group | rolls back with everything else if anything throws |

Prisma creates `tx` and passes it into your callback — you never instantiate it yourself.

**Throw = rollback. Return normally = commit.**

---

## `async` vs `await`

### `async`

Marks a function as one that **returns a Promise**. Does not mean parallel — the function still runs line by line.

```ts
async function example() {
  const a = await getA(); // waits for A
  const b = await getB(); // only starts after A is done — sequential
}
```

### `await`

Pauses that line until the Promise resolves, then hands the result to the next line.

```ts
const alice = await tx.account.findFirstOrThrow({ where: { owner: "Alice" } });
//                 ^^^^^
//                 wait for the DB to respond, then put the row in `alice`
```

### Parallel — `Promise.all`

To run things at the same time, use `Promise.all` and skip individual awaits:

```ts
const [a, b] = await Promise.all([getA(), getB()]);
// A and B fire at the same time
```

| | meaning | runs in parallel? |
|---|---|---|
| `async` | this function returns a Promise | no |
| `await` | pause until this Promise resolves | no — sequential |
| `Promise.all` | start all at once, wait for all | yes |

---

## Callbacks

A callback is a function you pass as an argument to another function. The caller decides when to invoke it and what to pass in.

### `map` example

```ts
["alice", "bob", "charlie"].map(name => name.toUpperCase())
// call 1: name = "alice"   → "ALICE"
// call 2: name = "bob"     → "BOB"
// call 3: name = "charlie" → "CHARLIE"
// result: ["ALICE", "BOB", "CHARLIE"]
```

### `filter` example

```ts
[1, 2, 3].filter(n => n > 1)
// call 1: n = 1 → false → excluded
// call 2: n = 2 → true  → kept
// call 3: n = 3 → true  → kept
// result: [2, 3]
```

### `$transaction` callback

```ts
prisma.$transaction(async (tx) => {
  // Prisma calls this function and decides what tx is
  // just like map decides what `name` is each iteration
});
```

You write the **what** (the logic inside). The caller controls the **when** and **what gets passed in**.

---

## Mental models

- `tx` — a leashed Prisma client; throw to rollback, return to commit
- `async` — "I return a Promise, you can await me"
- `await` — "pause here, give me the value when done"
- callback — "here's a function, you call it when ready"
