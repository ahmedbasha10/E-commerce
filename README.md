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