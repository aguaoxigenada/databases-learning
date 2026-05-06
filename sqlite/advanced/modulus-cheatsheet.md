# Modulus (`%`) — the cookie cheatsheet

You'll see `%` all over SQL (and every other language) when generating test
data, cycling values, or doing clock-style math. Here's the whole idea.

## The cookie analogy

You have `a` cookies. You want to put them in bags of `b`.

- `a / b` → how many **full bags** you can make.
- `a % b` → how many cookies are **left over** on the counter.

That's it. `%` is the leftover, not the division result.

## Worked examples (b = 20)

| Cookies (`a`) | Can I fill a bag of 20? | Full bags (`a / 20`) | Leftover (`a % 20`) |
|---------------|-------------------------|----------------------|---------------------|
| 1             | No, way short            | 0                    | **1**               |
| 3             | No                       | 0                    | **3**               |
| 19            | No, one short            | 0                    | **19**              |
| 20            | Yes, exactly             | 1                    | **0**               |
| 21            | Yes, with 1 left         | 1                    | **1**               |
| 40            | Yes, exactly twice       | 2                    | **0**               |
| 45            | Yes, twice + 5 left      | 2                    | **5**               |

Key insight: when `a < b`, you can't even fill one bag, so **everything is
leftover** → `a % b = a`. That's why `1 % 20 = 1` and `19 % 20 = 19`.

## Why "20 goes into 1 zero times" sounded weird

"X goes into Y" = "how many copies of X fit inside Y."

- "5 goes into 20" → 4 times. Natural.
- "20 goes into 1" → 0 times. Sounds odd but means: a 20 can't fit inside a 1
  even once. Zero full bags. Everything stays on the counter.

## The cycle

`n % b` always lands in the range `[0, b-1]`. Once it would reach `b`, that's
a full new group and the leftover resets to 0. So as `n` grows:

```
n        :  0  1  2  3  ... 18 19 20 21 22 ... 39 40 41 ...
n % 20   :  0  1  2  3  ... 18 19  0  1  2  ... 19  0  1 ...
```

It's a **20-position clock**. The hand cycles forever, no matter how big `n`
gets.

## Why the seeding script uses it

In `01-indexes-and-explain.sql`:

```sql
SELECT n, 'Product ' || n, (n % 20) + 1, (n % 100) + 10 FROM seq;
```

- `(n % 20) + 1` → cycles `category_id` through **1..20** (never 0).
- `(n % 100) + 10` → cycles `price` through **10..109**.

A plain counter (`n` = 1..10 000) gets turned into realistic-looking
distributions: 20 categories, evenly spread; prices spread over a 100-unit
band. No randomness needed, fully reproducible.

## Mental model

**`%` answers "what's left over?". `/` answers "how many times does it fit?"**
Modulo is the clock-arithmetic operator — `14 % 12 = 2` is exactly how 14:00
becomes 2 PM.

## `/` vs `%` at a glance

| Expression | What it means              | n=1 | n=20 | n=21 | n=10000 |
|------------|----------------------------|-----|------|------|---------|
| `n / 20`   | how many full 20s          | 0   | 1    | 1    | 500     |
| `n % 20`   | leftover after the full 20s| 1   | 0    | 1    | 0       |
| `(n % 20) + 1` | shifted into 1..20     | 2   | 1    | 2    | 1       |

## Common uses you'll keep seeing

| Pattern                    | What it does                                       |
|----------------------------|----------------------------------------------------|
| `n % 2`                    | 0 if even, 1 if odd                                |
| `n % k == 0`               | "every k-th row" (great for sampling)              |
| `(n % k) + 1`              | cycle through `1..k`                               |
| `(n % range) + offset`     | fabricate a value in `[offset, offset+range-1]`    |
| `hash(x) % buckets`        | assign `x` to one of `buckets` shards              |
