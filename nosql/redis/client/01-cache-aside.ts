// 01-cache-aside.ts
// The same pattern as ../05-cache-patterns.sh, expressed as a reusable,
// typed helper you'd actually drop into an app.
// Run with:  npx tsx 01-cache-aside.ts

import Redis from "ioredis";

const redis = new Redis(process.env.REDIS_URL ?? "redis://localhost:6379");

// ---------------------------------------------------------------------------
// A cache-aside helper. Given a key, a fetcher that knows how to produce the
// fresh value, and a TTL, returns the cached value if present or populates
// and returns fresh on miss.
//
// The generic <T> means callers get back the type they serialised in.
// Redis stores strings; we JSON-encode/decode at the boundary.
// ---------------------------------------------------------------------------
async function cached<T>(
  key: string,
  ttlSeconds: number,
  fetcher: () => Promise<T>,
): Promise<{ value: T; source: "cache" | "origin" }> {
  const hit = await redis.get(key);
  if (hit !== null) {
    return { value: JSON.parse(hit) as T, source: "cache" };
  }
  const fresh = await fetcher();
  // SET with EX — store with a TTL in one round trip. Alternatively SETEX.
  await redis.set(key, JSON.stringify(fresh), "EX", ttlSeconds);
  return { value: fresh, source: "origin" };
}

// ---------------------------------------------------------------------------
// Pretend this is an expensive Postgres query.
// ---------------------------------------------------------------------------
type UserProfile = { id: number; name: string; plan: "free" | "pro" };

async function fetchUserFromDb(id: number): Promise<UserProfile> {
  // Simulate network + query cost.
  await new Promise((r) => setTimeout(r, 120));
  return { id, name: "Alice", plan: "pro" };
}

async function getUserProfile(id: number): Promise<UserProfile> {
  const { value, source } = await cached(
    `cache:user_profile:${id}`,
    60, // 1 minute TTL — short enough that stale data corrects itself
    () => fetchUserFromDb(id),
  );
  console.log(`  (${source})`, value);
  return value;
}

async function main() {
  // Clean slate.
  await redis.del("cache:user_profile:42");

  console.log("--- first call: cache MISS, populates ---");
  let t = Date.now();
  await getUserProfile(42);
  console.log(`  took ${Date.now() - t}ms`);

  console.log("--- second call: cache HIT ---");
  t = Date.now();
  await getUserProfile(42);
  console.log(`  took ${Date.now() - t}ms`);

  console.log("--- write happens → invalidate ---");
  await redis.del("cache:user_profile:42");
  console.log("  cache invalidated");

  console.log("--- third call: MISS again, repopulates ---");
  t = Date.now();
  await getUserProfile(42);
  console.log(`  took ${Date.now() - t}ms`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => redis.quit());
