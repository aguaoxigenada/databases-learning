// 03-relationships.exercises.ts — fill-in-the-blank practice for 03-relationships.ts
//
// HOW THIS WORKS:
//   - Scaffolding (seed, labels, call shapes) is done; you fill the `// TODO:`s.
//   - Run any time:  npx tsx 03-relationships.exercises.ts
//   - Re-seeds every run.
//
// Seed:
//   Ursula K. Le Guin — A Wizard of Earthsea (1968), The Dispossessed (1974)
//   Ted Chiang        — Stories of Your Life (2002), Exhalation (2019)
//   N. K. Jemisin     — The Fifth Season (2015)
//   Unpublished Author — (no books)
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
  await prisma.author.create({ data: { name: "Unpublished Author" } });
}

async function main() {
  await seed();

  // 1. Every book with its author's name, sorted by TITLE (A->Z).
  console.log("--- ex1: books + author, by title ---");
  const books = await prisma.book.findMany({
    // TODO: include the author, and orderBy title ascending
  });
  for (const b of books) {
    // (this line works once your `include` is in place)
    console.log(`${b.title} — ${(b as any).author?.name}`);
  }

  // 2. Fetch ONE author (Ted Chiang) with all of their books included.
  console.log("--- ex2: Ted Chiang + books ---");
  console.log(
    await prisma.author.findFirst({
      where: { name: "Ted Chiang" },
      // TODO: include his books
    }),
  );

  // 3. All books published AFTER 2000, with their author included.
  console.log("--- ex3: post-2000 books + author ---");
  console.log(
    await prisma.book.findMany({
      // TODO: where year > 2000, and include the author
    }),
  );

  // 4. Every author with their book count, but ONLY authors with >= 1 book.
  console.log("--- ex4: authors with at least one book ---");
  const authors = await prisma.author.findMany({
    // TODO: where they have `some` books; include `_count` of books
  });
  for (const a of authors) {
    console.log(`${a.name}: ${(a as any)._count?.books}`);
  }

  // 5. Add a new book to Ursula K. Le Guin by setting authorId directly.
  console.log("--- ex5: add a book via authorId ---");
  const leguin = await prisma.author.findFirstOrThrow({
    where: { name: "Ursula K. Le Guin" },
  });
  // TODO: prisma.book.create(...) with title, year, and authorId: leguin.id

  // 6. Same idea, the OTHER way: update the author with a nested book create.
  console.log("--- ex6: add a book via nested write ---");
  // TODO: prisma.author.update({ where: { id: leguin.id }, data: { books: { create: ... } } })

  console.log(
    await prisma.author.findUnique({
      where: { id: leguin.id },
      include: { books: true },
    }),
  );

  // 7. Delete Ted Chiang AND his books — in the order that satisfies the FK.
  console.log("--- ex7: delete Ted Chiang safely ---");
  const chiang = await prisma.author.findFirstOrThrow({
    where: { name: "Ted Chiang" },
  });
  // TODO: delete his books first, then the author (two calls)

  // 8. Find authors with NO books at all.
  console.log("--- ex8: authors with zero books ---");
  console.log(
    await prisma.author.findMany({
      // TODO: where books `none` match
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
