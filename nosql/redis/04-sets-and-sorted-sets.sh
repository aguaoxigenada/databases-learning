#!/usr/bin/env bash
# 04-sets-and-sorted-sets.sh
#   SET       — unordered collection of unique strings.
#   SORTED SET (zset) — set where each member has a numeric "score".
#                       Members kept auto-sorted by score. The killer structure
#                       for leaderboards, priority queues, and time-based indexes.
# Run with:  bash 04-sets-and-sorted-sets.sh

set -euo pipefail
r() { docker exec redis-learn redis-cli "$@"; }

r DEL tags:article:1 tags:article:2 online:users leaderboard:global > /dev/null

echo
echo "=== Sets — uniqueness and membership ==="
# SADD adds members. Duplicates are silently ignored (that's the point).
r SADD tags:article:1 "redis" "database" "nosql"
r SADD tags:article:1 "redis"           # already there, returns 0

r SMEMBERS tags:article:1                # all members
r SCARD tags:article:1                   # count
r SISMEMBER tags:article:1 "nosql"       # 1 (yes)
r SISMEMBER tags:article:1 "sql"         # 0 (no)

# Set algebra in one round-trip — SINTER, SUNION, SDIFF.
r SADD tags:article:2 "database" "sql" "postgres"

echo "articles 1 ∩ 2 (common tags):"
r SINTER tags:article:1 tags:article:2

echo "articles 1 ∪ 2 (all tags):"
r SUNION tags:article:1 tags:article:2

echo "articles 1 − 2 (only in 1):"
r SDIFF tags:article:1 tags:article:2

echo
echo "=== Sets for presence / uniqueness counting ==="
# "Who's online right now?" — SADD to a set, expire the set, or remove on logout.
# "How many unique visitors today?" — SADD with a visitor id, then SCARD.
r SADD online:users "alice" "bob" "carol"
r SADD online:users "alice"              # still 3 — sets dedupe
r SCARD online:users                     # 3
r SREM online:users "bob"
r SCARD online:users                     # 2

echo
echo "=== Sorted sets — the leaderboard ==="
# ZADD key score member. Add players with scores.
r ZADD leaderboard:global 1500 "alice"
r ZADD leaderboard:global  800 "bob"
r ZADD leaderboard:global 2100 "carol"
r ZADD leaderboard:global 1200 "dan"
r ZADD leaderboard:global 1900 "eve"

echo "top 3 players (highest scores first):"
# ZRANGE ... REV orders high-to-low. WITHSCORES includes the numeric score.
r ZRANGE leaderboard:global 0 2 REV WITHSCORES

echo
echo "bottom 3 players:"
r ZRANGE leaderboard:global 0 2 WITHSCORES

echo
echo "players with score between 1000 and 1800:"
r ZRANGEBYSCORE leaderboard:global 1000 1800 WITHSCORES

echo
echo "alice's rank (0 = lowest), and rank from the top:"
r ZRANK leaderboard:global "alice"
r ZREVRANK leaderboard:global "alice"

echo
echo "alice scored 300 more points — atomic increment:"
r ZINCRBY leaderboard:global 300 "alice"
r ZSCORE leaderboard:global "alice"

echo
echo "top 3 after alice's bonus:"
r ZRANGE leaderboard:global 0 2 REV WITHSCORES

echo
echo "=== Sorted sets for time-ordered event windows ==="
# A huge real-world pattern: score = a unix timestamp. You can then fetch
# "events in the last hour" with ZRANGEBYSCORE on a time range. That's how
# many rate limiters, feeds, and notification queues work.
r ZADD events:user:42 1716500000 "login" 1716500600 "view-page" 1716501200 "logout"
echo "all events with timestamps:"
r ZRANGE events:user:42 0 -1 WITHSCORES

echo
echo "=== Done ==="
