-- 02-basics.sql (Postgres)
-- Port of ../../sqlite/basics/02-basics.sql.
-- Run with:  docker exec -i pg-learn psql -U postgres -d learn_pg < 02-basics.sql

-- Re-runnable from scratch.
DROP TABLE IF EXISTS users;

-- Differences from the SQLite version:
--   - `GENERATED ALWAYS AS IDENTITY` replaces SQLite's magic `INTEGER PRIMARY KEY`.
--   - `TIMESTAMPTZ` + `NOW()` replaces `TEXT DEFAULT CURRENT_TIMESTAMP`. Real type, real timezone.
--   - Postgres is strict about types — `age INTEGER` rejects `'thirty'`.
CREATE TABLE users (
    id         INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       TEXT        NOT NULL,
    email      TEXT        NOT NULL UNIQUE,
    age        INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO users (name, email, age) VALUES
    ('Alice',   'alice@example.com',   30),
    ('Bob',     'bob@example.com',     25),
    ('Charlie', 'charlie@example.com', 35),
    ('Diana',   'diana@example.com',   28);

\echo '--- all users ---'
SELECT * FROM users;

\echo '--- users older than 27, newest first ---'
SELECT name, age
FROM users
WHERE age > 27
ORDER BY age DESC;

UPDATE users SET age = 31 WHERE name = 'Alice';
DELETE FROM users WHERE name = 'Bob';

\echo '--- after update and delete ---'
SELECT * FROM users;

-- Note: `\echo` is a psql meta-command for printing a plain line.
-- SQLite's trick of `SELECT '--- ... ---' AS section;` works in Postgres too,
-- but `\echo` is cleaner when you know you're in psql.
