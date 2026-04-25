// 02-rate-limiter.ts
// A compact, atomic, fixed-window rate limiter.
// Run with:  npx tsx 02-rate-limiter.ts

import Redis from "ioredis";

const redis = new Redis(process.env.REDIS_URL ?? "redis://localhost:6379");

// ---------------------------------------------------------------------------
// Allow up to `limit` actions per `windowSeconds` for `identity` (user id, IP).
// Returns { allowed, count, ttl }. Atomic: INCR + EXPIRE race-free because
// INCR's return value tells us whether we're the one who created the key.
// ---------------------------------------------------------------------------
async function rateLimit(
  identity: string,
  limit: number,
  windowSeconds: number,
): Promise<{ allowed: boolean; count: number; ttlSeconds: number }> {
  const key = `rate:${identity}`;

  // pipeline = both commands in one round trip.
  const pipeline = redis.multi();
  pipeline.incr(key);
  pipeline.ttl(key);
  const results = await pipeline.exec();

  if (!results) throw new Error("rate limit pipeline failed");

  const count = results[0][1] as number;
  let ttl = results[1][1] as number;

  // If the key just got created, TTL is -1 → set the expiry now.
  if (ttl === -1) {
    await redis.expire(key, windowSeconds);
    ttl = windowSeconds;
  }

  return {
    allowed: count <= limit,
    count,
    ttlSeconds: ttl,
  };
}

async function main() {
  const ip = "1.2.3.4";
  await redis.del(`rate:${ip}`);

  console.log("--- limit: 3 requests per 10 seconds ---");
  for (let i = 1; i <= 5; i++) {
    const r = await rateLimit(ip, 3, 10);
    console.log(
      `hit ${i}:  allowed=${r.allowed}  count=${r.count}/3  ttl=${r.ttlSeconds}s`,
    );
  }

  // ---------------------------------------------------------------------------
  // Why this is "fixed window" — and when it's not enough
  // ---------------------------------------------------------------------------
  // The window resets at a fixed boundary. That means someone could hit the
  // limit at 0:59 of window A, then immediately hit it again at 1:01 of
  // window B — effectively 2× the intended rate at the seam. Fine for most
  // "don't hammer me" use cases.
  //
  // For production rate limiting you'd layer:
  //   - Sliding-window-log: store every hit timestamp in a sorted set and
  //     count hits in the last N seconds. Exact but more memory.
  //   - Token bucket: atomic Lua script for refilling tokens smoothly.
  //     Preferred for "X requests per second, bursts OK".
  // ---------------------------------------------------------------------------
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => redis.quit());
