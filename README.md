# E-commerce

## Introduction

This document provides a design for a simple e-commerce database system. 
It includes the database schema, entity relationships, example SQL queries for reporting, and de-normalization strategies.

---

## 1. Database ERD and Schema

<img src="images/E-commerceDB.png" alt="ERD Diagram" width="1674"/>

---

## 2. Database Creation Script

### 2.1 Create Database
```sql
CREATE database IF NOT EXISTS e_commerce;
use e_commerce;
```

### 2.2 Create Customer Table
```sql
Create Table customer(
    id int auto_increment,
    first_name varchar(50) NOT NULL,
    last_name varchar(50) NOT NULL,
    email varchar(100) NOT NULL UNIQUE,
    password varchar(255) NOT NULL,
    PRIMARY KEY (id)
);
```

### 2.3 Create Orders Table
```sql
Create Table orders(
    id int auto_increment,
    customer_id int NOT NULL,
    order_date DATETIME NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) REFERENCES customer(id)
);
```

### 2.4 Create Category Table
```sql
Create Table category (
    id int auto_increment,
    name varchar(50) NOT NULL UNIQUE,
    PRIMARY KEY (id)
);
```

### 2.5 Create Product Table
```sql
Create Table product (
    id int auto_increment,
    category_id int NOT NULL,
    name varchar(50) NOT NULL,
    description varchar (200),
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity int NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_product_category FOREIGN KEY (category_id) REFERENCES category(id) 
);
```

### 2.6 Create Order Details Table
```sql
Create Table order_details (
    id int auto_increment,
    order_id int NOT NULL,
    product_id int NOT NULL,
    quantity int NOT NULL CHECK(quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_order_details_orders FOREIGN KEY (order_id) REFERENCES orders(id),
    CONSTRAINT fk_order_details_product FOREIGN KEY (product_id) REFERENCES product(id)
);
```

---

## 3. SQL Queries for Reporting

### 3.1 Daily Revenue Report
```sql
SELECT SUM(orders.total_amount) as 'Total Day Revenue'
FROM orders
WHERE orders.order_date BETWEEN "2024-11-10 00:00:00" AND "2024-11-10 23:59:59";
```

### 3.2 Top 3 Selling Products For a Month

```sql
SELECT od.product_id, p.name, SUM(od.quantity*od.unit_price) as total_revenue
FROM order_details od INNER JOIN product p
ON od.product_id = p.id
INNER JOIN orders o
ON od.order_id = o.id
WHERE o.order_date >= '2025-03-01' AND o.order_date < '2025-04-01'
GROUP BY od.product_id
ORDER BY total_revenue DESC
LIMIT 3;
```

### 3.3 Customers Spent More Than $500 In The Past Month

```sql
SELECT CONCAT(c.first_name, " ", c.last_name) as Name, SUM(o.total_amount) as total_spent
FROM customer c INNER JOIN orders o
ON c.id = o.customer_id
WHERE o.order_date >= DATE_FORMAT(CURRENT_DATE - INTERVAL 1 MONTH, '%Y-%m-01')
  AND o.order_date <  DATE_FORMAT(CURRENT_DATE, '%Y-%m-01')
GROUP BY c.id
HAVING total_spent > 500
ORDER BY total_spent DESC;
```

### 3.4 Search for all products with the word "camera" in either the product name or description

```sql
SELECT p.name, p.description, p.price, c.name as category
FROM product p INNER JOIN category c
ON p.category_id = c.id 
WHERE p.name like '%camera%' or description like '%camera%';
```

### 3.5  design a query to suggest popular products in the same category for the same author, excluding the Purchased product from the recommendations

```SQL
SELECT p2.id, p2.name, COALESCE(SUM(od2.quantity), 0) As popularity
FROM (
	SELECT DISTINCT p.category_id
    FROM orders o
    INNER JOIN order_details od ON o.id = od.order_id
    INNER JOIN product p ON p.id = od.product_id
    WHERE o.customer_id = 1
) AS customer_categories
INNER JOIN product p2 ON p2.category_id = customer_categories.category_id
LEFT JOIN order_details od2 ON od2.product_id = p2.id
WHERE p2.id NOT IN (
	SELECT DISTINCT od.product_id
    FROM orders o
    INNER JOIN order_details od ON o.id = od.order_id
    WHERE o.customer_id = 1
)
GROUP BY p2.id
ORDER BY popularity DESC
LIMIT 10;
```

