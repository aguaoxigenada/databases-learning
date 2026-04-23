// 05-transactions.ts
// Mirrors ../basics/05-transactions.sql: atomicity via $transaction.
// Run with:  npx tsx 05-transactions.ts

import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  await prisma.account.deleteMany();
  await prisma.account.createMany({
    data: [
      { owner: "Alice", balance: 100 },
      { owner: "Bob", balance: 50 },
    ],
  });

  console.log("--- starting balances ---");
  console.log(await prisma.account.findMany());

  // Successful transfer. The array form of $transaction runs a list of
  // queries atomically: either all commit or none do.
  // We use `updateMany` + `where: { owner }` because `owner` isn't a
  // unique column (so `update` wouldn't type-check).
  await prisma.$transaction([
    prisma.account.updateMany({
      where: { owner: "Alice" },
      data: { balance: { decrement: 30 } },
    }),
    prisma.account.updateMany({
      where: { owner: "Bob" },
      data: { balance: { increment: 30 } },
    }),
  ]);

  console.log("--- after successful transfer ---");
  console.log(await prisma.account.findMany());

  // Failed transfer. We use the *callback* form of $transaction here because
  // we need to throw mid-transaction to force a rollback. Prisma's schema
  // DSL has no CHECK constraint, so we enforce `balance >= 0` in code.
  try {
    await prisma.$transaction(async (tx) => {
      const alice = await tx.account.findFirstOrThrow({ where: { owner: "Alice" } });
      const nextBalance = alice.balance - 200;
      if (nextBalance < 0) {
        throw new Error(
          `Refusing transfer: Alice would go to ${nextBalance} (must stay >= 0)`,
        );
      }
      // This line never runs — but it's here to show the shape of the real call.
      await tx.account.update({
        where: { id: alice.id },
        data: { balance: nextBalance },
      });
    });
  } catch (e) {
    // Expected. Prisma has already rolled back anything the callback did.
    console.log(`--- transfer rejected: ${(e as Error).message} ---`);
  }

  console.log("--- after rolled-back transfer (unchanged) ---");
  console.log(await prisma.account.findMany());
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
