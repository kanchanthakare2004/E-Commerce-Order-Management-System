
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF


BEGIN
    FOR t IN (SELECT 'ORDER_ITEMS' tab FROM dual UNION ALL
              SELECT 'ORDERS'           FROM dual UNION ALL
              SELECT 'PRODUCTS'         FROM dual UNION ALL
              SELECT 'CUSTOMERS'        FROM dual)
    LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || t.tab || ' CASCADE CONSTRAINTS PURGE';
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE != -942 THEN RAISE; END IF; 
        END;
    END LOOP;

    FOR s IN (SELECT 'SEQ_CUSTOMER_ID' seq FROM dual UNION ALL
              SELECT 'SEQ_PRODUCT_ID'      FROM dual UNION ALL
              SELECT 'SEQ_ORDER_ID'        FROM dual UNION ALL
              SELECT 'SEQ_ORDER_ITEM_ID'   FROM dual)
    LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.seq;
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE != -2289 THEN RAISE; END IF; 
        END;
    END LOOP;
END;
/


CREATE TABLE customers (
    customer_id   NUMBER(10)     NOT NULL,
    customer_name VARCHAR2(100)  NOT NULL,
    email         VARCHAR2(150)  NOT NULL,
    city          VARCHAR2(60)   NOT NULL,
    status        VARCHAR2(10)   DEFAULT 'Active' NOT NULL,
    created_at    DATE           DEFAULT SYSDATE  NOT NULL,
    CONSTRAINT pk_customers        PRIMARY KEY (customer_id),
    CONSTRAINT uq_customers_email  UNIQUE (email),
    CONSTRAINT chk_customer_status CHECK (status IN ('Active','Inactive'))
);


CREATE TABLE products (
    product_id     NUMBER(10)     NOT NULL,
    product_name   VARCHAR2(120)  NOT NULL,
    category       VARCHAR2(60)   NOT NULL,
    price          NUMBER(10,2)   NOT NULL,
    stock_quantity NUMBER(10)     DEFAULT 0        NOT NULL,
    status         VARCHAR2(10)   DEFAULT 'Active' NOT NULL,
    CONSTRAINT pk_products        PRIMARY KEY (product_id),
    CONSTRAINT chk_product_price  CHECK (price >= 0),
    CONSTRAINT chk_product_stock  CHECK (stock_quantity >= 0),
    CONSTRAINT chk_product_status CHECK (status IN ('Active','Inactive'))
);

CREATE INDEX idx_products_category ON products (category, price);


CREATE TABLE orders (
    order_id     NUMBER(10)    NOT NULL,
    customer_id  NUMBER(10)    NOT NULL,
    order_date   DATE          DEFAULT SYSDATE   NOT NULL,
    order_status VARCHAR2(12)  DEFAULT 'Pending' NOT NULL,
    total_amount NUMBER(12,2)  DEFAULT 0         NOT NULL,
    CONSTRAINT pk_orders          PRIMARY KEY (order_id),
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id),
    CONSTRAINT chk_order_status CHECK (order_status IN ('Pending','Completed','Cancelled')),
    CONSTRAINT chk_order_total  CHECK (total_amount >= 0)
);

CREATE INDEX idx_orders_customer ON orders (customer_id, order_date);
CREATE INDEX idx_orders_status   ON orders (order_status, order_date);


CREATE TABLE order_items (
    order_item_id NUMBER(10)    NOT NULL,
    order_id      NUMBER(10)    NOT NULL,
    product_id    NUMBER(10)    NOT NULL,
    quantity      NUMBER(10)    NOT NULL,
    unit_price    NUMBER(10,2)  NOT NULL,
    CONSTRAINT pk_order_items         PRIMARY KEY (order_item_id),
    CONSTRAINT fk_order_items_order   FOREIGN KEY (order_id)
        REFERENCES orders (order_id) ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product FOREIGN KEY (product_id)
        REFERENCES products (product_id),
    CONSTRAINT uq_order_product   UNIQUE (order_id, product_id),  
    CONSTRAINT chk_item_quantity  CHECK (quantity > 0),
    CONSTRAINT chk_item_price     CHECK (unit_price >= 0)
);

