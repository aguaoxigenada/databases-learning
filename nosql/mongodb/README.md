# MongoDB — Document Store

Parallel to `../../sqlite/basics/` — but the data model is different. MongoDB stores **documents** (JSON-ish objects) in **collections**, not rows in tables.

You already saw "JSON inside a relational DB" in `../../postgres/advanced/05-jsonb-and-arrays.sql`. MongoDB is what you get when "JSON inside" becomes "JSON is the whole model". The interesting question this folder answers: **when is that actually better than Postgres + JSONB?**

## Files

1. `01-concepts.md` — what MongoDB is, how it differs from relational, and the direct comparison with Postgres JSONB. Read first.
2. `02-basics.js` — CRUD on a `users` collection.
3. `03-nested-and-arrays.js` — documents with nested objects and arrays; the queries they enable.
4. `04-queries-and-aggregation.js` — filters, sort, limit, and the aggregation pipeline (`$match`, `$group`, `$sort`).
5. `05-jsonb-vs-mongodb.md` — side-by-side comparison with the Postgres JSONB lesson. When to pick which.

## Setup

A Mongo 7 Docker container named `mongo-learn`:

```bash
docker start mongo-learn          # if stopped
docker ps | grep mongo-learn      # verify
```

If the container doesn't exist yet:

```bash
docker run --name mongo-learn -p 27017:27017 -d mongo:7
```

Verify it answers:

```bash
docker exec mongo-learn mongosh --quiet --eval 'db.runCommand({ping:1})'
```

## Running a lesson script

Scripts are plain JavaScript files (mongosh is a Node-based shell).

```bash
# from inside nosql/mongodb/
docker exec -i mongo-learn mongosh --quiet learn_mongo < 02-basics.js
```

`learn_mongo` is the database name — Mongo creates it on first use.

## Exploring interactively

```bash
docker exec -it mongo-learn mongosh learn_mongo
```

Useful commands at the `learn_mongo>` prompt:

```
show collections              -- list collections (≈ .tables)
db.users.find()               -- all documents in users
db.users.find().limit(1).pretty()
db.users.findOne({ name: "Alice" })
exit                          -- quit
```

## Reset

```bash
docker exec mongo-learn mongosh --quiet learn_mongo --eval "db.dropDatabase()"
```
