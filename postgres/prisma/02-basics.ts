// 02-basics.ts
// Mirrors ../basics/02-basics.sql: CRUD against the User model.
// Run with:  npx tsx 02-basics.ts
// (Requires `npx prisma migrate dev` to have been run at least once.)

import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  // Re-runnable: clear the table so inserts never collide on `email UNIQUE`.
  await prisma.user.deleteMany();

  // createMany = bulk INSERT. SQLite doesn't return the created rows from
  // createMany, so we read them back afterwards.
  await prisma.user.createMany({
    data: [
      { name: "Alice", email: "alice@example.com", age: 30 },
      { name: "Bob", email: "bob@example.com", age: 25 },
      { name: "Charlie", email: "charlie@example.com", age: 35 },
      { name: "Diana", email: "diana@example.com", age: 28 },
    ],
  });

  console.log("--- all users ---");
  console.log(await prisma.user.findMany());

  // WHERE + ORDER BY equivalent. Prisma's operators: gt, gte, lt, lte, in, not, contains...
  console.log("--- users older than 27, newest first ---");
  console.log(
    await prisma.user.findMany({
      where: { age: { gt: 27 } },
      orderBy: { age: "desc" },
      select: { name: true, age: true }, // like SELECT name, age
    }),
  );

  // UPDATE. `update` targets a single row by a unique field; `updateMany`
  // for criteria-based updates.
  await prisma.user.update({
    where: { email: "alice@example.com" },
    data: { age: 31 },
  });

  // DELETE. Same split: `delete` for a unique row, `deleteMany` for criteria.
  await prisma.user.delete({ where: { email: "bob@example.com" } });

  console.log("--- after update and delete ---");
  console.log(await prisma.user.findMany());
}

// Always disconnect — the process hangs otherwise.
main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
