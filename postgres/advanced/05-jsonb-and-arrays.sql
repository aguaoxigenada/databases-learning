-- 05-jsonb-and-arrays.sql (Postgres only)
-- Goal: work with semi-structured data WITHOUT dropping to a NoSQL store.
-- JSONB + arrays are two of Postgres's biggest reasons-for-being over SQLite.
-- Run with:  docker exec -i pg-learn psql -U postgres -d learn_pg < 05-jsonb-and-arrays.sql

DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS articles;

-- ---------------------------------------------------------------------------
-- PART 1 — JSONB
-- ---------------------------------------------------------------------------
-- JSON  — stored as TEXT, re-parsed every read. Preserves whitespace/key order.
-- JSONB — stored as a parsed binary tree. Slightly slower to write, MUCH
--         faster to query, and indexable. Use JSONB unless you have a very
--         specific reason not to.

CREATE TABLE events (
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type       TEXT    NOT NULL,
    payload    JSONB   NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO events (type, payload) VALUES
    ('signup',   '{"user": "alice", "plan": "pro",    "source": {"campaign": "spring25", "medium": "email"}}'),
    ('signup',   '{"user": "bob",   "plan": "free",   "source": {"campaign": "spring25", "medium": "ads"}}'),
    ('purchase', '{"user": "alice", "items": [{"sku": "A1", "qty": 2}, {"sku": "B7", "qty": 1}], "total": 59}'),
    ('purchase', '{"user": "carol", "items": [{"sku": "A1", "qty": 5}], "total": 125}'),
    ('signup',   '{"user": "dan",   "plan": "pro",    "source": {"campaign": "referral", "medium": "link"}}');

-- ---------------------------------------------------------------------------
-- Reading JSONB — two operators, one crucial distinction:
--   ->   returns JSONB (keeps the quotes and type)
--   ->>  returns TEXT  (strips them — what you normally want for display)
-- ---------------------------------------------------------------------------
\echo '--- -> (JSONB) vs ->> (TEXT) ---'
SELECT
    payload -> 'user'  AS user_jsonb,      -- "alice"
    payload ->> 'user' AS user_text        -- alice
FROM events
WHERE type = 'signup';

-- Chain for nested access.
\echo '--- signups by campaign ---'
SELECT
    payload ->> 'user'                     AS user,
    payload -> 'source' ->> 'campaign'     AS campaign,
    payload -> 'source' ->> 'medium'       AS medium
FROM events
WHERE type = 'signup';

-- Filter by a nested JSON value. Cast to text for comparison, or use ->>.
\echo '--- all "pro" signups ---'
SELECT payload ->> 'user' AS user
FROM events
WHERE type = 'signup' AND payload ->> 'plan' = 'pro';

-- ---------------------------------------------------------------------------
-- Containment — Postgres's killer JSONB feature.
--   @>   "does the left side contain everything in the right side?"
-- Great for filtering on a specific shape without unfolding every key.
-- ---------------------------------------------------------------------------
\echo '--- events from the spring25 campaign (any nesting depth) ---'
SELECT id, type, payload ->> 'user' AS user
FROM events
WHERE payload @> '{"source": {"campaign": "spring25"}}';

-- ---------------------------------------------------------------------------
-- jsonb_array_elements — unfold an array into rows.
-- Best way to "JOIN across" items in an array.
-- ---------------------------------------------------------------------------
\echo '--- line items across all purchases ---'
SELECT
    e.id                               AS event_id,
    e.payload ->> 'user'               AS user,
    item ->> 'sku'                     AS sku,
    (item ->> 'qty')::INTEGER          AS qty
FROM events AS e, jsonb_array_elements(e.payload -> 'items') AS item
WHERE e.type = 'purchase';

-- ---------------------------------------------------------------------------
-- Indexing JSONB — the GIN index.
-- A GIN index on a JSONB column can serve `@>` queries. Creating one:
-- ---------------------------------------------------------------------------
CREATE INDEX idx_events_payload_gin ON events USING GIN (payload);

-- Now this query can use the index instead of scanning every row:
--   SELECT * FROM events WHERE payload @> '{"user": "alice"}';
-- On 10 000 events the difference is dramatic; on 5 it isn't worth showing,
-- but the shape-of-things is what matters.

\echo '--- plan for a containment query (should use GIN) ---'
EXPLAIN SELECT * FROM events WHERE payload @> '{"user": "alice"}';
-- Note: on tiny tables Postgres may still choose Seq Scan because the
-- overhead of an index lookup exceeds the saving. That's correct behaviour.

-- ---------------------------------------------------------------------------
-- PART 2 — Arrays
-- ---------------------------------------------------------------------------
-- Every type has an array form: INTEGER[], TEXT[], JSONB[], etc.
-- 1-indexed (unlike most languages). Useful when a field naturally is
-- "a handful of tags" — overkill to model as a separate table.

CREATE TABLE articles (
    id    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title TEXT    NOT NULL,
    tags  TEXT[]  NOT NULL DEFAULT '{}'
);

INSERT INTO articles (title, tags) VALUES
    ('Intro to Postgres',       ARRAY['sql', 'postgres', 'beginner']),
    ('Advanced Window Tricks',  ARRAY['sql', 'advanced']),
    ('Prisma + SQLite',         ARRAY['orm', 'prisma', 'sqlite']),
    ('Scaling Postgres',        ARRAY['postgres', 'advanced', 'devops']);

\echo '--- articles tagged "advanced" ---'
SELECT title FROM articles WHERE 'advanced' = ANY(tags);

\echo '--- articles tagged with ANY of (postgres, prisma) ---'
SELECT title FROM articles WHERE tags && ARRAY['postgres', 'prisma'];
-- && = array overlap.

\echo '--- articles tagged with BOTH "sql" AND "advanced" ---'
SELECT title FROM articles WHERE tags @> ARRAY['sql', 'advanced'];
-- @> = left contains right.

\echo '--- how many tags each article has ---'
SELECT title, array_length(tags, 1) AS tag_count FROM articles;

\echo '--- explode tags into rows ---'
SELECT title, unnest(tags) AS tag FROM articles ORDER BY title;

-- ---------------------------------------------------------------------------
-- When to use JSONB vs arrays vs a real relation
-- ---------------------------------------------------------------------------
-- JSONB       — payload shape is irregular / evolves / came from outside
--               your system (webhook, analytics event, flexible config).
-- Array       — small, homogeneous, rarely queried on individual elements
--               (tags, permissions, enabled feature flags).
-- Separate
-- table       — many rows per parent, you'll FK-reference it, you'll
--               query and index individual child rows. Always the
--               "relational answer"; use JSONB/arrays only when it clearly
--               wins on ergonomics.