CREATE INDEX idx_order_items_product ON order_items (product_id);


CREATE SEQUENCE seq_customer_id   START WITH 109  INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_product_id    START WITH 316  INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_order_id      START WITH 5016 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_order_item_id START WITH 9026 INCREMENT BY 1 NOCACHE NOCYCLE;




-- customers (8 records) ------------------------------------------------
INSERT INTO customers (customer_id, customer_name, email, city, status) VALUES (101, 'Aarav Sharma',  'aarav.sharma@example.com', 'Mumbai',    'Active');
INSERT INTO customers (customer_id, customer_name, email, city, status) VALUES (102, 'Diya Patel',    'diya.patel@example.com',   'Ahmedabad', 'Active');
INSERT INTO customers (customer_id, customer_name, email, city, status) VALUES (103, 'Rohan Mehta',   'rohan.mehta@example.com',  'Pune',      'Active');
INSERT INTO customers (customer_id, customer_name, email, city, status) VALUES (104, 'Ishita Nair',   'ishita.nair@example.com',  'Kochi',     'Active');
INSERT INTO customers (customer_id, customer_name, email, city, status) VALUES (105, 'Kabir Singh',   'kabir.singh@example.com',  'Delhi',     'Active');
INSERT INTO customers (customer_id, customer_name, email, city, status) VALUES (106, 'Ananya Reddy',  'ananya.reddy@example.com', 'Hyderabad', 'Active');
INSERT INTO customers (customer_id, customer_name, email, city, status) VALUES (107, 'Vikram Joshi',  'vikram.joshi@example.com', 'Nagpur',    'Active');
INSERT INTO customers (customer_id, customer_name, email, city, status) VALUES (108, 'Meera Iyer',    'meera.iyer@example.com',   'Chennai',   'Inactive');

-- products (15 records) ------------------------------------------------
INSERT INTO products VALUES (301, 'Smartphone X200',        'Electronics', 45000.00,  25, 'Active');
INSERT INTO products VALUES (302, 'Laptop Pro 14',          'Electronics', 78000.00,  12, 'Active');
INSERT INTO products VALUES (303, 'Wireless Earbuds',       'Electronics',  3500.00,  80, 'Active');
INSERT INTO products VALUES (304, 'Bluetooth Speaker',      'Electronics',  2999.00,  60, 'Active');
INSERT INTO products VALUES (305, 'Smart Watch S2',         'Electronics', 12500.00,  30, 'Active');
INSERT INTO products VALUES (306, 'LED TV 43 inch',         'Electronics', 32000.00,  10, 'Active');
INSERT INTO products VALUES (307, 'Microwave Oven',         'Appliances',   9500.00,  18, 'Active');
INSERT INTO products VALUES (308, 'Air Fryer 4L',           'Appliances',   6800.00,  22, 'Active');
INSERT INTO products VALUES (309, 'Vacuum Cleaner',         'Appliances',  11000.00,   9, 'Active');
INSERT INTO products VALUES (310, 'Ergonomic Office Chair', 'Furniture',    7500.00,  15, 'Active');
INSERT INTO products VALUES (311, 'Study Table',            'Furniture',    5400.00,  11, 'Active');
INSERT INTO products VALUES (312, 'Wooden Bookshelf',       'Furniture',    4200.00,   7, 'Inactive');
INSERT INTO products VALUES (313, 'Running Shoes',          'Fashion',      2750.00,  45, 'Active');
INSERT INTO products VALUES (314, 'Leather Wallet',         'Fashion',      1200.00,  50, 'Active');
INSERT INTO products VALUES (315, 'Notebook Pack of 5',     'Stationery',    350.00, 200, 'Active');

