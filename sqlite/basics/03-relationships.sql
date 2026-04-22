-- 03-relationships.sql
-- Goal: model a one-to-many relationship (one author, many books) and query it with JOINs.
-- Run with:  sqlite3 learn.db < 03-relationships.sql

-- SQLite doesn't enforce foreign keys unless you turn them on. Do it every session.
PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS books;
DROP TABLE IF EXISTS authors;

CREATE TABLE authors (
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE books (
    id        INTEGER PRIMARY KEY,
    title     TEXT NOT NULL,
    year      INTEGER,
    author_id INTEGER NOT NULL,
    -- This is the foreign key: books.author_id must match some authors.id.
    FOREIGN KEY (author_id) REFERENCES authors(id)
);

INSERT INTO authors (id, name) VALUES
    (1, 'Ursula K. Le Guin'),
    (2, 'Ted Chiang'),
    (3, 'N. K. Jemisin');

INSERT INTO books (title, year, author_id) VALUES
    ('A Wizard of Earthsea',    1968, 1),
    ('The Dispossessed',        1974, 1),
    ('Stories of Your Life',    2002, 2),
    ('Exhalation',              2019, 2),
    ('The Fifth Season',        2015, 3);

-- INNER JOIN returns only rows that match in both tables.
SELECT '--- books with their authors (INNER JOIN) ---' AS section;
SELECT b.title, b.year, a.name AS author
FROM books AS b
INNER JOIN authors AS a ON a.id = b.author_id
ORDER BY b.year;

-- Add an author with no books to demonstrate LEFT JOIN.
INSERT INTO authors (id, name) VALUES (4, 'Unpublished Author');

-- LEFT JOIN keeps every row from the left table even when there's no match.
-- Here it shows every author, including the one with zero books.
SELECT '--- every author, with book count (LEFT JOIN + GROUP BY) ---' AS section;
SELECT a.name, COUNT(b.id) AS book_count
FROM authors AS a
LEFT JOIN books AS b ON b.author_id = a.id
GROUP BY a.id
ORDER BY book_count DESC;

-- Foreign keys protect integrity. This would fail because author_id 999 doesn't exist:
-- INSERT INTO books (title, year, author_id) VALUES ('Orphan', 2024, 999);
