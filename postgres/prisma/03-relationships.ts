// 03-relationships.ts
// Mirrors ../basics/03-relationships.sql: one-to-many Author -> Books, with JOINs.
// Run with:  npx tsx 03-relationships.ts

import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  // Reset both tables. Delete the child first (books) because of the FK.
  await prisma.book.deleteMany();
  await prisma.author.deleteMany();

  // "Nested write": creating an Author and their Books in a single call.
  // Prisma figures out the foreign keys for you.
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

  // "INNER JOIN" equivalent: pull books, include their author.
  // This is what `include` does — an extra query under the hood, flattened
  // into a nested object in the result.
  console.log("--- books with their authors ---");
  const books = await prisma.book.findMany({
    include: { author: true },
    orderBy: { year: "asc" },
  });
  for (const b of books) {
    console.log(`${b.title} (${b.year}) — ${b.author.name}`);
  }

  // Add an author with no books, to mirror the LEFT JOIN demo.
  await prisma.author.create({ data: { name: "Unpublished Author" } });

  // "LEFT JOIN + GROUP BY + COUNT" equivalent: every author, with their
  // book count — including zeros. Prisma exposes this as `_count`.
  console.log("--- every author, with book count ---");
  const authors = await prisma.author.findMany({
    include: { _count: { select: { books: true } } },
    orderBy: { books: { _count: "desc" } },
  });
  for (const a of authors) {
    console.log(`${a.name}: ${a._count.books}`);
  }

  // Referential integrity: this would throw, because no Author has id 999.
  // Prisma validates FKs at the client level — you get a typed error before
  // the query ever reaches SQLite.
  //
  // await prisma.book.create({ data: { title: "Orphan", year: 2024, authorId: 999 } });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
