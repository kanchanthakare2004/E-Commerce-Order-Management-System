SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

-- create SearchProducts Procedures
CREATE OR REPLACE PROCEDURE SearchProducts (
    p_category   IN  VARCHAR2 DEFAULT NULL,
    p_max_price  IN  NUMBER   DEFAULT NULL,
    p_result     OUT SYS_REFCURSOR
)
AS
    v_category VARCHAR2(60) := TRIM(p_category);
BEGIN
 
    IF v_category IS NULL OR LENGTH(v_category) = 0 THEN
        v_category := NULL;
    END IF;

    IF p_max_price IS NOT NULL AND p_max_price < 0 THEN
        RAISE_APPLICATION_ERROR(-20001,
            'Search failed: max_price cannot be negative.');
    END IF;

    OPEN p_result FOR
        SELECT p.product_id,
               p.product_name,
               p.category,
               p.price,
               p.stock_quantity,
               CASE WHEN p.stock_quantity = 0  THEN 'Out of Stock'
                    WHEN p.stock_quantity < 10 THEN 'Low Stock'
                    ELSE 'In Stock'
               END AS stock_status
        FROM   products p
        WHERE  p.status = 'Active'
          AND  (v_category  IS NULL OR UPPER(p.category) = UPPER(v_category))
          AND  (p_max_price IS NULL OR p.price <= p_max_price)
        ORDER  BY p.price ASC, p.product_name ASC;
END SearchProducts;
/


-- create CheckStock Procedures

CREATE OR REPLACE PROCEDURE CheckStock (
    p_product_id         IN  NUMBER,
    p_requested_quantity IN  NUMBER,
    p_result             OUT SYS_REFCURSOR
)
AS
    v_product_name   products.product_name%TYPE;
    v_stock          products.stock_quantity%TYPE;
    v_product_status products.status%TYPE;
BEGIN

    IF p_requested_quantity IS NULL OR p_requested_quantity <= 0 THEN
        RAISE_APPLICATION_ERROR(-20002,
            'Invalid request: requested quantity must be greater than zero.');
    END IF;


    BEGIN
        SELECT product_name, stock_quantity, status
          INTO v_product_name, v_stock, v_product_status
        FROM   products
        WHERE  product_id = p_product_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003,
                'Invalid request: product_id ' || p_product_id || ' does not exist.');
    END;

   
    IF v_product_status <> 'Active' THEN
        RAISE_APPLICATION_ERROR(-20004,
            'Product "' || v_product_name || '" is inactive and not available for sale.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('Product        : ' || v_product_name);
    DBMS_OUTPUT.PUT_LINE('Available stock: ' || v_stock);
    DBMS_OUTPUT.PUT_LINE('Requested      : ' || p_requested_quantity);
    DBMS_OUTPUT.PUT_LINE('Result         : ' ||
        CASE WHEN v_stock >= p_requested_quantity
             THEN 'Sufficient Stock' ELSE 'Insufficient Stock' END);

    OPEN p_result FOR
        SELECT p_product_id                                AS product_id,
               v_product_name                              AS product_name,
               v_stock                                     AS available_stock,
               p_requested_quantity                        AS requested_quantity,
               CASE WHEN v_stock >= p_requested_quantity
                    THEN 'Sufficient Stock'
                    ELSE 'Insufficient Stock'
               END                                         AS stock_status,
               GREATEST(p_requested_quantity - v_stock, 0) AS shortfall
        FROM   dual;
END CheckStock;
/

-- create PlaceOrder Procedures

CREATE OR REPLACE PROCEDURE PlaceOrder (
    p_customer_id  IN  NUMBER,
    p_product_id   IN  NUMBER,
    p_quantity     IN  NUMBER,
    p_order_id     OUT NUMBER,
    p_total_amount OUT NUMBER,
    p_order_status OUT VARCHAR2
)
AS
    v_customer_name   customers.customer_name%TYPE;
    v_customer_status customers.status%TYPE;
    v_product_name    products.product_name%TYPE;
    v_product_status  products.status%TYPE;
    v_price           products.price%TYPE;
    v_stock           products.stock_quantity%TYPE;
BEGIN
  
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE_APPLICATION_ERROR(-20005,
            'Order rejected: quantity must be greater than zero.');
    END IF;

    BEGIN
        SELECT customer_name, status
          INTO v_customer_name, v_customer_status
        FROM   customers
        WHERE  customer_id = p_customer_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006,
                'Order rejected: customer_id ' || p_customer_id || ' does not exist.');
    END;

    IF v_customer_status <> 'Active' THEN
        RAISE_APPLICATION_ERROR(-20007,
            'Order rejected: customer account is inactive.');
    END IF;

  
    BEGIN
        SELECT product_name, price, stock_quantity, status
          INTO v_product_name, v_price, v_stock, v_product_status
        FROM   products
        WHERE  product_id = p_product_id
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20008,
                'Order rejected: product_id ' || p_product_id || ' does not exist.');
    END;

    IF v_product_status <> 'Active' THEN
        RAISE_APPLICATION_ERROR(-20009,
            'Order rejected: product "' || v_product_name || '" is inactive.');
    END IF;

    IF v_stock < p_quantity THEN
        RAISE_APPLICATION_ERROR(-20010,
            'Order rejected: insufficient stock for "' || v_product_name ||
            '". Available ' || v_stock || ', requested ' || p_quantity || '.');
    END IF;

    p_order_id     := seq_order_id.NEXTVAL;
    p_total_amount := v_price * p_quantity;
    p_order_status := 'Pending';

    -- 1. Order header
    INSERT INTO orders (order_id, customer_id, order_date, order_status, total_amount)
    VALUES (p_order_id, p_customer_id, TRUNC(SYSDATE), p_order_status, p_total_amount);

    -- 2. Order line
    INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price)
    VALUES (seq_order_item_id.NEXTVAL, p_order_id, p_product_id, p_quantity, v_price);

    -- 3. Reduce stock ONLY after both inserts have succeeded.
    UPDATE products
    SET    stock_quantity = stock_quantity - p_quantity
    WHERE  product_id = p_product_id;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('--------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Order placed successfully');
    DBMS_OUTPUT.PUT_LINE('Order ID       : ' || p_order_id);
    DBMS_OUTPUT.PUT_LINE('Customer       : ' || v_customer_name);
    DBMS_OUTPUT.PUT_LINE('Product        : ' || v_product_name || ' x' || p_quantity);
    DBMS_OUTPUT.PUT_LINE('Total amount   : ' || TO_CHAR(p_total_amount, 'FM999999990.00'));
    DBMS_OUTPUT.PUT_LINE('Order status   : ' || p_order_status);
    DBMS_OUTPUT.PUT_LINE('Stock left     : ' || (v_stock - p_quantity));
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;              
        RAISE;                     
