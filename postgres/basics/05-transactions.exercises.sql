-- 05-transactions.exercises.sql — fill-in-the-blank practice for 05-transactions.sql
--
-- HOW THIS WORKS:
--   - The accounts table (with a CHECK balance >= 0) is set up below.
--   - Each exercise is a skeleton with a  /* TODO */  blank.
--   - Run any time:
--       docker exec -i pg-learn psql -U postgres -d learn_pg < 05-transactions.exercises.sql
--   - Rebuilds every run. Seed balances: Alice 100, Bob 50.
--
-- Paste this file back when done and I'll grade it.

DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts (
    id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner   TEXT    NOT NULL,
    balance INTEGER NOT NULL CHECK (balance >= 0)
);

INSERT INTO accounts (owner, balance) VALUES
    ('Alice', 100),
    ('Bob',   50);

\echo '--- starting balances ---'
SELECT * FROM accounts;


\echo '--- ex1: transfer 20 from Alice to Bob, atomically ---'
BEGIN;
    UPDATE accounts SET balance = balance - 20 WHERE owner = 'Alice';
    UPDATE accounts SET balance = balance + 20 WHERE owner = 'Bob';
COMMIT;
SELECT * FROM accounts;


\echo '--- ex2: a transfer that VIOLATES the CHECK, then rolls back ---'
--       The CHECK rejects it and aborts the transaction; ROLLBACK ends it.
BEGIN;
    UPDATE accounts SET balance = balance + 200 WHERE owner = 'Bob';
ROLLBACK;

\echo '   (balances should be unchanged below)'
SELECT * FROM accounts;


\echo '--- ex3: SAVEPOINT-based partial recovery ---'
-- Goal: apply a -10 to Alice, ATTEMPT a bad update, undo only the bad update
-- with ROLLBACK TO SAVEPOINT, then still commit the good -10 and a +10 to Bob.
BEGIN;
    UPDATE accounts SET balance = balance - 10 WHERE owner = 'Alice';
    SAVEPOINT before_risky;
    UPDATE accounts SET balance = balance - 999 WHERE owner = 'Alice';
    ROLLBACK TO SAVEPOINT before_risky;
    UPDATE accounts SET balance = balance + 10 WHERE owner = 'Bob';
COMMIT;
SELECT * FROM accounts;


\echo '--- ex4 (observe, no blank): the "aborted transaction" rule ---'
-- Run this block and read the output. After the failing statement, the second
-- UPDATE is IGNORED ("current transaction is aborted") until the transaction
-- ends. This is the key Postgres behaviour from the lesson.
BEGIN;
    UPDATE accounts SET balance = balance - 9999 WHERE owner = 'Alice';  -- fails CHECK
    UPDATE accounts SET balance = balance + 1     WHERE owner = 'Bob';   -- ignored
ROLLBACK;
\echo '   (Bob unchanged — the +1 never applied)'
SELECT * FROM accounts;