-- orders (15 records) --------------------------------------------------
INSERT INTO orders VALUES (5001, 101, DATE '2026-09-02', 'Pending',   52000.00);
INSERT INTO orders VALUES (5002, 102, DATE '2026-09-03', 'Completed', 78000.00);
INSERT INTO orders VALUES (5003, 103, DATE '2026-09-05', 'Completed', 26200.00);
INSERT INTO orders VALUES (5004, 104, DATE '2026-09-06', 'Cancelled', 32000.00);
INSERT INTO orders VALUES (5005, 101, DATE '2026-09-08', 'Completed', 17700.00);
INSERT INTO orders VALUES (5006, 105, DATE '2026-09-09', 'Pending',   15000.00);
INSERT INTO orders VALUES (5007, 106, DATE '2026-09-10', 'Completed',  7900.00);
INSERT INTO orders VALUES (5008, 107, DATE '2026-09-11', 'Completed',  8997.00);
INSERT INTO orders VALUES (5009, 102, DATE '2026-09-12', 'Completed', 12900.00);
INSERT INTO orders VALUES (5010, 108, DATE '2026-09-13', 'Pending',   14500.00);
INSERT INTO orders VALUES (5011, 103, DATE '2026-09-15', 'Completed', 48500.00);
INSERT INTO orders VALUES (5012, 104, DATE '2026-09-16', 'Completed', 15250.00);
INSERT INTO orders VALUES (5013, 105, DATE '2026-09-18', 'Cancelled', 78000.00);
INSERT INTO orders VALUES (5014, 106, DATE '2026-08-28', 'Completed', 34999.00);
INSERT INTO orders VALUES (5015, 107, DATE '2026-08-30', 'Completed', 13600.00);

-- order_items (25 records) ---------------------------------------------
INSERT INTO order_items VALUES (9001, 5001, 301,  1, 45000.00);
INSERT INTO order_items VALUES (9002, 5001, 303,  2,  3500.00);
INSERT INTO order_items VALUES (9003, 5002, 302,  1, 78000.00);
INSERT INTO order_items VALUES (9004, 5003, 305,  2, 12500.00);
INSERT INTO order_items VALUES (9005, 5003, 314,  1,  1200.00);
INSERT INTO order_items VALUES (9006, 5004, 306,  1, 32000.00);
INSERT INTO order_items VALUES (9007, 5005, 307,  1,  9500.00);
INSERT INTO order_items VALUES (9008, 5005, 308,  1,  6800.00);
INSERT INTO order_items VALUES (9009, 5005, 315,  4,   350.00);
INSERT INTO order_items VALUES (9010, 5006, 310,  2,  7500.00);
INSERT INTO order_items VALUES (9011, 5007, 313,  2,  2750.00);
INSERT INTO order_items VALUES (9012, 5007, 314,  2,  1200.00);
INSERT INTO order_items VALUES (9013, 5008, 304,  3,  2999.00);
INSERT INTO order_items VALUES (9014, 5009, 311,  1,  5400.00);
INSERT INTO order_items VALUES (9015, 5009, 310,  1,  7500.00);
INSERT INTO order_items VALUES (9016, 5010, 309,  1, 11000.00);
INSERT INTO order_items VALUES (9017, 5010, 315, 10,   350.00);
INSERT INTO order_items VALUES (9018, 5011, 301,  1, 45000.00);
INSERT INTO order_items VALUES (9019, 5011, 303,  1,  3500.00);
INSERT INTO order_items VALUES (9020, 5012, 305,  1, 12500.00);
INSERT INTO order_items VALUES (9021, 5012, 313,  1,  2750.00);
INSERT INTO order_items VALUES (9022, 5013, 302,  1, 78000.00);
INSERT INTO order_items VALUES (9023, 5014, 306,  1, 32000.00);
INSERT INTO order_items VALUES (9024, 5014, 304,  1,  2999.00);
INSERT INTO order_items VALUES (9025, 5015, 308,  2,  6800.00);

COMMIT;


SELECT 'CUSTOMERS' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'PRODUCTS',      COUNT(*) FROM products
UNION ALL SELECT 'ORDERS',        COUNT(*) FROM orders
UNION ALL SELECT 'ORDER_ITEMS',   COUNT(*) FROM order_items;


.
SELECT o.order_id,
       o.total_amount,
       SUM(oi.quantity * oi.unit_price) AS calculated_total
FROM   orders o
JOIN   order_items oi ON oi.order_id = o.order_id
GROUP  BY o.order_id, o.total_amount
HAVING o.total_amount <> SUM(oi.quantity * oi.unit_price);