END PlaceOrder;
/

-- create CancelOrder Procedures

CREATE OR REPLACE PROCEDURE CancelOrder (
    p_order_id            IN  NUMBER,
    p_cancel_status       OUT VARCHAR2,
    p_restored_quantity   OUT NUMBER
)
AS
    v_order_status   orders.order_status%TYPE;
    v_total          orders.total_amount%TYPE;
    v_lines_restored NUMBER := 0;
BEGIN
 
    BEGIN
        SELECT order_status, total_amount
          INTO v_order_status, v_total
        FROM   orders
        WHERE  order_id = p_order_id
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20011,
                'Cancellation failed: order_id ' || p_order_id || ' does not exist.');
    END;

    IF v_order_status = 'Cancelled' THEN
        RAISE_APPLICATION_ERROR(-20012,
            'Cancellation failed: order ' || p_order_id || ' is already cancelled.');
    ELSIF v_order_status <> 'Pending' THEN
        RAISE_APPLICATION_ERROR(-20013,
            'Cancellation failed: only Pending orders can be cancelled. Order ' ||
            p_order_id || ' is ' || v_order_status || '.');
    END IF;

  
    SELECT NVL(SUM(quantity), 0), COUNT(*)
      INTO p_restored_quantity, v_lines_restored
    FROM   order_items
    WHERE  order_id = p_order_id;

   
    MERGE INTO products p
    USING (SELECT product_id, SUM(quantity) AS qty
           FROM   order_items
           WHERE  order_id = p_order_id
           GROUP  BY product_id) src
    ON    (p.product_id = src.product_id)
    WHEN MATCHED THEN
        UPDATE SET p.stock_quantity = p.stock_quantity + src.qty;

    
    UPDATE orders
    SET    order_status = 'Cancelled'
    WHERE  order_id = p_order_id;

    COMMIT;

    p_cancel_status := 'Cancelled';

    DBMS_OUTPUT.PUT_LINE('--------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Order cancelled and stock restored');
    DBMS_OUTPUT.PUT_LINE('Order ID          : ' || p_order_id);
    DBMS_OUTPUT.PUT_LINE('Status            : ' || p_cancel_status);
    DBMS_OUTPUT.PUT_LINE('Line items        : ' || v_lines_restored);
    DBMS_OUTPUT.PUT_LINE('Units restored    : ' || p_restored_quantity);
    DBMS_OUTPUT.PUT_LINE('Amount released   : ' || TO_CHAR(v_total, 'FM999999990.00'));
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END CancelOrder;
/

-- create GetCustomerOrderHistory Procedures

