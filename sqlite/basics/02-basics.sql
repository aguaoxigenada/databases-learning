-- 02-basics.sql
-- Goal: create your first table, put some rows in it, and read them.
-- Run with:  sqlite3 learn.db < 02-basics.sql
-- Try running it with formatting flags to see the difference:                                                    
-- sqlite3 -header -column learn.db < 02-basics.sql    

-- Start clean so the script is re-runnable.
DROP TABLE IF EXISTS users;

-- CREATE TABLE defines the schema: the table name, its columns, and their types.
-- INTEGER PRIMARY KEY auto-increments in SQLite; it's how every row gets a unique id.
CREATE TABLE users (
    id         INTEGER PRIMARY KEY,
    name       TEXT    NOT NULL,
    email      TEXT    NOT NULL UNIQUE,
    age        INTEGER,
    created_at TEXT    DEFAULT CURRENT_TIMESTAMP
);

-- INSERT adds rows. We can omit `id` — SQLite assigns one.
INSERT INTO users (name, email, age) VALUES
    ('Alice',   'alice@example.com',   30),
    ('Bob',     'bob@example.com',     25),
    ('Charlie', 'charlie@example.com', 35),
    ('Diana',   'diana@example.com',   28);

-- SELECT reads rows.
SELECT '--- all users ---' AS section;
SELECT * FROM users;  -- * means every column.

-- Pick specific columns, filter with WHERE, sort with ORDER BY.
SELECT '--- users older than 27, newest first ---' AS section;
SELECT name, age
FROM users
WHERE age > 27
ORDER BY age DESC;

-- UPDATE changes existing rows. Always use WHERE or you'll change every row!
UPDATE users SET age = 31 WHERE name = 'Alice';

-- DELETE removes rows. Same warning.
DELETE FROM users WHERE name = 'Bob';

SELECT '--- after update and delete ---' AS section;
SELECT * FROM users;
