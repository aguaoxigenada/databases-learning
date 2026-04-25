// 04-pipelining.ts
// Pipelining = ship many commands in one network round-trip. The single
// biggest performance knob once your app makes more than a handful of
// Redis calls per request.
// Run with:  npx tsx 04-pipelining.ts

import Redis from "ioredis";

const redis = new Redis(process.env.REDIS_URL ?? "redis://localhost:6379");

async function main() {
  await redis.del(
    ...Array.from({ length: 100 }, (_, i) => `bench:counter:${i}`),
  );

  const N = 100;

  // ---------------------------------------------------------------------------
  // BAD: one await per command. Each call waits for the full round-trip
  // before issuing the next. Even on localhost this adds up fast.
  // ---------------------------------------------------------------------------
  let t = Date.now();
  for (let i = 0; i < N; i++) {
    await redis.incr(`bench:counter:${i}`);
  }
  const serial = Date.now() - t;
  console.log(`serial (${N} INCRs):     ${serial} ms`);

  // ---------------------------------------------------------------------------
  // GOOD: pipeline. All commands queued on the client, sent as one batch,
  // one round-trip for all their responses.
  // ---------------------------------------------------------------------------
  // Reset so the demo is fair.
  await redis.del(
    ...Array.from({ length: N }, (_, i) => `bench:counter:${i}`),
  );

  t = Date.now();
  const pipeline = redis.pipeline();
  for (let i = 0; i < N; i++) {
    pipeline.incr(`bench:counter:${i}`);
  }
  const results = await pipeline.exec();
  const pipelined = Date.now() - t;
  console.log(`pipelined (${N} INCRs):  ${pipelined} ms`);
  console.log(`speedup:                 ${(serial / pipelined).toFixed(1)}×`);

  // results is Array<[err, value]>. You iterate to get each command's reply.
  console.log(`first 3 results:`, results?.slice(0, 3));

  // ---------------------------------------------------------------------------
  // multi() = pipeline + atomicity
  // ---------------------------------------------------------------------------
  // .multi() is the transactional form: the server queues your commands and
  // runs them atomically (no other client can interleave). Use when
  // correctness depends on atomicity, not when you just want throughput.
  //
  // Example: "decrement stock AND push an audit event" — both or neither.
  await redis.set("stock:widget", "10");
  await redis.del("audit:events");

  const tx = redis.multi();
  tx.decr("stock:widget");
  tx.rpush("audit:events", JSON.stringify({ type: "sale", sku: "widget" }));
  await tx.exec();

  console.log("\nafter MULTI:");
  console.log("  stock:widget =", await redis.get("stock:widget"));
  console.log("  audit:events =", await redis.lrange("audit:events", 0, -1));

  // ---------------------------------------------------------------------------
  // When you'd use one vs the other:
  //   pipeline()  — throughput. N independent commands, don't care about
  //                 atomicity. "Warm 50 cache keys", "bulk increment", etc.
  //   multi()     — correctness. "These commands must run as a unit."
  //                 Slightly more overhead than pipeline.
  //
  // Lua scripts (EVAL) are the next level: arbitrary logic, executed
  // server-side atomically. Beyond this tutorial.
  // ---------------------------------------------------------------------------
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => redis.quit());
