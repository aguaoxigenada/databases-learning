# Redis — Key-Value Store

Parallel to `../../sqlite/basics/`, but for a completely different kind of database. Redis isn't really a "database" in the relational sense — it's an in-memory data-structure server that you talk to over TCP. Think of it as a very fast, very shared `HashMap<String, Value>` with some benefits.

## Files

1. `01-concepts.md` — what Redis is, where it fits, when NOT to use it. Read first.
2. `02-strings-and-counters.sh` — `SET`/`GET`, TTLs, atomic counters, rate limiting.
3. `03-hashes-and-lists.sh` — structured records (hashes), queues (lists).
4. `04-sets-and-sorted-sets.sh` — membership + dedup (sets), leaderboards (sorted sets).
5. `05-cache-patterns.sh` — the cache-aside pattern, stampedes, TTL strategy.

## Setup

A Redis 7 Docker container named `redis-learn` should already be running:

```bash
docker start redis-learn         # if it's stopped
docker ps | grep redis-learn     # verify
```

If the container doesn't exist yet:

```bash
docker run --name redis-learn -p 6379:6379 -d redis:7
```

Verify it answers:

```bash
docker exec redis-learn redis-cli PING      # -> PONG
```

## Running a lesson script

```bash
# from inside nosql/redis/
bash 02-strings-and-counters.sh
```

Each script wipes the keys it uses (`FLUSHDB` or targeted `DEL`) so re-runs are safe.

## Exploring interactively

Open the Redis CLI:

```bash
docker exec -it redis-learn redis-cli
```

Useful commands at the `127.0.0.1:6379>` prompt:

```
KEYS *             -- list all keys (OK for learning, NEVER in production)
SCAN 0             -- production-safe iteration
TYPE mykey         -- what data type is this key?
TTL mykey          -- seconds until this key expires (-1 = no expiry, -2 = gone)
FLUSHDB            -- nuke everything in the current database
QUIT               -- exit
```

## Reset

Wipe all data:

```bash
docker exec redis-learn redis-cli FLUSHALL
```

Or restart the container from scratch:

```bash
docker rm -f redis-learn
docker run --name redis-learn -p 6379:6379 -d redis:7
```
