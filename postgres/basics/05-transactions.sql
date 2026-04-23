-- 05-transactions.sql (Postgres)
-- Port of ../../sqlite/basics/05-transactions.sql — with an important behaviour
-- difference highlighted.
-- Run with:  docker exec -i pg-learn psql -U postgres -d learn_pg < 05-transactions.sql

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

-- Successful transfer — same as SQLite.
BEGIN;
    UPDATE accounts SET balance = balance - 30 WHERE owner = 'Alice';
    UPDATE accounts SET balance = balance + 30 WHERE owner = 'Bob';
COMMIT;

\echo '--- after successful transfer ---'
SELECT * FROM accounts;

-- ** KEY DIFFERENCE FROM SQLITE **
-- In Postgres, the moment a statement errors inside a transaction, the WHOLE
-- transaction is "aborted". Every subsequent statement returns:
--
--     ERROR: current transaction is aborted, commands ignored until
--            end of transaction block
--
-- You must ROLLBACK before you can do anything else. This is stricter than
-- SQLite (which does per-statement rollback) and — in practice — safer: it
-- prevents silently continuing after a half-done transaction.
--
-- Below: the CHECK constraint rejects the update; psql reports the error
-- and skips straight to ROLLBACK, which cleanly ends the transaction.
BEGIN;
    UPDATE accounts SET balance = balance - 200 WHERE owner = 'Alice';
    -- ^ ERROR: new row for relation "accounts" violates check constraint
ROLLBACK;

\echo '--- after rolled-back transfer (unchanged) ---'
SELECT * FROM accounts;

-- Bonus: SAVEPOINTs let you recover WITHOUT rolling back the whole thing.
-- Postgres only — SQLite has them too but you rarely see them used there.
BEGIN;
    UPDATE accounts SET balance = balance - 10 WHERE owner = 'Alice';

    SAVEPOINT before_risky;
        -- Try something that might fail. If it does, we roll back to the
        -- savepoint and carry on as if the risky bit never happened.
        UPDATE accounts SET balance = balance - 9999 WHERE owner = 'Alice';
        -- That errors and aborts the transaction... to this savepoint only.
    ROLLBACK TO SAVEPOINT before_risky;

    -- The -10 from before is still in effect; we can keep going.
    UPDATE accounts SET balance = balance + 10 WHERE owner = 'Bob';
COMMIT;

\echo '--- after savepoint-based partial recovery ---'
SELECT * FROM accounts;
