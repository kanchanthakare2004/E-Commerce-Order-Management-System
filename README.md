# E-Commerce-Order-Management-System
Build six procedures covering product search, stock validation, order placement, order cancellation, customer history and sales reporting, with special attention to stock consistency.

## Contents

```
database.sql      Tables, constraints, sequences, sample data
procedures.sql    All 6 procedures + bonus procedure + demo script
README.md         This file
```

## Quick start

```sql
SQL> SET SERVEROUTPUT ON
SQL> @database.sql
SQL> @procedures.sql
```

Both scripts are idempotent — `database.sql` drops its own tables/sequences first, so
re-running from a clean slate is always safe.

Because Oracle procedures can't hand back a result grid directly, six of the seven
procedures return an `OUT SYS_REFCURSOR`. Calling one from SQL*Plus looks like this:

```sql
VARIABLE rc REFCURSOR
EXEC SearchProducts('Electronics', 50000, :rc);
PRINT rc
```

`PlaceOrder` and `CancelOrder` are action procedures rather than reports, so they return
scalar `OUT` values (new order id, total, status, restored quantity) and also print a
confirmation via `DBMS_OUTPUT`.

## Data model

| Table | Rows | Key points |
|---|---|---|
| `customers` | 8 | `customer_id` PK, unique email, status Active/Inactive |
| `products` | 15 | `product_id` PK, `stock_quantity >= 0` enforced by a CHECK constraint |
| `orders` | 15 | `order_id` PK, FK → customers, status Pending/Completed/Cancelled |
| `order_items` | 25 | `order_item_id` PK, FK → orders (cascade) and products, unique per (order, product) |

Two decisions worth knowing about going in:

- **`unit_price` lives on the line item, not just on the product.** Catalogue prices
  move over time; freezing the price at the moment of sale keeps historical orders
  accurate no matter what happens to `products.price` afterward.
- **The seeded `stock_quantity` values are already net of the sample orders.** What you
  see in `products` right after loading `database.sql` is what should remain after
  orders 5001–5015 were placed and orders 5004/5013 were cancelled — not the original
  warehouse stock. A check query at the end of `database.sql` confirms every order's
  `total_amount` reconciles against its line items.

No `AUTO_INCREMENT` in Oracle, so four sequences (`seq_customer_id`, `seq_product_id`,
`seq_order_id`, `seq_order_item_id`) generate new ids, starting just past the highest
seeded value so the sample rows keep their readable numbering.

## The procedures

| # | Procedure | What it does |
|---|---|---|
| 1 | `SearchProducts` | Active products by category/max price, cheapest first. Both filters optional. |
| 2 | `CheckStock` | Sufficient/insufficient verdict for a product + quantity, with shortfall. |
| 3 | `PlaceOrder` | Validates, locks the product row, inserts order + line, deducts stock — all in one transaction. |
| 4 | `CancelOrder` | Cancels a Pending order and restores every line's stock via one `MERGE`. |
| 5 | `GetCustomerOrderHistory` | Full order history per customer with `LISTAGG`-rolled product lists, newest first. |
| 6 | `GetSalesReport` | Completed-order stats (count, units, revenue, avg order value) for a date range. |
| ★ | `GetTopSellingProducts` | Top 5 products by quantity sold in a date range (bonus). |

### Where the actual logic lives

**`PlaceOrder`** is the one that carries the stock-consistency requirement from the brief.
The sequence is: validate customer → `SELECT … FOR UPDATE` on the product (this is what
stops two simultaneous orders from both seeing "enough stock" and overselling the last
unit) → check status/stock → insert order → insert line → **only then** decrement stock →
commit. Anything that fails partway triggers `ROLLBACK; RAISE;`, so a rejected order never
leaves a half-written row or phantom stock change behind.

**`CancelOrder`** mirrors that discipline in reverse: lock the order header, refuse
anything that isn't `Pending` (a already-cancelled order raises a different error than a
completed one, since they're different mistakes), restore stock for *every* line with a
single `MERGE` rather than a loop, flip the status, commit.

**`GetSalesReport`** and **`GetTopSellingProducts`** both validate the date range up
front (neither date NULL, start ≤ end) and both explicitly handle an empty period —
the report returns a row of zeros with a status message rather than nothing at all.

## Error codes

Business-rule failures raise `RAISE_APPLICATION_ERROR` in the `-20001` to `-20018` range,
so a Java/`.NET`/whatever caller sees a real exception instead of a silent no-op. Missing
rows are caught with `NO_DATA_FOUND` and turned into a message naming the id that didn't
resolve. Covered: invalid quantities, unknown customer/product/order ids, inactive
customers or products, insufficient stock, cancelling something that isn't Pending, and
malformed date ranges.

## Running the demo

`procedures.sql` ends with a full SQL*Plus script (commented out) that exercises every
procedure including the failure cases. Suggested flow for a screen recording:

1. `SearchProducts` — with a category, then with none
2. `CheckStock` — a comfortable quantity, a shortfall, an invalid product id
3. Check stock on product 301 → `PlaceOrder(101, 301, 2)` → check stock again → try an
   order that should fail, then confirm stock didn't move
4. Check stock on 301 & 303 → `CancelOrder(5001)` → check again to see both restored →
   try cancelling a Completed order
5. `GetCustomerOrderHistory(101)`
6. `GetSalesReport` for a real month, then for a month with nothing in it
7. `GetTopSellingProducts`

Keep `SERVEROUTPUT` on throughout — half the story is in the `DBMS_OUTPUT` lines, not
just the grids.