### 3.6 Create a trigger to create a sale history
```sql
DELIMITER $$
CREATE TRIGGER sale_history_trigger
AFTER INSERT
ON order_details
FOR EACH ROW
BEGIN
	INSERT INTO sale_history (customer_id, product_id, total_amount, quantity, order_date)
    SELECT customer_id, product_id, total_amount, quantity, order_date 
    FROM orders o INNER JOIN order_details od
    ON o.id = od.order_id
    WHERE od.order_id = New.order_id;
END$$
DELIMITER ;
```

### 3.7 Transaction query to lock the field quantity with product id = 211 from being updated
```sql
BEGIN;
SELECT id FROM product WHERE id=211 FOR UPDATE;
COMMIT;
```

### 3.8 Transaction query to lock row with product id = 211 from being updated
```sql
BEGIN;
SELECT * FROM product WHERE id=211 FOR UPDATE;
COMMIT;
```
---

## 4. De-normalization

We can de-normalize the order table by adding the concatenated customer first_name and last_name to the order table,
to avoid joining on each reporting query to retrieve customer name.

---

## 5. SQL Optimizations

### 5.1 Execution without performance enhancements

Query:

```sql
EXPLAIN ANALYZE SELECT name FROM userinfo WHERE name = 'John Brown';
```

#### 5.1.1 Analyze Query Plan

```text
-> Filter: (userinfo.`name` = 'John Brown')  (cost=1.06e+6 rows=993273) (actual time=8.33..4216 rows=250000 loops=1)
     -> Table scan on userinfo  (cost=1.06e+6 rows=9.93e+6) (actual time=8.32..3636 rows=10e+6 loops=1)
```

#### 5.1.2 Query Benchmark

run the query 10 times and calculate QPS:

**Total Time: 43 seconds**

**QPS: 0.23**

---

### 5.2 Execution with adding an individual index on name column

Query:
```sql
EXPLAIN ANALYZE SELECT name FROM userinfo WHERE name = 'John Brown';
```

#### 5.2.1 Analyze Query Plan

We have 250000 rows matching the criteria.

```text
-> Covering index lookup on userinfo using name_idx (name='John Brown')  (cost=63232 rows=481760) (actual time=0.0789..118 rows=250000 loops=1)
```

#### 5.2.2 Query Benchmark

run the query 10 times and calculate QPS:

**Total Time: 15 seconds**

**QPS: 0.66**

---

### 5.3 Composite Index vs Individual Indexes

If we are executing a query that has multiple conditions, if we created individual indexes, it will execute both indexes
separately and then merge the results, which is less efficient than using a composite index.

Query:
```sql
EXPLAIN ANALYZE SELECT COUNT(*) FROM userinfo WHERE name = 'John Brown' AND state_id = 1;
```

#### 5.3.1 Analyze Query Plan without Indexes
With this approach, the database engine performs a full table scan, resulting in a higher cost and longer execution time.
It filters the rows based on both conditions after scanning the entire table.

```text
-> Aggregate: count(0)  (cost=1.1e+6 rows=1) (actual time=4194..4194 rows=1 loops=1)
    -> Filter: ((userinfo.state_id = 1) and (userinfo.`name` = 'John Brown'))  (cost=1.07e+6 rows=99183) (actual time=0.944..4189 rows=50000 loops=1)
        -> Table scan on userinfo  (cost=1.07e+6 rows=9.92e+6) (actual time=0.933..3786 rows=10e+6 loops=1)
```

#### 5.3.1 Analyze Query Plan with Individual Indexes on `name` and `state_id`
With this approach, the database engine uses both individual indexes to filter rows based on each condition separately.
It then uses the Intersect operator to merge the results.

