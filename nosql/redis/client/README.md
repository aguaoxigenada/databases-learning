# Redis from TypeScript (ioredis)

The CLI scripts in `../` showed you the commands. This folder shows what they look like from **application code** — which is how you'll actually use Redis in a real project.

We use [**ioredis**](https://github.com/redis/ioredis). There's also `node-redis` (the official client); the APIs are similar. ioredis has slightly nicer defaults and strong TypeScript types.

## Files

1. `01-cache-aside.ts` — the canonical cache pattern as a reusable typed function.
2. `02-rate-limiter.ts` — a sliding-window-style rate limiter in ~15 lines.
3. `03-leaderboard.ts` — sorted sets as a typed helper: add, top N, player rank.
4. `04-pipelining.ts` — batch multiple commands into one round trip. The single biggest performance win once you start calling Redis often.

## Setup

You need the `redis-learn` Docker container running (see `../README.md`). Then:

```bash
cp .env.example .env         # edit if your Redis isn't at localhost:6379
npm install
```

## Running

```bash
npx tsx 01-cache-aside.ts
npx tsx 02-rate-limiter.ts
npx tsx 03-leaderboard.ts
npx tsx 04-pipelining.ts
```

Or via the npm shortcuts:

```bash
npm run cache
npm run rate
npm run leaderboard
npm run pipeline
```

## Why TypeScript here

- Redis values are raw bytes → strings by default. The moment you want to store an object, you serialise to JSON yourself. Types catch "I stored `{x:1}` and deserialised it as `Array<string>`" bugs at compile time.
- Sorted set scores are numbers; members are strings. ioredis's types reflect that, so you can't accidentally pass a member where a score belongs.
- Command signatures are typed. `zrange(key, start, stop, "REV", "WITHSCORES")` — the flags are string literals, autocompleted.
