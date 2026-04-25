// 03-nested-and-arrays.js
// The thing documents do that rows don't: embed data. An "order" document can
// CONTAIN its line items, instead of linking to an `order_items` table.
// This is MongoDB's main ergonomic argument over relational models.
// Run with:  docker exec -i mongo-learn mongosh --quiet learn_mongo < 03-nested-and-arrays.js

db.orders.drop();

// One order, with the customer info AND the items embedded. In SQL this would
// typically be three tables (orders, order_items, maybe customers) and a join.
db.orders.insertMany([
    {
        orderNo: "A-1001",
        customer: { id: 42, name: "Alice", email: "alice@example.com" },
        items: [
            { sku: "WID-1", name: "Widget",  qty: 2, price: 19.99 },
            { sku: "GIZ-7", name: "Gizmo",   qty: 1, price: 29.50 },
        ],
        status: "shipped",
        total: 69.48,
        tags: ["priority", "gift"],
        placedAt: new Date("2026-01-15"),
    },
    {
        orderNo: "A-1002",
        customer: { id: 43, name: "Bob", email: "bob@example.com" },
        items: [
            { sku: "WID-1", name: "Widget",  qty: 5, price: 19.99 },
        ],
        status: "pending",
        total: 99.95,
        tags: [],
        placedAt: new Date("2026-02-03"),
    },
    {
        orderNo: "A-1003",
        customer: { id: 42, name: "Alice", email: "alice@example.com" },
        items: [
            { sku: "GAD-3", name: "Gadget",  qty: 3, price: 15.00 },
            { sku: "GIZ-7", name: "Gizmo",   qty: 2, price: 29.50 },
        ],
        status: "shipped",
        total: 104.00,
        tags: ["priority"],
        placedAt: new Date("2026-03-10"),
    },
]);

// ---------------------------------------------------------------------------
// Dotted path — reach into nested fields with `"field.subfield"`.
// No $lookup needed because the customer is already inside the document.
// ---------------------------------------------------------------------------
print("\n--- orders placed by customer id 42 ---");
printjson(db.orders.find({ "customer.id": 42 }, { _id: 0, orderNo: 1, total: 1 }).toArray());

// ---------------------------------------------------------------------------
// Array queries — ask about the array as a whole.
//   $in       — ANY element matches one of a set of values
//   $all      — array CONTAINS ALL the given values
//   $size     — array has exactly N elements
// ---------------------------------------------------------------------------
print("\n--- orders tagged 'priority' ---");
printjson(db.orders.find({ tags: "priority" }, { _id: 0, orderNo: 1, tags: 1 }).toArray());

print("\n--- orders with BOTH 'priority' AND 'gift' tags ---");
printjson(db.orders.find({ tags: { $all: ["priority", "gift"] } }, { _id: 0, orderNo: 1, tags: 1 }).toArray());

// ---------------------------------------------------------------------------
// Arrays of objects — use $elemMatch to require "the SAME array element matches
// all these conditions". Without $elemMatch, each condition can be satisfied
// by a DIFFERENT element.
// ---------------------------------------------------------------------------
print("\n--- orders containing at least one Widget with qty >= 2 ---");
printjson(
    db.orders.find(
        { items: { $elemMatch: { sku: "WID-1", qty: { $gte: 2 } } } },
        { _id: 0, orderNo: 1, items: 1 }
    ).toArray()
);

// ---------------------------------------------------------------------------
// Updates into nested structures.
//   $set with a dotted path     — overwrite a nested field
//   $push / $pull               — append / remove from an array
//   $inc on `items.$[elem].qty` — modify specific array elements (filtered update)
// ---------------------------------------------------------------------------

// Mark every pending order as shipped.
db.orders.updateMany(
    { status: "pending" },
    { $set: { status: "shipped" } }
);

// Append a tag (without duplicates — that's $addToSet; $push allows duplicates).
db.orders.updateOne(
    { orderNo: "A-1002" },
    { $addToSet: { tags: "backorder" } }
);

// Positional filtered update: "in order A-1001, double the qty of SKU WID-1".
db.orders.updateOne(
    { orderNo: "A-1001" },
    { $mul: { "items.$[elem].qty": 2 } },
    { arrayFilters: [ { "elem.sku": "WID-1" } ] }
);

print("\n--- after updates ---");
printjson(db.orders.find({}, { _id: 0, orderNo: 1, status: 1, tags: 1, items: 1 }).toArray());

// ---------------------------------------------------------------------------
// Indexes on nested and array fields.
// ---------------------------------------------------------------------------
db.orders.createIndex({ "customer.id": 1 });     // nested field
db.orders.createIndex({ tags: 1 });              // array — each element indexed
db.orders.createIndex({ "items.sku": 1 });       // fields inside array elements

print("\n--- indexes ---");
printjson(db.orders.getIndexes().map(i => ({ name: i.name, key: i.key })));

// ---------------------------------------------------------------------------
// Design decision: embed vs reference?
//   Embed     — data "belongs to" the parent and is read together. Example:
//               line items on an order. One disk read, no $lookup.
//   Reference — data is shared across parents, is huge, or changes independently.
//               Example: a Product catalog referenced by orders' item lines.
//               You store productId and resolve it separately when you need to.
//
// Rule of thumb: start by embedding. Split out to a separate collection only
// when embedding causes unbounded document growth or obvious duplication pain.
// ---------------------------------------------------------------------------
