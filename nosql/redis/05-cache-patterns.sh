#!/usr/bin/env bash
# 05-cache-patterns.sh
# The #1 reason Redis exists in a real app: caching the results of expensive
# work. This script walks through the canonical "cache-aside" pattern and the
# knobs you tune around it (TTL, stampedes, invalidation).
# Run with:  bash 05-cache-patterns.sh

set -euo pipefail
r() { docker exec redis-learn redis-cli "$@"; }

r DEL "cache:user_profile:42" "cache:top_articles" > /dev/null

# -----------------------------------------------------------------------------
# PATTERN 1 — Cache-aside (aka lazy loading)
# -----------------------------------------------------------------------------
# Pseudocode of the pattern in an app:
#
#   def get_user_profile(id):
#       cached = redis.get(f"cache:user_profile:{id}")
#       if cached:
#           return cached               # HIT — microseconds
#       fresh = db.query("SELECT ... FROM users WHERE id = %s", id)   # MISS — ms
#       redis.set(f"cache:user_profile:{id}", fresh, ex=300)          # populate
#       return fresh
#
# On write, invalidate the key:
#       db.update(...)
#       redis.delete(f"cache:user_profile:{id}")
#
# The application code decides what to cache and when to invalidate. Redis is
# passive — it just stores what you tell it to, with a TTL as a safety net.

echo
echo "=== Cache-aside demo ==="
KEY="cache:user_profile:42"

# First call — cache MISS.
VALUE=$(r GET "$KEY")
if [ -z "$VALUE" ]; then
    echo "MISS → would hit Postgres here, takes ~10ms"
    # Simulate the fetched row + write to Redis with a 5-minute TTL.
    r SET "$KEY" '{"id":42,"name":"Alice","plan":"pro"}' EX 300 > /dev/null
    VALUE=$(r GET "$KEY")
fi
echo "served: $VALUE"
echo "TTL remaining: $(r TTL "$KEY")s"

# Second call — cache HIT.
VALUE=$(r GET "$KEY")
echo "next call → served from cache (HIT, ~0.2ms):  $VALUE"

# Write through — invalidate on update.
echo
echo "user updates their profile → DEL the key so next read repopulates:"
r DEL "$KEY"
r EXISTS "$KEY"                    # 0

# -----------------------------------------------------------------------------
# PATTERN 2 — Short TTLs for "mostly-read" computed data
# -----------------------------------------------------------------------------
# Things like "top 10 articles this hour" or "homepage feed" are expensive to
# compute but don't need to be perfectly fresh. Cache them for a bounded window.
# No invalidation needed — they just expire.

echo
echo "=== Short-TTL computed cache ==="
TOP_KEY="cache:top_articles"
r SET "$TOP_KEY" '[{"id":101,"title":"Intro to Redis"},{"id":77,"title":"JSONB wins"}]' EX 60 > /dev/null
r GET "$TOP_KEY"
echo "expires in: $(r TTL "$TOP_KEY")s"

# -----------------------------------------------------------------------------
# PATTERN 3 — Preventing a cache stampede
# -----------------------------------------------------------------------------
# Problem: an entry expires. 1000 requests arrive simultaneously. All 1000
# miss the cache. All 1000 hit Postgres. Postgres melts.
#
# Fix: the first miss takes a short-lived "lock" (SET NX EX), computes the
# value, populates the cache, releases the lock. Everyone else either waits
# a few ms and retries (finds the now-warm cache), or serves the stale value.
#
# SET with NX = "only set if the key does NOT already exist". Perfect for locks.
echo
echo "=== Stampede-protecting lock pattern ==="
LOCK="lock:build_top_articles"
r DEL "$LOCK" > /dev/null

# First caller acquires the lock (NX succeeds because the key didn't exist).
RESULT=$(r SET "$LOCK" "worker-1" NX EX 10)
echo "worker-1 tries to lock:  $RESULT"     # OK

# Second caller finds it already held (NX fails).
RESULT=$(r SET "$LOCK" "worker-2" NX EX 10)
echo "worker-2 tries to lock:  ${RESULT:-<nil, already held>}"

# When worker-1 finishes, it releases.
r DEL "$LOCK" > /dev/null
echo "worker-1 releases; lock now free"

# -----------------------------------------------------------------------------
# How to pick a TTL — heuristics
# -----------------------------------------------------------------------------
# - How stale is tolerable? Profile data = minutes. Homepage = seconds. Payment
#   state = don't cache.
# - Reads per second × value size × cache rate = memory pressure.
# - Start with short TTLs (30-60s). Make them longer only if cache hit rate
#   is too low AND the data is OK to be stale.
# - NEVER cache a key forever. Bugs in invalidation are the most common
#   source of "why is my app showing yesterday's data?" — a TTL is cheap
#   insurance.

echo
echo "=== Done ==="
