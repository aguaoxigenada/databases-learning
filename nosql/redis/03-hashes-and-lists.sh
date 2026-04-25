#!/usr/bin/env bash
# 03-hashes-and-lists.sh
# Two structures that map closely onto familiar shapes:
#   HASH  = a small dict / "row" / record. Use when a key has multiple fields.
#   LIST  = an ordered collection pushed/popped from either end.
#          The idiomatic way to build a lightweight queue.
# Run with:  bash 03-hashes-and-lists.sh

set -euo pipefail
r() { docker exec redis-learn redis-cli "$@"; }

r DEL user:42 user:43 jobs:pending news:recent > /dev/null

echo
echo "=== Hashes — structured records ==="
# Think of a hash as one row of a table, where the Redis key is the primary key
# and each field is a column. `HSET` sets one or more fields at once.
r HSET user:42 name "Alice" email "alice@example.com" age 30

# HGET — one field. HGETALL — every field.
r HGET user:42 name
r HGETALL user:42

# Why hashes instead of many strings?
#   - Atomic multi-field updates.
#   - Memory-efficient: Redis packs small hashes into a single allocation.
#   - You can modify one field without touching the others.
r HSET user:42 age 31
r HGET user:42 age

# Atomic counter ON A FIELD — common pattern for "view count per post".
r HINCRBY user:42 login_count 1
r HINCRBY user:42 login_count 1
r HGET user:42 login_count

# Delete a single field (not the whole record).
r HDEL user:42 email
r HGETALL user:42

echo
echo "=== Lists — queues and feeds ==="
# A list is a linked list of strings. Push and pop at either end in O(1).
# Naming convention in real usage:
#   LPUSH + RPOP  = FIFO queue (push left, pop right)
#   LPUSH + LPOP  = LIFO stack

# Simulate a job queue. Producer pushes work items.
r LPUSH jobs:pending "send-email:123"
r LPUSH jobs:pending "resize-image:456"
r LPUSH jobs:pending "index-search:789"

r LLEN jobs:pending             # 3

# Inspect without removing. LRANGE is 0-indexed, end-inclusive.
# -1 means "last element"; 0..-1 means "everything".
r LRANGE jobs:pending 0 -1

# Consumer pops from the right (FIFO — oldest job first).
r RPOP jobs:pending
r RPOP jobs:pending
r LRANGE jobs:pending 0 -1

echo
echo "=== Lists as capped recent-N logs ==="
# A very common pattern: keep the last N items, drop older ones.
# LPUSH each new entry, then LTRIM to keep only the newest N.
for headline in "H1" "H2" "H3" "H4" "H5" "H6" "H7"; do
    r LPUSH news:recent "$headline" > /dev/null
    r LTRIM news:recent 0 4 > /dev/null         # keep indices 0..4 → 5 newest
done

echo "most recent 5 headlines (newest first):"
r LRANGE news:recent 0 -1

echo
echo "=== Blocking reads — BRPOP ==="
# In real consumer code you'd use BRPOP instead of RPOP. It blocks until an
# item arrives or a timeout expires. That avoids busy-looping the consumer.
# We skip a live demo because it'd block this script; the call shape is:
#   BRPOP jobs:pending 5      -- wait up to 5 seconds
# Returns (key, value) on success, nil on timeout.
echo "(see inline comment — BRPOP blocks, not demoed here)"

echo
echo "=== Done ==="