```text
-> Aggregate: count(0)  (cost=21985 rows=1) (actual time=393..393 rows=1 loops=1)
    -> Filter: ((userinfo.state_id = 1) and (userinfo.`name` = 'John Brown'))  (cost=17430 rows=19765) (actual time=2.06..392 rows=50000 loops=1)
        -> Intersect rows sorted by row ID  (cost=17430 rows=19765) (actual time=2.06..384 rows=50000 loops=1)
            -> Index range scan on userinfo using state_idx over (state_id = 1)  (cost=978e-6..398 rows=406922) (actual time=0.0295..135 rows=200000 loops=1)
            -> Index range scan on userinfo using name_idx over (name = 'John Brown')  (cost=0.0313..15056 rows=481760) (actual time=2.02..234 rows=250000 loops=1)
```

#### 5.3.2 Benchmark with Individual Indexes

**Total Time: 1.3 seconds**

**QPS: 7.8**

#### 5.3.3 Analyze Query Plan with Composite Indexes
Using a composite index on `(name, state_id)`, the database engine can efficiently filter rows based on both conditions simultaneously,
resulting in a lower cost and faster execution time.

```text
-> Aggregate: count(0)  (cost=37058 rows=1) (actual time=24.5..24.5 rows=1 loops=1)
    -> Covering index lookup on userinfo using name_state_idx (name='John Brown', state_id=1)  (cost=13515 rows=102178) (actual time=0.0467..23.2 rows=50000 loops=1)
```

#### 5.3.4 Benchmark with Composite Indexes

running the query 10 times:

**Total Time: 0.12 seconds**

**QPS: 83**


#### 5.3.5 Composite Index Order

The order of columns in a composite index matters. The most selective column should be placed first.
Also, the equality conditions should come before range conditions in the index definition for optimal performance, 
because the range index will not allow the equality index to be used effectively.


#### 5.3.6 Redundant Indexes

Sometimes, If we have two queries that are used frequently, one of them works well with a single index, but the other query works with composite index,
and the single index of the first query is a prefix of the composite index of the second query (redundant).

In this case, we can keep both indexes for faster query time but with a drawback of slower write operations.

---

### 5.4 Choosing the Primary Key

Choosing the correct primary key is very important for performance, as it affects indexing, data retrieval speed, and overall database efficiency.

Incremental surrogate keys are better than random non-sequential (UUID) keys for the following reasons:

- They are easy to generate and maintain.
- They provide better performance for indexing and querying, as they reduce fragmentation.

Non-sequential keys can lead to more frequent page splits and fragmentation in indexes to find its correct place to be stored,
which can degrade performance over time.

**Questions:**
1- Is the auto-increment surrogate key leads to security issues? because it is predictable?

Now, we are going to run tests to compare the performance of auto-increment surrogate keys vs random UUID keys.
We are going to run 1 million inserts and measure the time taken for each approach.

#### 5.4.1 Surrogate Key With Auto Increment Performance

**Total Test Time: 228.5 seconds**

#### 5.4.2 Random UUID Key Performance

**Total Test Time: 1542.5 seconds**

---

## 6. Query Optimizations

### 6.1 Retrieve the total number of products in each category

#### 6.1.1 Original Query

```sql
SELECT category_name, COUNT(*) AS 'number of products'
FROM category INNER JOIN product
ON category.category_id = product.category_id
GROUP BY category.category_id;
```

#### 6.1.2 Query Plan Analysis

```text
-> Group aggregate: count(0)  (cost=1.64e+6 rows=97480) (actual time=3.47..2581 rows=100000 loops=1)
    -> Nested loop inner join  (cost=533958 rows=4.81e+6) (actual time=3.45..2431 rows=5e+6 loops=1)
        -> Index scan on category using PRIMARY  (cost=10034 rows=97480) (actual time=1.28..73.9 rows=100000 loops=1)
        -> Covering index lookup on product using fk_product_category (category_id=category.category_id)  (cost=0.436 rows=49.4) (actual time=0.0183..0.0214 rows=50 loops=100000)
```

#### 6.1.3 Optimization Technique

MySQL already uses primary and foreign keys to optimize the join operation, 
but we can optimize by rewriting the query to use subqueries to reduce the number of rows processed in the join.

#### 6.1.4 Rewrite Query

```sql
SELECT category.category_name, product_categories.number_of_products FROM category INNER JOIN (
	SELECT category_id, count(*) as 'number_of_products'
	FROM product
	GROUP BY product.category_id) product_categories 
ON category.category_id = product_categories.category_id;
```

#### 6.1.5 Query Plan Analysis After Optimization

