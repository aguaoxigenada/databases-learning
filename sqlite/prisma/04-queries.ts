// 04-queries.ts
// Mirrors ../basics/04-queries.sql: filters, aggregates, grouping, subqueries.
// Assumes 03-relationships.ts has been run (it needs authors + books).
// Run with:  npx tsx 04-queries.ts

import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  // WHERE with a range. Prisma's equivalent of BETWEEN.
  console.log("--- books between 1970 and 2010 ---");
  console.log(
    await prisma.book.findMany({
      where: { year: { gte: 1970, lte: 2010 } },
      orderBy: { year: "asc" },
      select: { title: true, year: true },
    }),
  );

  // LIKE '%the%'. Prisma uses `contains`. By default SQLite's LIKE is
  // case-insensitive for ASCII, which matches Prisma's behaviour here.
  console.log('--- titles containing "the" ---');
  console.log(
    await prisma.book.findMany({
      where: { title: { contains: "the" } },
      select: { title: true },
    }),
  );

  // Aggregates: COUNT / MIN / MAX / AVG / SUM.
  console.log("--- total books, oldest, newest, average year ---");
  const stats = await prisma.book.aggregate({
    _count: { _all: true },
    _min: { year: true },
    _max: { year: true },
    _avg: { year: true },
  });
  console.log(stats);

  // GROUP BY + HAVING. `groupBy` returns one row per distinct key, and you
  // can filter post-aggregation with `having`.
  console.log("--- authors with more than one book ---");
  const grouped = await prisma.book.groupBy({
    by: ["authorId"],
    _count: { _all: true },
    having: { authorId: { _count: { gt: 1 } } },
  });

  // groupBy returns IDs only. Fetch the author names and zip them together.
  const authorIds = grouped.map((g) => g.authorId);
  const authors = await prisma.author.findMany({
    where: { id: { in: authorIds } },
  });
  const nameById = new Map(authors.map((a) => [a.id, a.name]));
  for (const g of grouped) {
    console.log(`${nameById.get(g.authorId)}: ${g._count._all}`);
  }

  // "Subquery": books by whichever author has the most books.
  // Two queries here, same as the SQL version conceptually.
  console.log("--- books by the most prolific author ---");
  const top = await prisma.book.groupBy({
    by: ["authorId"],
    _count: { _all: true },
    orderBy: { _count: { authorId: "desc" } },
    take: 1,
  });
  if (top.length > 0) {
    console.log(
      await prisma.book.findMany({
        where: { authorId: top[0].authorId },
        select: { title: true, year: true },
      }),
    );
  }

  // LIMIT + ORDER BY = `take` + `orderBy`. OFFSET = `skip`.
  console.log("--- 2 newest books ---");
  console.log(
    await prisma.book.findMany({
      orderBy: { year: "desc" },
      take: 2,
      select: { title: true, year: true },
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
