// 05-transactions.exercises.ts — fill-in-the-blank practice for 05-transactions.ts
//
// HOW THIS WORKS:
//   - Scaffolding done; you fill the `// TODO:`s.
//   - Run any time:  npx tsx 05-transactions.exercises.ts
//   - Re-seeds every run.  Seed balances: Alice 100, Bob 50.
//
// Paste this file back when done and I'll grade it.

import { Prisma, PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function seed() {
  await prisma.account.deleteMany();
  await prisma.account.createMany({
    data: [
      { owner: "Alice", balance: 100 },
      { owner: "Bob", balance: 50 },
    ],
  });
}

async function main() {
  await seed();
  console.log("--- starting balances ---");
  console.log(await prisma.account.findMany());

  // 1. Transfer 20 from Bob -> Alice using the ARRAY form of $transaction.
  console.log("--- ex1: array-form transfer (Bob -> Alice, 20) ---");
  await prisma.$transaction([
    // TODO: updateMany to decrement Bob by 20
    // TODO: updateMany to increment Alice by 20
  ]);
  console.log(await prisma.account.findMany());

  // 2. Transfer 10 Alice -> Bob using the CALLBACK form.
  console.log("--- ex2: callback-form transfer (Alice -> Bob, 10) ---");
  await prisma.$transaction(async (tx) => {
    // TODO: decrement Alice by 10, increment Bob by 10 (two tx.account.updateMany calls)
  });
  console.log(await prisma.account.findMany());

  // 3. Demonstrate ROLLBACK: inside a callback, move 40 Alice -> Bob, then
  //    throw on the next line. Balances afterward should be UNCHANGED.
  console.log("--- ex3: rollback on throw ---");
  try {
    await prisma.$transaction(async (tx) => {
      // TODO: do the two updates here...
      // TODO: ...then `throw new Error("boom")` to force the rollback
    });
  } catch (e) {
    console.log("rolled back:", (e as Error).message);
  }
  console.log(await prisma.account.findMany());

  // 4. Guarded transfer that REFUSES to let an account go negative.
  //    Test it by trying to move 200 from Bob (he only has 50) -> should reject.
  console.log("--- ex4: guarded transfer, should reject ---");
  try {
    await prisma.$transaction(async (tx) => {
      const bob = await tx.account.findFirstOrThrow({ where: { owner: "Bob" } });
      const next = bob.balance - 200;
      // TODO: if `next` < 0, throw an Error explaining why
      // TODO: otherwise update Bob to `next` and credit Alice by 200
    });
  } catch (e) {
    console.log("rejected:", (e as Error).message);
  }
  console.log(await prisma.account.findMany());

  // 5. Same guard, but a transfer that SUCCEEDS: move 30 Alice -> Bob.
  console.log("--- ex5: guarded transfer, should succeed ---");
  await prisma.$transaction(async (tx) => {
    const alice = await tx.account.findFirstOrThrow({ where: { owner: "Alice" } });
    const next = alice.balance - 30;
    if (next < 0) throw new Error("insufficient funds");
    // TODO: update Alice to `next`, and increment Bob by 30
  });
  console.log(await prisma.account.findMany());

  // 6. Set an ISOLATION LEVEL on a transaction (Postgres-only knob).
  //    With one client it just passes — the point is wiring it up.
  console.log("--- ex6: transaction with isolation level ---");
  await prisma.$transaction(
    async (tx) => {
      await tx.account.findMany();
    },
    {
      // TODO: set isolationLevel to Serializable
      // (use Prisma.TransactionIsolationLevel.* — already imported above)
    },
  );
  console.log("isolation-level transaction committed");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
