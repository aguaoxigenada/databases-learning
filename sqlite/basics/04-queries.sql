-- 04-queries.sql
-- Goal: go beyond SELECT *. Filter, aggregate, group, and combine.
-- Assumes 03-relationships.sql has been run (it needs the authors/books tables).
-- Run with:  sqlite3 learn.db < 04-queries.sql

PRAGMA foreign_keys = ON;

-- WHERE with multiple conditions.
SELECT '--- books between 1970 and 2010 ---' AS section;
SELECT title, year
FROM books
WHERE year BETWEEN 1970 AND 2010
ORDER BY year;

-- LIKE for text pattern matching. % = any number of chars, _ = one char.
SELECT '--- titles containing "the" (case-insensitive) ---' AS section;
SELECT title FROM books WHERE title LIKE '%the%';

-- Aggregate functions: COUNT, SUM, AVG, MIN, MAX.
SELECT '--- total books, oldest, newest, average year ---' AS section;
SELECT COUNT(*)  AS total_books,
       MIN(year) AS oldest,
       MAX(year) AS newest,
       AVG(year) AS avg_year
FROM books;

-- GROUP BY collapses rows that share a value.
-- HAVING filters AFTER aggregation (WHERE filters BEFORE).
SELECT '--- authors with more than one book ---' AS section;
SELECT a.name, COUNT(b.id) AS n
FROM authors AS a
JOIN books AS b ON b.author_id = a.id
GROUP BY a.id
HAVING n > 1;

-- Subquery: use one query's result inside another.
SELECT '--- books by the most prolific author ---' AS section;
SELECT title, year
FROM books
WHERE author_id = (
    SELECT author_id
    FROM books
    GROUP BY author_id
    ORDER BY COUNT(*) DESC
    LIMIT 1
);

-- LIMIT / OFFSET for pagination.
SELECT '--- 2 newest books ---' AS section;
SELECT title, year FROM books ORDER BY year DESC LIMIT 2;
