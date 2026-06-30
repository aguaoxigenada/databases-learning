-- 02-basics.exercises.sql — fill-in-the-blank practice for 02-basics.sql
--
-- HOW THIS WORKS:
--   - The setup (table + seed rows) below is complete and runs as-is.
--   - Each exercise is a skeleton with a  /* TODO */  blank you complete.
--   - Run any time:
--       docker exec -i pg-learn psql -U postgres -d learn_pg < 02-basics.exercises.sql
--   - It rebuilds the table every run, so iterate freely. Until you fill a
--     blank, that query may return everything (or error) — that's expected.
--
-- Paste this file back when done and I'll grade it.

DROP TABLE IF EXISTS users;

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


\echo '--- ex1: every user, ONLY name and email ---'
SELECT name, email
FROM users;


\echo '--- ex2: just the user whose email is diana@example.com ---'
SELECT * FROM users
WHERE email = 'diana@example.com';

\echo '--- ex3: how many users are there? ---'
SELECT COUNT(*) FROM users;



\echo '--- ex4: users aged 28 or older, youngest first ---'
-- TODO: add WHERE (age >= 28) and ORDER BY (age ascending)
SELECT name, age FROM users
WHERE age >= 28
ORDER BY age ASC;

\echo '--- ex5: users whose age is NOT 35 ---'
SELECT name, age FROM users
WHERE age != 35;


\echo '--- ex6: the users named Alice or Charlie (one query) ---'
SELECT name FROM users
WHERE name = 'Alice' OR name = 'Charlie';  


\echo '--- ex7: insert a new user with NO age, then list everyone ---'
INSERT INTO users (name, email) VALUES ('James', 'hey@atamail.com');
SELECT name, age FROM users ORDER BY id;


\echo '--- ex8: give EVERY user one extra year of age ---'
UPDATE users SET age = age + 1;
SELECT name, age FROM users ORDER BY id;


\echo '--- ex9: try to insert a SECOND diana@example.com (should fail) ---'
INSERT INTO users (name, email) VALUES ('Bank', 'diana@example.com');

