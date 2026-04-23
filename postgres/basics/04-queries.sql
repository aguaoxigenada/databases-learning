-- 04-queries.sql (Postgres)
-- Port of ../../sqlite/basics/04-queries.sql.
-- Assumes 03-relationships.sql has been run (needs authors/books).
-- Run with:  docker exec -i pg-learn psql -U postgres -d learn_pg < 04-queries.sql

\echo '--- books between 1970 and 2010 ---'
SELECT title, year
FROM books
WHERE year BETWEEN 1970 AND 2010
ORDER BY year;

-- ** KEY DIFFERENCE FROM SQLITE **
-- `LIKE` in Postgres is case-SENSITIVE. 'The Dispossessed' matches '%the%'
-- in SQLite but NOT in Postgres. Use `ILIKE` for case-insensitive matching.
\echo '--- titles containing "the" (case-sensitive LIKE — misses "The...") ---'
SELECT title FROM books WHERE title LIKE '%the%';

\echo '--- titles containing "the" (case-insensitive ILIKE) ---'
SELECT title FROM books WHERE title ILIKE '%the%';

\echo '--- total books, oldest, newest, average year ---'
SELECT COUNT(*)          AS total_books,
       MIN(year)         AS oldest,
       MAX(year)         AS newest,
       ROUND(AVG(year))  AS avg_year
       -- In SQLite, AVG returned a float. In Postgres, AVG on an integer
       -- column returns NUMERIC (arbitrary precision). ROUND() gives a nice
       -- human-readable year.
FROM books;

\echo '--- authors with more than one book ---'
SELECT a.name, COUNT(b.id) AS n
FROM authors AS a
JOIN books AS b ON b.author_id = a.id
GROUP BY a.id, a.name
HAVING COUNT(b.id) > 1;
-- Note: `HAVING n > 1` works in SQLite but fails in strict Postgres.
-- Use the underlying expression. More portable, more explicit.

\echo '--- books by the most prolific author ---'
SELECT title, year
FROM books
WHERE author_id = (
    SELECT author_id
    FROM books
    GROUP BY author_id
    ORDER BY COUNT(*) DESC
    LIMIT 1
);

\echo '--- 2 newest books ---'
SELECT title, year FROM books ORDER BY year DESC LIMIT 2;
