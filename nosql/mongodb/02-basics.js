// 02-basics.js
// Mongo's equivalent of sqlite/basics/02-basics.sql: CRUD on a `users` collection.
// Run with:  docker exec -i mongo-learn mongosh --quiet learn_mongo < 02-basics.js

// Start clean so the script is re-runnable.
db.users.drop();

// ---------------------------------------------------------------------------
// INSERT — no schema definition needed. The first `insertOne` creates the
// collection on the fly.
// Each document gets an auto-generated `_id` (an ObjectId) unless you provide
// one. That `_id` is the primary key and is always indexed.
// ---------------------------------------------------------------------------
db.users.insertMany([
    { name: "Alice",   email: "alice@example.com",   age: 30, createdAt: new Date() },
    { name: "Bob",     email: "bob@example.com",     age: 25, createdAt: new Date() },
    { name: "Charlie", email: "charlie@example.com", age: 35, createdAt: new Date() },
    { name: "Diana",   email: "diana@example.com",   age: 28, createdAt: new Date() },
]);

// We WANT email to be unique. Unlike SQL, this isn't declared with the
// collection — you create an index that enforces it.
db.users.createIndex({ email: 1 }, { unique: true });

print("\n--- all users ---");
// find() with no filter = all documents.
// .toArray() makes the result print nicely in mongosh.
printjson(db.users.find().toArray());

// ---------------------------------------------------------------------------
// SELECT equivalents.
// find(filter, projection). Projection = which fields to include.
// ---------------------------------------------------------------------------
print("\n--- users older than 27, newest first (only name + age) ---");
printjson(
    db.users
        .find(
            { age: { $gt: 27 } },          // WHERE age > 27
            { _id: 0, name: 1, age: 1 }    // SELECT name, age   (0 = omit, 1 = include)
        )
        .sort({ age: -1 })                 // ORDER BY age DESC   (-1 desc, 1 asc)
        .toArray()
);

// ---------------------------------------------------------------------------
// UPDATE — operators ($set, $inc, $push, etc.) describe the change.
// Without operators, the update would REPLACE the whole document.
// ---------------------------------------------------------------------------
db.users.updateOne(
    { name: "Alice" },
    { $set: { age: 31 } }
);

// ---------------------------------------------------------------------------
// DELETE.
// ---------------------------------------------------------------------------
db.users.deleteOne({ name: "Bob" });

print("\n--- after update and delete ---");
printjson(db.users.find().toArray());

// ---------------------------------------------------------------------------
// What's *not* here that SQL gave you:
//   - No schema declaration: Mongo would happily accept `{ age: "thirty" }`
//     for the next insert. That's dangerous — in real projects, use a
//     validation layer (Mongoose, Zod, or Mongo's built-in $jsonSchema).
//   - No NOT NULL: it's on you and your code to insist a field is present.
//   - No CHECK constraints: ditto.
// ---------------------------------------------------------------------------
