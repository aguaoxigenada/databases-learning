// 03-leaderboard.ts
// A typed helper around a Redis sorted set. The operations you'd use
// regardless of the game/product: add a score, fetch the top N, look up a
// single player's rank.
// Run with:  npx tsx 03-leaderboard.ts

import Redis from "ioredis";

const redis = new Redis(process.env.REDIS_URL ?? "redis://localhost:6379");

type Entry = { player: string; score: number; rank: number };

class Leaderboard {
  constructor(private readonly key: string) {}

  // Add or update a player's score. ZADD overwrites if the member exists.
  setScore(player: string, score: number) {
    return redis.zadd(this.key, score, player);
  }

  // Atomically bump a player's score by `delta`.
  addToScore(player: string, delta: number) {
    return redis.zincrby(this.key, delta, player);
  }

  // Top N by score (highest first).
  // ioredis returns a flat array [member, score, member, score, ...] when
  // WITHSCORES is passed. We pair them up.
  async top(n: number): Promise<Entry[]> {
    const raw = await redis.zrange(this.key, 0, n - 1, "REV", "WITHSCORES");
    return this.pair(raw, 0);
  }

  // A single player's rank (0-indexed from the top) and score.
  async lookup(player: string): Promise<Entry | null> {
    const [rank, score] = await Promise.all([
      redis.zrevrank(this.key, player),
      redis.zscore(this.key, player),
    ]);
    if (rank === null || score === null) return null;
    return { player, score: Number(score), rank };
  }

  // Window of ranks around a player, e.g. show me "my rank ± 2".
  async around(player: string, radius: number): Promise<Entry[]> {
    const rank = await redis.zrevrank(this.key, player);
    if (rank === null) return [];
    const start = Math.max(0, rank - radius);
    const end = rank + radius;
    const raw = await redis.zrange(this.key, start, end, "REV", "WITHSCORES");
    return this.pair(raw, start);
  }

  reset() {
    return redis.del(this.key);
  }

  private pair(raw: string[], startRank: number): Entry[] {
    const out: Entry[] = [];
    for (let i = 0; i < raw.length; i += 2) {
      out.push({
        player: raw[i],
        score: Number(raw[i + 1]),
        rank: startRank + i / 2,
      });
    }
    return out;
  }
}

async function main() {
  const lb = new Leaderboard("game:s1:leaderboard");
  await lb.reset();

  // Bulk-seed. In a real game you'd call setScore after each match.
  const seed: Array<[string, number]> = [
    ["alice", 1500],
    ["bob", 800],
    ["carol", 2100],
    ["dan", 1200],
    ["eve", 1900],
    ["frank", 1600],
    ["grace", 950],
  ];
  for (const [p, s] of seed) await lb.setScore(p, s);

  console.log("--- top 5 ---");
  console.table(await lb.top(5));

  console.log("--- dan earned 500 points ---");
  await lb.addToScore("dan", 500);

  console.log("--- dan's current standing ---");
  console.log(await lb.lookup("dan"));

  console.log("--- dan's rank ± 1 (rival context) ---");
  console.table(await lb.around("dan", 1));

  console.log("--- unknown player ---");
  console.log(await lb.lookup("nobody"));
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => redis.quit());
