// 02-basics.exercises.ts — fill-in-the-blank practice for 02-basics.ts
//
// HOW THIS WORKS:
//   - The scaffolding (seed data, labels, the shape of each call) is done.
//   - Each exercise has a `// TODO:` with the part you have to write.
//   - Run it any time:  npx tsx 02-basics.exercises.ts
//   - It re-seeds itself every run, so you can iterate freely.
//
// When you're done (or stuck), paste this file back and I'll grade it.

import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function seed() {
  await prisma.user.deleteMany();
  await prisma.user.createMany({
    data: [
      { name: "Alice", email: "alice@example.com", age: 30 },
      { name: "Bob", email: "bob@example.com", age: 25 },
      { name: "Charlie", email: "charlie@example.com", age: 35 },
      { name: "Diana", email: "diana@example.com", age: 28 },
    ],
  });
}

async function main() {
  await seed();

  // 1. Print every user, but ONLY their name and email.
  console.log("--- ex1: names + emails only ---");
  console.log(
    await prisma.user.findMany({
      select: { name: true, email: true },
      // like SELECT name, age      // TODO: add a `select` so only name and email come back
    }),
  );

  // 2. Fetch the single user whose email is diana@example.com.
  //    Use the method meant for one row by a unique field (not findMany).
  console.log("--- ex2: just Diana ---");
  console.log(
    await prisma.user.findUnique({
      where: { email: "diana@example.com" },
    }),
    // TODO: replace null with the right prisma.user.<method>({ where: ... })
  );

  // 3. Count the users without pulling back the rows.
  console.log("--- ex3: how many users? ---");
  console.log(
    await prisma.user.count(),
    // TODO: replace null with the prisma.user count call
  );

  // 4. All users aged 28 or older, youngest -> oldest.
  console.log("--- ex4: 28+ sorted youngest first ---");
  console.log(
    await prisma.user.findMany({
      where: { age: { gt: 28 } },
      orderBy: { age: "asc" },
      // TODO: add `where` (age >= 28) and `orderBy` (age ascending)
    }),
  );

  // 5. All users whose age is NOT 35.
  console.log("--- ex5: age != 35 ---");
  console.log(
    await prisma.user.findMany({
      where: { age: { not: 35 } },
      // TODO: add a `where` using the `not` operator
    }),
  );

  // 6. The users named "Alice" or "Charlie", in one query.
  console.log("--- ex6: Alice or Charlie ---");
  console.log(
    await prisma.user.findMany({
      where: {
        name: {
          in: ["Alice", "Charlie"],
        },
      },
    }),
  );

  // 7. Insert a new user with NO age set, then read it back.
  //    What does `age` come back as?
  console.log("--- ex7: user with no age ---");
  await prisma.user.create({
    data: { name: "NO AGE", email: "noage@example.com", age: null },
  });

  console.log(
    await prisma.user.findUnique({
      where: { email: "noage@example.com" },
    }),
  );

  console.log(await prisma.user.findMany());

  // 8. Give EVERY user one extra year of age in a single call.
  console.log("--- ex8: everyone +1 year ---");
  await prisma.user.updateMany({
    data: {
      age: {
        increment: 1,
      },
    },
  });

  console.log(
    await prisma.user.findMany({ select: { name: true, age: true } }),
  );

  // 9. Try to insert a SECOND user with email diana@example.com.
  //    Wrap it in try/catch and log which constraint blew up.
  console.log("--- ex9: duplicate email ---");
  try {
    await prisma.user.create({
      data: { name: "DUPLICATE", email: "diana@example.com", age: null },
    });
    // TODO: create a user with email "diana@example.com" again
  } catch (e) {
    console.log("blocked:", (e as Error).message);
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
