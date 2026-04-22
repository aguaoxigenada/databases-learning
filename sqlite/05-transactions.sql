-- 05-transactions.sql
-- Goal: see why transactions matter. A transaction is "all or nothing".
-- Run with:  sqlite3 learn.db < 05-transactions.sql

DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts (
    id      INTEGER PRIMARY KEY,
    owner   TEXT    NOT NULL,
    balance INTEGER NOT NULL CHECK (balance >= 0)  -- can't go negative
);

INSERT INTO accounts (owner, balance) VALUES
    ('Alice', 100),
    ('Bob',   50);

SELECT '--- starting balances ---' AS section;
SELECT * FROM accounts;

-- A successful transfer: wrap both updates so they either both apply or neither does.
BEGIN TRANSACTION;
    UPDATE accounts SET balance = balance - 30 WHERE owner = 'Alice';
    UPDATE accounts SET balance = balance + 30 WHERE owner = 'Bob';
COMMIT;

SELECT '--- after successful transfer ---' AS section;
SELECT * FROM accounts;

-- A failed transfer. Alice has 70 after the first transfer, so subtracting 200
-- would make her -130 and violate CHECK (balance >= 0). The UPDATE errors out
-- (you'll see "Runtime error: CHECK constraint failed" printed) and SQLite
-- rolls back just that statement. The transaction is still open, so we
-- ROLLBACK explicitly to close it and discard any partial work.
-- Moral: in a real transfer you'd pair BOTH updates inside one transaction,
-- so if the credit fails the debit gets undone too — money never vanishes.
BEGIN TRANSACTION;
    UPDATE accounts SET balance = balance - 200 WHERE owner = 'Alice';
ROLLBACK;

SELECT '--- after rolled-back transfer (unchanged) ---' AS section;
SELECT * FROM accounts;
