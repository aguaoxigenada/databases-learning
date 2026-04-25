# Redis — concepts

You've been learning relational databases. Redis is a different *kind* of tool. The mental model you built for SQLite/Postgres doesn't fully apply here — some things are faster, many things are simpler, and a few things are impossible.

## What Redis is

A **single-process, in-memory, key-value data-structure server.** Unpacking that:

- **Single-process** — one Redis server handles everything in one thread. There's no concurrent-writer headache because there's only one writer: Redis. Every command is atomic.
- **In-memory** — all data lives in RAM. That's why it's fast (microseconds, not milliseconds). Disk is only used for persistence snapshots.
- **Key-value** — you look things up by a string key. No joins, no WHERE clauses, no ad-hoc queries across the dataset. If you want it back, you need to remember its key.
- **Data-structure server** — the "value" isn't just a blob. Redis understands several real data structures (strings, hashes, lists, sets, sorted sets, streams, bitmaps, hyperloglogs, geospatial indexes) and gives you operations on them.

## Shape vs SQL — worked example

You want to store a user session.

**SQL** (Postgres):
```sql
CREATE TABLE sessions (
    token      TEXT PRIMARY KEY,
    user_id    INTEGER NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL
);
INSERT INTO sessions VALUES ('abc123', 42, NOW() + INTERVAL '1 hour');
SELECT user_id FROM sessions WHERE token = 'abc123' AND expires_at > NOW();
```

**Redis:**
```
SET session:abc123 42 EX 3600
GET session:abc123
```

Same goal. Redis wins on simplicity *for this use case* because sessions are write-once-read-often-then-expire — an awkward fit for a relational table. The expiry is built in (`EX 3600` = 3600 seconds). No DELETE cron job, no index on `expires_at`.

But Redis can't answer "how many sessions does user 42 have right now?" without you having pre-designed that data structure yourself. SQL can, because you can query the table any way you like.

## The "key-naming convention"

Since you can't query by anything but the key, **how you name keys matters a lot**. The community convention uses `:` as a separator:

```
user:42                       → a hash of user 42's fields
user:42:session               → the session token for user 42
page:hits:2026-04-22          → a counter for today's page hits
leaderboard:global            → a sorted set of scores
```

Think of it as your "schema": keys organised hierarchically so you can reason about what exists.

## Where Redis shines

1. **Caching** — put an expensive query's result under a key with a TTL. Next request reads from Redis in microseconds. This is the single biggest reason Redis exists in a real app.
2. **Session storage** — fast, auto-expiring, shared across multiple web servers.
3. **Rate limiting** — `INCR` a counter, set TTL, reject if it exceeds the limit. Atomic and simple.
4. **Queues** — lightweight job queues via lists (`LPUSH` producer, `BRPOP` consumer).
5. **Leaderboards** — sorted sets make "top N by score" a one-command operation.
6. **Real-time signals** — pub/sub, streams.
7. **Atomic counters** — page hits, view counts, likes. `INCR` is atomic and fast.

## Where Redis does NOT fit

1. **Primary source of truth for critical data.** Default persistence is best-effort snapshots. You can configure it stricter, but you're still betting your business on something optimised for speed, not durability. Use Postgres as truth; use Redis as cache.
2. **Ad-hoc querying.** No SELECT. If you need to answer questions you haven't designed for, Redis will fight you.
3. **Anything that doesn't fit in RAM.** Redis holds *everything* in memory. Larger than RAM = you need a different tool (or sharding, which is its own headache).
4. **Complex multi-entity transactions.** Redis has transactions (`MULTI`/`EXEC`), but nothing like SQL's rollback semantics.

## Data types you'll meet

| Type | What it is | Real use |
|---|---|---|
| **String** | a key → string value (or integer, for counters) | cache values, session tokens, counters |
| **Hash** | a key → a small map of field→value pairs | "rows" (user profile, config) |
| **List** | an ordered list of values, push/pop at either end | queues, recent-N logs |
| **Set** | unordered collection of unique strings | tags, unique-visitor tracking |
| **Sorted set** | set where each member has a numeric score; auto-sorted | leaderboards, priority queues, time-ordered events |
| **Stream** | append-only log, consumer groups | event processing (Kafka-lite). Beyond this tutorial. |

## How you'll interact with Redis

- **`redis-cli`** — the command-line client. Simple commands like `SET mykey "hello"`. Every lesson script uses this.
- **Client libraries** — in a real app, you use a client library: `node-redis` or `ioredis` for TypeScript, `redis-py` for Python, etc. The commands and arguments are identical, just wrapped in method calls.

## Vocabulary from SQL → Redis

| SQL | Redis |
|---|---|
| Row | Usually a hash, keyed by some id |
| Table | A namespace convention in key names (`user:*`) |
| Primary key | The Redis key itself |
| Secondary index | You maintain it yourself (e.g. a set of ids by status) |
| `SELECT ... WHERE` | Either look up by key, or pre-built data structures; there is no "query" |
| `JOIN` | Multiple `GET`/`HGETALL` calls, often pipelined |
| `ORDER BY` | A sorted set |
| `COUNT(*)` | `DBSIZE`, or a counter you maintain |
| `TRUNCATE` | `FLUSHDB` |

Keep this table open as you read the next few scripts. A lot of "how do I do X in Redis?" is just looking up the right structure for the job.
