-- 03-relationships.exercises.sql — fill-in-the-blank practice for 03-relationships.sql
--
-- HOW THIS WORKS:
--   - Setup (authors + books, with a book-less author) is complete below.
--   - Each exercise is a skeleton with a  /* TODO */  blank.
--   - Run any time:
--       docker exec -i pg-learn psql -U postgres -d learn_pg < 03-relationships.exercises.sql
--   - Rebuilds every run. Unfilled blanks may return everything or error.
--
-- Seed:
--   1 Ursula K. Le Guin — A Wizard of Earthsea (1968), The Dispossessed (1974)
--   2 Ted Chiang        — Stories of Your Life (2002), Exhalation (2019)
--   3 N. K. Jemisin     — The Fifth Season (2015)
--   4 Unpublished Author — (no books)
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
    (3, 'N. K. Jemisin'),
    (4, 'Unpublished Author');

INSERT INTO books (title, year, author_id) VALUES
    ('A Wizard of Earthsea',    1968, 1),
    ('The Dispossessed',        1974, 1),
    ('Stories of Your Life',    2002, 2),
    ('Exhalation',              2019, 2),
    ('The Fifth Season',        2015, 3);

-- Keep the identity sequence in sync after the explicit ids above.
SELECT setval(pg_get_serial_sequence('authors', 'id'), (SELECT MAX(id) FROM authors));


\echo '--- ex1: every book with its author name, sorted by TITLE (A->Z) ---'
-- TODO: INNER JOIN books to authors on author_id = authors.id, ORDER BY title
SELECT b.title, b.year, a.name AS author
FROM books AS b
INNER JOIN authors AS a ON a.id = b.author_id
ORDER BY b.title;



\echo '--- ex2: all of Ted Chiang''s books ---'
SELECT a.name, b.title AS book
FROM authors AS a
LEFT JOIN books AS b ON b.author_id = a.id
WHERE a.name = 'Ted Chiang'
ORDER BY b.title;



\echo '--- ex3: books published AFTER 2000, with author name ---'
SELECT b.title, b.year, a.name AS author
FROM books AS b
INNER JOIN authors AS a ON a.id = b.author_id
WHERE b.year > 2000;


\echo '--- ex4: every author with their book count, only those with >= 1 book ---'
--       (an INNER JOIN naturally drops the book-less author)
SELECT a.name, COUNT(b.id) AS book_count
FROM authors AS a
INNER JOIN books AS b ON b.author_id = a.id
GROUP BY a.id, a.name
HAVING COUNT(b.id) >= 1;


\echo '--- ex5: add a new book for Ursula K. Le Guin (author_id 1) ---'
INSERT INTO books (title, year, author_id) VALUES ('Greg the Great', '2010', 1);
SELECT title, year, author_id FROM books WHERE author_id = 1;


\echo '--- ex6: delete Ted Chiang AND his books, in FK-safe order ---'
-- TODO: two DELETEs. Which table must go first, and why?
--   1) DELETE the books where author_id = 2
--   2) DELETE the author with id = 2

DELETE FROM books WHERE author_id = '2';
DELETE FROM authors WHERE id = '2';
SELECT name FROM authors ORDER BY id;


\echo '--- ex7: authors with NO books at all ---'
-- TODO: LEFT JOIN authors->books and keep rows where the book side IS NULL
SELECT a.name, b.title AS titles
FROM authors AS a
LEFT JOIN books AS b ON b.author_id = a.id;
