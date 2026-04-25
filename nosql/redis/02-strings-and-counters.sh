#!/usr/bin/env bash
# 02-strings-and-counters.sh
# Redis's simplest data type: strings, plus the atomic-integer operations
# built on them. Despite the name, Redis "strings" hold integers just fine —
# they're really opaque byte sequences.
# Run with:  bash 02-strings-and-counters.sh

set -euo pipefail

# Helper — run a command against the redis-learn container.
r() { docker exec redis-learn redis-cli "$@"; }

# Reset only the keys this script touches (safer than FLUSHDB across lessons).
r DEL greeting user:42:name user:42:session page:hits rate:ip:1.2.3.4 > /dev/null

echo
echo "=== SET / GET — strings ==="
# SET stores a value. GET fetches it. Both O(1).
r SET greeting "hello, redis"
r GET greeting

# Overwrite — SET is upsert by default.
r SET greeting "hello again"
r GET greeting

# Namespaced keys: the colon convention. Redis doesn't care about the ':' —
# but every Redis tool (monitoring, UIs) assumes you use it.
r SET user:42:name "Alice"
r GET user:42:name

echo
echo "=== TTL — expiring keys ==="
# EX 10 = expire after 10 seconds. Critical for anything ephemeral
# (sessions, caches, rate limits).
r SET user:42:session "token-abc123" EX 10
r TTL user:42:session          # seconds remaining, -1 if none, -2 if gone
r GET user:42:session

# Remove the TTL explicitly.
r PERSIST user:42:session
r TTL user:42:session          # -1 now

echo
echo "=== INCR / DECR — atomic counters ==="
# Classic real-world use: page-view counter.
# INCR treats the value as an integer. If it doesn't exist, it's created as 0.
# Atomic = safe across many concurrent clients; no race condition.
r INCR page:hits
r INCR page:hits
r INCR page:hits
r GET page:hits                 # "3"

# INCRBY for larger steps. DECRBY for decreases.
r INCRBY page:hits 10
r GET page:hits                 # "13"

echo
echo "=== Rate limiting — the classic 3-line recipe ==="
# Goal: allow at most 5 requests per minute from a given IP.
# Trick: INCR a key, set a 60s TTL on FIRST hit, reject if count > 5.
# Real code would check the INCR's return value; we just demo the primitives.
for i in 1 2 3; do
    COUNT=$(r INCR rate:ip:1.2.3.4)
    # Set expiry only on the first hit of this window.
    if [ "$COUNT" = "1" ]; then
        r EXPIRE rate:ip:1.2.3.4 60 > /dev/null
    fi
    echo "hit $i  →  count now: $COUNT  (TTL: $(r TTL rate:ip:1.2.3.4)s)"
done

echo
echo "=== EXISTS / DEL — housekeeping ==="
r EXISTS greeting               # 1 (exists)
r EXISTS nonexistent            # 0
r DEL greeting                  # 1 (one key deleted)
r EXISTS greeting               # 0

echo
echo "=== Done ==="
