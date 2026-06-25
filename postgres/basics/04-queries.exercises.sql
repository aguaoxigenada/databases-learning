-- 04-queries.exercises.sql — fill-in-the-blank practice for 04-queries.sql
--
-- HOW THIS WORKS:
--   - This file SEEDS its own authors/books (so you don't need to run 03 first).
--   - Each exercise is a skeleton with a  /* TODO */  blank.
--   - Run any time:
--       docker exec -i pg-learn psql -U postgres -d learn_pg < 04-queries.exercises.sql
--   - Rebuilds every run. Unfilled blanks may return everything or error.
--
-- Paste this file back when done and I'll grade it.

DROP TABLE IF EXISTS books;
DROP TABLE IF EXISTS authors;

CREATE TABLE authors (
    id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL
);
CREATE TABLE books (
    id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title     TEXT NOT NULL,
    year      INTEGER,
    author_id INTEGER NOT NULL REFERENCES authors(id)
);

INSERT INTO authors (id, name) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Ursula K. Le Guin'),
    (2, 'Ted Chiang'),
    (3, 'N. K. Jemisin');
INSERT INTO books (title, year, author_id) VALUES
    ('A Wizard of Earthsea',    1968, 1),
    ('The Dispossessed',        1974, 1),
    ('Stories of Your Life',    2002, 2),
    ('Exhalation',              2019, 2),
    ('The Fifth Season',        2015, 3);
SELECT setval(pg_get_serial_sequence('authors', 'id'), (SELECT MAX(id) FROM authors));


\echo '--- ex1: books published between 2000 and 2020 inclusive, oldest first ---'
-- TODO: add WHERE year BETWEEN 2000 AND 2020, and ORDER BY year
SELECT title, year FROM books;


\echo '--- ex2: books published before 1970 OR after 2015 ---'
-- TODO: add a WHERE using OR (year < 1970 OR year > 2015)
SELECT title, year FROM books;


\echo '--- ex3: books whose title STARTS WITH "The" ---'
-- TODO: add WHERE title LIKE 'The%'
SELECT title FROM books;


\echo '--- ex4: count, oldest year, newest year, average year (rounded) ---'
-- TODO: replace the columns with COUNT(*), MIN(year), MAX(year), ROUND(AVG(year))
SELECT title FROM books;


\echo '--- ex5: per-author book counts, with author names ---'
-- TODO: JOIN authors->books, GROUP BY a.id, a.name, and COUNT the books
SELECT a.name
FROM authors AS a;


\echo '--- ex6: authors with 2 OR MORE books ---'
-- TODO: like ex5, but add HAVING COUNT(b.id) >= 2
SELECT a.name
FROM authors AS a;


\echo '--- ex7: the 2 OLDEST books ---'
-- TODO: ORDER BY year ascending, then LIMIT 2
SELECT title, year FROM books;


\echo '--- ex8: "page 2" when page size is 2, ordered by year ascending ---'
-- TODO: ORDER BY year, then LIMIT 2 OFFSET 2  (rows 3 and 4)
SELECT title, year FROM books;


\echo '--- ex9: titles containing "the" with case-SENSITIVE LIKE ---'
-- Run this as-is first. On Postgres, LIKE is case-sensitive: how many rows?
SELECT title FROM books WHERE title LIKE '%the%';


\echo '--- ex10: same search, now case-INSENSITIVE ---'
-- TODO: change LIKE to the case-insensitive operator so "The Dispossessed"
--       and "The Fifth Season" match
SELECT title FROM books WHERE title LIKE '%the%';