```text
-> Nested loop inner join  (cost=962e+6 rows=9.61e+9) (actual time=1579..1735 rows=100000 loops=1)
    -> Covering index scan on category using category_name  (cost=9954 rows=97480) (actual time=0.0389..84.7 rows=100000 loops=1)
    -> Index lookup on product_categories using <auto_key0> (category_id=category.category_id)  (cost=1.65e+6..1.65e+6 rows=49.9) (actual time=0.0163..0.0164 rows=1 loops=100000)
        -> Materialize  (cost=1.65e+6..1.65e+6 rows=98549) (actual time=1579..1579 rows=100000 loops=1)
            -> Group aggregate: count(0)  (cost=1.63e+6 rows=98549) (actual time=0.0296..1498 rows=100000 loops=1)
                -> Covering index scan on product using fk_product_category  (cost=509684 rows=4.87e+6) (actual time=0.021..1354 rows=5e+6 loops=1)

```

#### 6.1.6 Benchmark Results

| Execution Time Before Optimization | Optimization Technique   | Rewrite Query                   | Execution Time After Optimization |
|-----------------------------------|--------------------------|---------------------------------|-----------------------------------|
| 2.5s                              | Reducing number of joins | Create subquery to reduce joins | 1.7s                              |


---

### 6.2 Find the top customers by total spending

#### 6.2.1 Original Query

```sql
SELECT 
  CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
  o.total_spending
FROM customer c
INNER JOIN (
    SELECT customer_id, SUM(total_amount) AS total_spending
    FROM orders
    GROUP BY customer_id
    ORDER BY total_spending DESC 
    LIMIT 10
) o ON o.customer_id = c.customer_id;
```

#### 6.2.2 Query Plan Analysis

```text
-> Nested loop inner join  (cost=12.5 rows=0) (actual time=36963..36965 rows=10 loops=1)
    -> Table scan on o  (cost=2.5..2.5 rows=0) (actual time=36961..36961 rows=10 loops=1)
        -> Materialize  (cost=0..0 rows=0) (actual time=36961..36961 rows=10 loops=1)
            -> Limit: 10 row(s)  (actual time=36961..36961 rows=10 loops=1)
                -> Sort: total_spending DESC, limit input to 10 row(s) per chunk  (actual time=36961..36961 rows=10 loops=1)
                    -> Stream results  (cost=6.48e+6 rows=5e+6) (actual time=13.2..36404 rows=5e+6 loops=1)
                        -> Group aggregate: sum(orders.total_amount)  (cost=6.48e+6 rows=5e+6) (actual time=13.2..35834 rows=5e+6 loops=1)
                            -> Index scan on orders using idx_orders_customer  (cost=1.99e+6 rows=19.5e+6) (actual time=13.2..34237 rows=20e+6 loops=1)
    -> Single-row index lookup on c using PRIMARY (customer_id=o.customer_id)  (cost=1.01 rows=1) (actual time=0.333..0.333 rows=1 loops=10)

```

#### 6.2.3 Optimization Technique

We can optimize the query by creating a composite index on the `orders` table that includes both `customer_id` and `total_amount`.

#### 6.2.4 Query Plan Analysis After Optimization

```text
-> Nested loop inner join  (cost=12.5 rows=0) (actual time=8974..8976 rows=10 loops=1)
    -> Table scan on o  (cost=2.5..2.5 rows=0) (actual time=8965..8965 rows=10 loops=1)
        -> Materialize  (cost=0..0 rows=0) (actual time=8965..8965 rows=10 loops=1)
            -> Limit: 10 row(s)  (actual time=8965..8965 rows=10 loops=1)
                -> Sort: total_spending DESC, limit input to 10 row(s) per chunk  (actual time=8965..8965 rows=10 loops=1)
                    -> Stream results  (cost=6.48e+6 rows=5e+6) (actual time=0.0401..8428 rows=5e+6 loops=1)
                        -> Group aggregate: sum(orders.total_amount)  (cost=6.48e+6 rows=5e+6) (actual time=0.0374..7814 rows=5e+6 loops=1)
                            -> Covering index scan on orders using idx_orders_customer_amount  (cost=1.99e+6 rows=19.5e+6) (actual time=0.0325..6241 rows=20e+6 loops=1)
    -> Single-row index lookup on c using PRIMARY (customer_id=o.customer_id)  (cost=1.01 rows=1) (actual time=1.08..1.08 rows=1 loops=10)

```

