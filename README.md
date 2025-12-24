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