CREATE OR REPLACE PROCEDURE GetCustomerOrderHistory (
    p_customer_id IN  NUMBER,
    p_result      OUT SYS_REFCURSOR
)
AS
    v_customer_name customers.customer_name%TYPE;
    v_order_count   NUMBER := 0;
BEGIN
    BEGIN
        SELECT customer_name
          INTO v_customer_name
        FROM   customers
        WHERE  customer_id = p_customer_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20014,
                'Lookup failed: customer_id ' || p_customer_id || ' does not exist.');
    END;

    SELECT COUNT(*) INTO v_order_count
    FROM   orders
    WHERE  customer_id = p_customer_id;

    
    IF v_order_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No orders found for customer ' ||
                             p_customer_id || ' (' || v_customer_name || ').');
        OPEN p_result FOR
            SELECT p_customer_id   AS customer_id,
                   v_customer_name AS customer_name,
                   'No orders found for this customer' AS message
            FROM   dual;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Order history for ' || v_customer_name ||
                             ' : ' || v_order_count || ' order(s).');
        OPEN p_result FOR
            SELECT c.customer_id,
                   c.customer_name,
                   c.city,
                   o.order_id,
                   TO_CHAR(o.order_date, 'DD-MON-YYYY') AS order_date,
                   LISTAGG(p.product_name, ', ')
                       WITHIN GROUP (ORDER BY p.product_name) AS products,
                   LISTAGG(p.product_name || ' x' || oi.quantity, ' | ')
                       WITHIN GROUP (ORDER BY p.product_name) AS product_details,
                   COUNT(oi.order_item_id)              AS item_count,
                   SUM(oi.quantity)                     AS total_quantity,
                   SUM(oi.quantity * oi.unit_price)     AS items_value,
                   o.total_amount,
                   o.order_status
            FROM   customers   c
            JOIN   orders      o  ON o.customer_id = c.customer_id
            JOIN   order_items oi ON oi.order_id   = o.order_id
            JOIN   products    p  ON p.product_id  = oi.product_id
            WHERE  c.customer_id = p_customer_id
            GROUP  BY c.customer_id, c.customer_name, c.city,
                      o.order_id, o.order_date, o.total_amount, o.order_status
            ORDER  BY o.order_date DESC, o.order_id DESC;
    END IF;
END GetCustomerOrderHistory;
/

-- create GetSalesReport Procedures

CREATE OR REPLACE PROCEDURE GetSalesReport (
    p_start_date IN  DATE,
    p_end_date   IN  DATE,
    p_result     OUT SYS_REFCURSOR
)
AS
    v_order_count NUMBER := 0;
    v_units_sold  NUMBER := 0;
    v_total_sales NUMBER := 0;
    v_avg_value   NUMBER := 0;
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE_APPLICATION_ERROR(-20015,
            'Report failed: start_date and end_date are both required.');
    END IF;

    IF p_start_date > p_end_date THEN
        RAISE_APPLICATION_ERROR(-20016,
            'Report failed: start_date cannot be later than end_date.');
    END IF;

    SELECT COUNT(*), NVL(SUM(total_amount), 0)
      INTO v_order_count, v_total_sales
    FROM   orders
    WHERE  order_status = 'Completed'
      AND  order_date BETWEEN TRUNC(p_start_date) AND TRUNC(p_end_date);

    SELECT NVL(SUM(oi.quantity), 0)
      INTO v_units_sold
    FROM   orders o
    JOIN   order_items oi ON oi.order_id = o.order_id
    WHERE  o.order_status = 'Completed'
      AND  o.order_date BETWEEN TRUNC(p_start_date) AND TRUNC(p_end_date);

  
    v_avg_value := CASE WHEN v_order_count = 0 THEN 0
                        ELSE ROUND(v_total_sales / v_order_count, 2)
                   END;

    IF v_order_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No completed sales between ' ||
            TO_CHAR(p_start_date, 'DD-MON-YYYY') || ' and ' ||
            TO_CHAR(p_end_date,   'DD-MON-YYYY') || '.');
    END IF;

    OPEN p_result FOR
        SELECT TO_CHAR(p_start_date, 'DD-MON-YYYY') AS period_start,
               TO_CHAR(p_end_date,   'DD-MON-YYYY') AS period_end,
               v_order_count AS completed_order_count,
               v_units_sold  AS total_units_sold,
               v_total_sales AS total_sales,
               v_avg_value   AS average_order_value,
               CASE WHEN v_order_count = 0
                    THEN 'No completed sales in the selected period'
                    ELSE 'Report generated successfully'
               END           AS report_status
        FROM   dual;
END GetSalesReport;
/

-- create GetTopSellingProducts Procedures