#### 6.2.5 Benchmark Results

| Execution Time Before Optimization | Optimization Technique            | Execution Time After Optimization |
|-----------------------------------|-----------------------------------|-----------------------------------|
| 36.9s                             | Composite Index on (customer_id, total_amount) | 8.9s                              |


---

### 6.3 Retrieve the most recent orders with customer information with 1000 orders

#### 6.3.1 Original Query

```sql
SELECT c.customer_id, first_name, last_name, email, order_date  
FROM customer c INNER JOIN (
	SELECT o.customer_id, o.order_date 
    FROM orders o
	ORDER BY order_date DESC 
    LIMIT 10
    ) recent_orders
ON c.customer_id = recent_orders.customer_id;
```

#### 6.3.2 Query Plan Analysis

```text
-> Nested loop inner join  (cost=1.99e+6 rows=10) (actual time=5410..5410 rows=10 loops=1)
    -> Table scan on recent_orders  (cost=1.99e+6..1.99e+6 rows=10) (actual time=5409..5409 rows=10 loops=1)
        -> Materialize  (cost=1.99e+6..1.99e+6 rows=10) (actual time=5409..5409 rows=10 loops=1)
            -> Limit: 10 row(s)  (cost=1.99e+6 rows=10) (actual time=5409..5409 rows=10 loops=1)
                -> Sort: o.order_date DESC, limit input to 10 row(s) per chunk  (cost=1.99e+6 rows=19.5e+6) (actual time=5409..5409 rows=10 loops=1)
                    -> Table scan on o  (cost=1.99e+6 rows=19.5e+6) (actual time=8.35..3784 rows=20e+6 loops=1)
    -> Single-row index lookup on c using PRIMARY (customer_id=recent_orders.customer_id)  (cost=1.01 rows=1) (actual time=0.102..0.102 rows=1 loops=10)
```

#### 6.3.3 Optimization Technique

We can optimize the query by creating an index on the `order_date` column in the `orders` table.

#### 6.3.4 Query Plan Analysis After Optimization

```text
-> Nested loop inner join  (cost=1348 rows=1000) (actual time=11.4..15.4 rows=1000 loops=1)
    -> Table scan on recent_orders  (cost=233..248 rows=1000) (actual time=10.5..10.5 rows=1000 loops=1)
        -> Materialize  (cost=233..233 rows=1000) (actual time=10.5..10.5 rows=1000 loops=1)
            -> Limit: 1000 row(s)  (cost=2.43 rows=1000) (actual time=8.43..10.3 rows=1000 loops=1)
                -> Index scan on o using idx_orders__date (reverse)  (cost=2.43 rows=1000) (actual time=8.43..10.3 rows=1000 loops=1)
    -> Single-row index lookup on c using PRIMARY (customer_id=recent_orders.customer_id)  (cost=1 rows=1) (actual time=0.00471..0.00474 rows=1 loops=1000)
```

#### 6.3.5 Benchmark Results

| Execution Time Before Optimization | Optimization Technique            | Execution Time After Optimization |
|-----------------------------------|-----------------------------------|-----------------------------------|
| 5.4s                              | Index on order_date               | 0.015s                            |


---

### 6.4 List products that have low stock quantities of less than 10 quantities

#### 6.4.1 Original Query

```sql
SELECT name, stock_quantity
FROM product
WHERE stock_quantity < 10;
```

#### 6.4.2 Query Plan Analysis

```text
-> Filter: (product.stock_quantity < 10)  (cost=507797 rows=1.62e+6) (actual time=1.17..1452 rows=95000 loops=1)
    -> Table scan on product  (cost=507797 rows=4.87e+6) (actual time=1.16..1299 rows=5e+6 loops=1)
```

#### 6.4.3 Optimization Technique
We can optimize the query by creating a composite index on the `stock_quantity` and `name` columns in the `product` table.

```sql
CREATE INDEX idx_quantity_name
ON product (stock_quantity, name);
```

#### 6.4.4 Query Plan Analysis After Optimization

