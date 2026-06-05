// 04-queries.exercises.ts — fill-in-the-blank practice for 04-queries.ts
//
// HOW THIS WORKS:
//   - Scaffolding done; you fill the `// TODO:`s.
//   - Run any time:  npx tsx 04-queries.exercises.ts
//   - This file SEEDS its own books (so you don't need to run 03 first).
//
// Seed:
//   Ursula K. Le Guin — A Wizard of Earthsea (1968), The Dispossessed (1974)
//   Ted Chiang        — Stories of Your Life (2002), Exhalation (2019)
//   N. K. Jemisin     — The Fifth Season (2015)
//
// Paste this file back when done and I'll grade it.

import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function seed() {
  await prisma.book.deleteMany();
  await prisma.author.deleteMany();
  await prisma.author.create({
    data: {
      name: "Ursula K. Le Guin",
      books: {
        create: [
          { title: "A Wizard of Earthsea", year: 1968 },
          { title: "The Dispossessed", year: 1974 },
        ],
      },
    },
  });
  await prisma.author.create({
    data: {
      name: "Ted Chiang",
      books: {
        create: [
          { title: "Stories of Your Life", year: 2002 },
          { title: "Exhalation", year: 2019 },
        ],
      },
    },
  });
  await prisma.author.create({
    data: {
      name: "N. K. Jemisin",
      books: { create: [{ title: "The Fifth Season", year: 2015 }] },
    },
  });
}

async function main() {
  await seed();

  // 1. Books published between 2000 and 2020 inclusive, oldest first,
  //    title + year only.
  console.log("--- ex1: 2000..2020 ---");
  console.log(
    await prisma.book.findMany({
      // TODO: where year gte 2000 AND lte 2020; orderBy year asc; select title+year
    }),
  );

  // 2. Books published before 1970 OR after 2015 (one query).
  console.log("--- ex2: <1970 or >2015 ---");
  console.log(
    await prisma.book.findMany({
      // TODO: where: { OR: [ ... , ... ] }
    }),
  );

  // 3. Books whose title STARTS WITH "The".
  console.log("--- ex3: starts with 'The' ---");
  console.log(
    await prisma.book.findMany({
      // TODO: where title startsWith "The"
    }),
  );

  // 4. One aggregate call: count, earliest year, latest year, average year.
  console.log("--- ex4: aggregates ---");
  console.log(
    await prisma.book.aggregate({
      // TODO: _count, _min(year), _max(year), _avg(year)
    }),
  );

  // 5. Group books by authorId -> count, then map IDs to author names.
  console.log("--- ex5: per-author counts (with names) ---");
  const grouped = await prisma.book.groupBy({
    by: ["authorId"],
    // TODO: add _count: { _all: true }
  });
  const authorIds = grouped.map((g) => g.authorId);
  const authors = await prisma.author.findMany({
    where: { id: { in: authorIds } },
  });
  const nameById = new Map(authors.map((a) => [a.id, a.name]));
  for (const g of grouped) {
    // (works once your _count is in place)
    console.log(`${nameById.get(g.authorId)}: ${(g as any)._count?._all}`);
  }

  // 6. Authors with 2 OR MORE books (groupBy + having).
  console.log("--- ex6: authors with >= 2 books ---");
  console.log(
    await prisma.book.groupBy({
      by: ["authorId"],
      _count: { _all: true },
      // TODO: add a `having` that keeps groups with count >= 2
    }),
  );

  // 7. The 2 OLDEST books (title + year).
  console.log("--- ex7: 2 oldest ---");
  console.log(
    await prisma.book.findMany({
      // TODO: orderBy year asc, take 2, select title+year
    }),
  );

  // 8. "Page 2" when page size is 2, ordered by year ascending.
  console.log("--- ex8: page 2 (size 2) ---");
  console.log(
    await prisma.book.findMany({
      orderBy: { year: "asc" },
      // TODO: skip + take to land on the 3rd and 4th rows
    }),
  );

  // 9. THE POSTGRES GOTCHA: case-sensitive LIKE.
  //    Run as-is first and look at the (empty?) result before fixing ex10.
  console.log("--- ex9: contains 'the' (case-sensitive on PG) ---");
  console.log(
    await prisma.book.findMany({
      where: { title: { contains: "the" } },
      select: { title: true },
    }),
  );

  // 10. Make ex9 case-INSENSITIVE so it matches "The Dispossessed" etc.
  console.log("--- ex10: contains 'the' (case-insensitive) ---");
  console.log(
    await prisma.book.findMany({
      where: {
        title: { contains: "the" /* TODO: add the option that ignores case */ },
      },
      select: { title: true },
    }),
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