CREATE OR REPLACE PROCEDURE GetTopSellingProducts (
    p_start_date IN  DATE,
    p_end_date   IN  DATE,
    p_result     OUT SYS_REFCURSOR
)
AS
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE_APPLICATION_ERROR(-20017,
            'Report failed: start_date and end_date are both required.');
    END IF;

    IF p_start_date > p_end_date THEN
        RAISE_APPLICATION_ERROR(-20018,
            'Report failed: start_date cannot be later than end_date.');
    END IF;

    OPEN p_result FOR
        SELECT *
        FROM (
            SELECT p.product_id,
                   p.product_name,
                   p.category,
                   SUM(oi.quantity)                 AS quantity_sold,
                   SUM(oi.quantity * oi.unit_price) AS sales_amount,
                   COUNT(DISTINCT o.order_id)       AS orders_containing_product
            FROM   order_items oi
            JOIN   orders   o ON o.order_id   = oi.order_id
            JOIN   products p ON p.product_id = oi.product_id
            WHERE  o.order_status = 'Completed'
              AND  o.order_date BETWEEN TRUNC(p_start_date) AND TRUNC(p_end_date)
            GROUP  BY p.product_id, p.product_name, p.category
            ORDER  BY SUM(oi.quantity) DESC, SUM(oi.quantity * oi.unit_price) DESC
        )
        WHERE ROWNUM <= 5;
END GetTopSellingProducts;
/



SELECT object_name, object_type, status
FROM   user_objects
WHERE  object_type = 'PROCEDURE'
ORDER  BY object_name;

SHOW ERRORS




SET SERVEROUTPUT ON
VARIABLE rc  REFCURSOR
VARIABLE oid NUMBER
VARIABLE amt NUMBER
VARIABLE st  VARCHAR2(20)
VARIABLE qty NUMBER

-- 1. Search ------------------------------------------------------------
EXEC SearchProducts('Electronics', 50000, :rc);
PRINT rc
EXEC SearchProducts(NULL, 5000, :rc);
PRINT rc

-- 2. Stock check -------------------------------------------------------
EXEC CheckStock(301, 3, :rc);
PRINT rc
EXEC CheckStock(309, 50, :rc);
PRINT rc
EXEC CheckStock(999, 1, :rc);      -- ORA-20003 product does not exist
EXEC CheckStock(301, 0, :rc);      -- ORA-20002 invalid quantity
EXEC CheckStock(312, 1, :rc);      -- ORA-20004 inactive product

-- 3. Place order -------------------------------------------------------
SELECT product_id, product_name, stock_quantity FROM products WHERE product_id = 301;
EXEC PlaceOrder(101, 301, 2, :oid, :amt, :st);
PRINT oid amt st
SELECT product_id, product_name, stock_quantity FROM products WHERE product_id = 301;
SELECT * FROM orders      WHERE order_id >= 5016;
SELECT * FROM order_items WHERE order_id >= 5016;

EXEC PlaceOrder(108, 301, 1,   :oid, :amt, :st);   -- ORA-20007 inactive customer
EXEC PlaceOrder(101, 309, 500, :oid, :amt, :st);   -- ORA-20010 insufficient stock
EXEC PlaceOrder(999, 301, 1,   :oid, :amt, :st);   -- ORA-20006 unknown customer
-- stock is unchanged after every failure:
SELECT product_id, stock_quantity FROM products WHERE product_id IN (301, 309);

-- 4. Cancel order ------------------------------------------------------
SELECT product_id, stock_quantity FROM products WHERE product_id IN (301, 303);
EXEC CancelOrder(5001, :st, :qty);
PRINT st qty
SELECT product_id, stock_quantity FROM products WHERE product_id IN (301, 303);
SELECT order_id, order_status FROM orders WHERE order_id = 5001;

EXEC CancelOrder(5001, :st, :qty);   -- ORA-20012 already cancelled
EXEC CancelOrder(5002, :st, :qty);   -- ORA-20013 order is Completed
EXEC CancelOrder(9999, :st, :qty);   -- ORA-20011 order does not exist

-- 5. Customer history --------------------------------------------------
EXEC GetCustomerOrderHistory(101, :rc);
PRINT rc
EXEC GetCustomerOrderHistory(999, :rc);   -- ORA-20014 unknown customer

-- 6. Sales report ------------------------------------------------------
EXEC GetSalesReport(DATE '2026-09-01', DATE '2026-09-30', :rc);
PRINT rc
EXEC GetSalesReport(DATE '2020-01-01', DATE '2020-12-31', :rc);   -- no-sales period
PRINT rc
EXEC GetSalesReport(DATE '2026-09-30', DATE '2026-09-01', :rc);   -- ORA-20016

-- Bonus ----------------------------------------------------------------
EXEC GetTopSellingProducts(DATE '2026-08-01', DATE '2026-09-30', :rc);
PRINT rc

  

