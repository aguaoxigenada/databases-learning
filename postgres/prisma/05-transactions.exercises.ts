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
    prisma.account.updateMany({
      where: { owner: "Bob" },
      data: { balance: { decrement: 20 } },
    }),
    prisma.account.updateMany({
      where: { owner: "Alice" },
      data: { balance: { increment: 20 } },
    }),
  ]);
  console.log(await prisma.account.findMany());

  // 2. Transfer 10 Alice -> Bob using the CALLBACK form.
  console.log("--- ex2: callback-form transfer (Alice -> Bob, 10) ---");
  await prisma.$transaction(async (tx) => {
    await tx.account.updateMany({
      where: { owner: "Alice" },
      data: { balance: { decrement: 10 } },
    });
    await tx.account.updateMany({
      where: { owner: "Bob" },
      data: { balance: { increment: 10 } },
    });
  });

  console.log(await prisma.account.findMany());

  // 3. Demonstrate ROLLBACK: inside a callback, move 40 Alice -> Bob, then
  //    throw on the next line. Balances afterward should be UNCHANGED.
  console.log("--- ex3: rollback on throw ---");
  try {
    await prisma.$transaction(async (tx) => {
      await tx.account.updateMany({
        where: { owner: "Alice" },
        data: { balance: { decrement: 10 } },
      });
      await tx.account.updateMany({
        where: { owner: "Bob" },
        data: { balance: { increment: 10 } },
      });
      throw new Error("Boom");
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
      const bob = await tx.account.findFirstOrThrow({
        where: { owner: "Bob" },
      });
      const next = bob.balance - 200;

      if (next < 0) {
        throw new Error(
          `Refusing transfer: Bob would go to ${next} (must stay >= 0)`,
        );
      }

      await tx.account.update({
        where: { id: bob.id },
        data: { balance: next },
      });
      await tx.account.updateMany({
        where: { owner: "Alice" },
        data: { balance: { decrement: 200 } },
      });
    });
  } catch (e) {
    console.log("rejected:", (e as Error).message);
  }
  console.log(await prisma.account.findMany());

  // 5. Same guard, but a transfer that SUCCEEDS: move 30 Alice -> Bob.
  console.log("--- ex5: guarded transfer, should succeed ---");
  await prisma.$transaction(async (tx) => {
    const alice = await tx.account.findFirstOrThrow({
      where: { owner: "Alice" },
    });
    const next = alice.balance - 30;
    if (next < 0) throw new Error("insufficient funds");

    await tx.account.updateMany({
      where: { owner: "Alice" },
      data: { balance: next },
    });
    await tx.account.updateMany({
      where: { owner: "Bob" },
      data: { balance: { increment: 30 } },
    });
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
      isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
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
