// 04-queries-and-aggregation.js
// Mongo's aggregation pipeline is its equivalent of SQL's
// SELECT ... FROM ... WHERE ... GROUP BY ... HAVING ... ORDER BY ... LIMIT.
// You pass an ARRAY of stages. Each stage transforms the documents flowing
// through it. Think Unix pipes, but for documents.
// Assumes 03-nested-and-arrays.js has been run (needs the `orders` collection).
// Run with:  docker exec -i mongo-learn mongosh --quiet learn_mongo < 04-queries-and-aggregation.js

// ---------------------------------------------------------------------------
// Simple finds — the `find()` API covers basic filtering, sort, limit.
// ---------------------------------------------------------------------------
print("\n--- orders placed in Feb 2026 or later, total > 90 ---");
printjson(
    db.orders.find(
        { placedAt: { $gte: new Date("2026-02-01") }, total: { $gt: 90 } },
        { _id: 0, orderNo: 1, placedAt: 1, total: 1 }
    ).toArray()
);

// ---------------------------------------------------------------------------
// Aggregation pipeline — where Mongo gets interesting.
// ---------------------------------------------------------------------------

// Total sales per customer (≈ GROUP BY customer.id, SUM(total)).
print("\n--- total spent per customer ---");
printjson(
    db.orders.aggregate([
        { $match: { status: "shipped" } },             // ≈ WHERE
        { $group: {
            _id: "$customer.id",                       // ≈ GROUP BY
            customer: { $first: "$customer.name" },
            orderCount: { $sum: 1 },
            totalSpent: { $sum: "$total" }
        }},
        { $sort: { totalSpent: -1 } }                  // ≈ ORDER BY
    ]).toArray()
);

// Unroll an array with $unwind — emits one document per array element.
// This is how you "go relational" temporarily inside a pipeline.
print("\n--- top-selling SKUs by unit count ---");
printjson(
    db.orders.aggregate([
        { $unwind: "$items" },                          // one doc per line item
        { $group: {
            _id: "$items.sku",
            name: { $first: "$items.name" },
            unitsSold: { $sum: "$items.qty" },
            revenue: { $sum: { $multiply: ["$items.qty", "$items.price"] } }
        }},
        { $sort: { unitsSold: -1 } }
    ]).toArray()
);

// HAVING equivalent — another $match AFTER the $group.
print("\n--- customers with more than one order ---");
printjson(
    db.orders.aggregate([
        { $group: {
            _id: "$customer.id",
            name: { $first: "$customer.name" },
            orderCount: { $sum: 1 }
        }},
        { $match: { orderCount: { $gt: 1 } } },         // ≈ HAVING
        { $project: { _id: 0, name: 1, orderCount: 1 } } // ≈ SELECT
    ]).toArray()
);

// ---------------------------------------------------------------------------
// $lookup — Mongo's JOIN. Fetches matching docs from another collection.
// Slower and stricter than a SQL JOIN; use sparingly.
// ---------------------------------------------------------------------------

// Set up a `customers` collection for the demo.
db.customers.drop();
db.customers.insertMany([
    { _id: 42, loyalty: "gold",   joinedAt: new Date("2024-01-10") },
    { _id: 43, loyalty: "silver", joinedAt: new Date("2025-06-22") },
]);

print("\n--- orders with looked-up customer loyalty tier ---");
printjson(
    db.orders.aggregate([
        { $lookup: {
            from: "customers",
            localField: "customer.id",
            foreignField: "_id",
            as: "customerInfo"
        }},
        // $lookup returns an ARRAY (could match 0..N). $unwind it to flatten.
        { $unwind: { path: "$customerInfo", preserveNullAndEmptyArrays: true } },
        { $project: {
            _id: 0,
            orderNo: 1,
            total: 1,
            "customer.name": 1,
            loyalty: "$customerInfo.loyalty"
        }}
    ]).toArray()
);

// ---------------------------------------------------------------------------
// $facet — run several pipelines against the same input in one call.
// Useful for "dashboard" queries that need multiple summaries at once.
// ---------------------------------------------------------------------------
print("\n--- dashboard: total orders + revenue by status, in one query ---");
printjson(
    db.orders.aggregate([
        { $facet: {
            totalOrders: [ { $count: "count" } ],
            revenueByStatus: [
                { $group: { _id: "$status", total: { $sum: "$total" } } },
                { $sort: { total: -1 } }
            ],
            biggestSingleOrder: [
                { $sort: { total: -1 } },
                { $limit: 1 },
                { $project: { _id: 0, orderNo: 1, total: 1 } }
            ]
        }}
    ]).toArray()
);

// ---------------------------------------------------------------------------
// Reading tip:
//   The aggregation pipeline is its own language. Once you learn 10-15 stages
//   ($match, $group, $project, $sort, $limit, $skip, $unwind, $lookup,
//    $addFields, $facet, $count) you can express almost anything SQL can.
//   It's verbose compared to SQL's single query, but composable — each stage
//   is a standalone transformation you can debug independently.
// ---------------------------------------------------------------------------
