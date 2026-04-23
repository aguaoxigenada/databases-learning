-- 03-relationships.sql (Postgres)
-- Port of ../../sqlite/basics/03-relationships.sql.
-- Run with:  docker exec -i pg-learn psql -U postgres -d learn_pg < 03-relationships.sql

-- Differences from the SQLite version:
--   - No `PRAGMA foreign_keys = ON` — Postgres enforces FKs always.
--   - `GENERATED ALWAYS AS IDENTITY` instead of auto-magic `INTEGER PRIMARY KEY`.
--   - Nothing else changes.

-- Drop the child first because of the FK.
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
    -- `REFERENCES authors(id)` inline is shorthand for
    -- `FOREIGN KEY (author_id) REFERENCES authors(id)` — both work, this is tighter.
);

-- When you use GENERATED ALWAYS AS IDENTITY you normally can't override the id.
-- `OVERRIDING SYSTEM VALUE` lets us force specific ids for demo clarity so the
-- FK inserts below are easy to read.
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

\echo '--- books with their authors (INNER JOIN) ---'
SELECT b.title, b.year, a.name AS author
FROM books AS b
INNER JOIN authors AS a ON a.id = b.author_id
ORDER BY b.year;

-- Author with no books, to demonstrate LEFT JOIN.
INSERT INTO authors (id, name) OVERRIDING SYSTEM VALUE VALUES (4, 'Unpublished Author');

\echo '--- every author, with book count (LEFT JOIN + GROUP BY) ---'
SELECT a.name, COUNT(b.id) AS book_count
FROM authors AS a
LEFT JOIN books AS b ON b.author_id = a.id
GROUP BY a.id, a.name
ORDER BY book_count DESC;

-- Postgres quirk: GROUP BY must list EVERY non-aggregated column in the SELECT.
-- SQLite is loose about this; Postgres enforces the SQL standard.
-- That's why we `GROUP BY a.id, a.name` here, not just `a.id`.

-- Referential integrity demo — this would now fail hard because Postgres
-- enforces FKs unconditionally. Uncomment to see the error.
-- INSERT INTO books (title, year, author_id) VALUES ('Orphan', 2024, 999);

-- Because we inserted explicit ids, the identity sequence doesn't know the
-- real max yet. Fix it so future inserts without ids don't collide.
SELECT setval(pg_get_serial_sequence('authors', 'id'), (SELECT MAX(id) FROM authors));