```text
-> Filter: (product.stock_quantity < 10)  (cost=43721 rows=194310) (actual time=0.022..47.4 rows=95000 loops=1)
    -> Covering index range scan on product using idx_quantity over (stock_quantity < 10)  (cost=43721 rows=194310) (actual time=0.0207..42.8 rows=95000 loops=1)
```

#### 6.4.5 Benchmark Results

| Execution Time Before Optimization | Optimization Technique                  | Execution Time After Optimization |
|-----------------------------------|-----------------------------------------|-----------------------------------|
| 1.45s                             | Composite Index on (stock_quantity, name) | 0.048s                            |

---

### 6.5 Calculate the revenue generated from each product category

#### 6.5.1 Original Query

```sql
SELECT c.category_name, category_revenue.total 
FROM category c  INNER JOIN (
	SELECT p.category_id, sum(od.quantity * od.unit_price) total 
    FROM product p INNER JOIN order_details od 
    ON p.product_id = od.product_id
    GROUP BY p.category_id 
) AS category_revenue  
ON c.category_id = category_revenue.category_id;
```

#### 6.5.2 Query Plan Analysis

```text
-> Nested loop inner join  (cost=11.3e+6 rows=0) (actual time=121466..121623 rows=100000 loops=1)
    -> Covering index scan on c using category_name  (cost=10036 rows=97480) (actual time=0.0318..81.9 rows=100000 loops=1)
    -> Index lookup on category_revenue using <auto_key0> (category_id=c.category_id)  (cost=0.25..116 rows=464) (actual time=1.22..1.22 rows=1 loops=100000)
        -> Materialize  (cost=0..0 rows=0) (actual time=121466..121466 rows=100000 loops=1)
            -> Table scan on <temporary>  (actual time=121390..121397 rows=100000 loops=1)
                -> Aggregate using temporary table  (actual time=121390..121390 rows=100000 loops=1)
                    -> Nested loop inner join  (cost=50.4e+6 rows=45.3e+6) (actual time=8.17..97312 rows=50e+6 loops=1)
                        -> Table scan on od  (cost=4.64e+6 rows=45.3e+6) (actual time=8.15..12252 rows=50e+6 loops=1)
                        -> Single-row index lookup on p using PRIMARY (product_id=od.product_id)  (cost=0.911 rows=1) (actual time=0.00156..0.00158 rows=1 loops=50e+6)
```

#### 6.5.3 Optimization Technique

```sql
CREATE INDEX idx_product_order_details
ON order_details (product_id, order_detail_id);

CREATE INDEX idx_order_details_covering
ON order_details(product_id, quantity, unit_price);
```

#### 6.5.4 Query Plan Analysis After Optimization

```text
-> Nested loop inner join  (cost=972e+6 rows=9.61e+9) (actual time=46447..46603 rows=100000 loops=1)
    -> Covering index scan on c using category_name  (cost=10036 rows=97480) (actual time=8.15..91.9 rows=100000 loops=1)
    -> Index lookup on category_revenue using <auto_key0> (category_id=c.category_id)  (cost=20.1e+6..20.1e+6 rows=453) (actual time=0.465..0.465 rows=1 loops=100000)
        -> Materialize  (cost=20.1e+6..20.1e+6 rows=98549) (actual time=46438..46438 rows=100000 loops=1)
            -> Group aggregate: sum((od.quantity * od.unit_price))  (cost=20.1e+6 rows=98549) (actual time=18.9..46261 rows=100000 loops=1)
                -> Nested loop inner join  (cost=9.88e+6 rows=44.2e+6) (actual time=1.26..41017 rows=50e+6 loops=1)
                    -> Covering index scan on p using fk_product_category  (cost=510394 rows=4.87e+6) (actual time=0.988..2295 rows=5e+6 loops=1)
                    -> Covering index lookup on od using idx_order_details_covering (product_id=p.product_id)  (cost=1.02 rows=9.08) (actual time=0.00626..0.00719 rows=10 loops=5e+6)
```

#### 6.5.5 Benchmark Results

| Execution Time Before Optimization | Optimization Technique                                    | Execution Time After Optimization |
|-----------------------------------|-----------------------------------------------------------|-----------------------------------|
| 121.6s                            | Composite Indexes on order_details (product_id, order_detail_id), (product_id, quantity, unit_price) | 46.6s                             |
