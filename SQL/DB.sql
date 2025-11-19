CREATE database IF NOT EXISTS e_commerce;

use e_commerce;

Create Table customer(
	id int auto_increment,
    first_name varchar(50) NOT NULL,
    last_name varchar(50) NOT NULL,
    email varchar(100) NOT NULL UNIQUE,
    password varchar(255) NOT NULL,
	primary key (id)
);

Create Table orders(
	id int auto_increment,
    customer_id int NOT NULL,
    order_date DATETIME NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) REFERENCES customer(id)
);

Create Table category (
	id int auto_increment,
    name varchar(50) NOT NULL UNIQUE,
    PRIMARY KEY (id)
);

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


-- Data Insertion

INSERT INTO customer (first_name, last_name, email, password) VALUES
('Ahmed', 'Khaled', 'ahmed1@example.com', 'hash1'),
('Sara', 'Hassan', 'sara2@example.com', 'hash2'),
('Omar', 'Ali', 'omar3@example.com', 'hash3'),
('Mona', 'Youssef', 'mona4@example.com', 'hash4'),
('Karim', 'Mostafa', 'karim5@example.com', 'hash5'),
('Huda', 'Nabil', 'huda6@example.com', 'hash6'),
('Yassin', 'Fathy', 'yassin7@example.com', 'hash7'),
('Laila', 'Ibrahim', 'laila8@example.com', 'hash8'),
('Nour', 'Salem', 'nour9@example.com', 'hash9'),
('Samir', 'Tawfik', 'samir10@example.com', 'hash10');

INSERT INTO category (name) VALUES
('Electronics'),
('Clothing'),
('Books'),
('Home Appliances'),
('Sports'),
('Beauty'),
('Furniture'),
('Groceries'),
('Toys'),
('Automotive');

INSERT INTO product (category_id, name, description, price, stock_quantity) VALUES
(1, 'Smartphone A1', 'High-end smartphone', 799.99, 50),
(2, 'Men T-Shirt', 'Cotton t-shirt', 19.99, 200),
(3, 'Novel Book', 'Bestselling fiction novel', 12.50, 150),
(4, 'Microwave Oven', '900W microwave', 120.00, 40),
(5, 'Football', 'Professional football', 25.99, 80),
(6, 'Lipstick', 'Matte red lipstick', 9.99, 120),
(7, 'Office Chair', 'Ergonomic chair', 250.00, 20),
(8, 'Pasta Pack', '500g Italian pasta', 2.15, 500),
(9, 'Lego Set', 'Creative construction set', 45.00, 60),
(10, 'Car Air Filter', 'High-performance filter', 18.99, 100);

INSERT INTO orders (customer_id, order_date, total_amount) VALUES
(1, '2025-10-10 10:15:00', 120.50),  -- November 2024
(2, '2025-10-10 14:20:00', 250.00),  -- November 2024
(3, '2024-11-05 09:45:00', 45.99),   -- December 2024
(4, '2024-10-18 11:00:00', 799.99),  -- January 2025
(5, '2025-01-25 16:30:00', 19.99),   -- January 2025
(6, '2025-02-14 13:15:00', 350.40),  -- February 2025
(7, '2025-03-09 17:50:00', 75.00),   -- March 2025
(8, '2025-03-27 08:22:00', 18.48),   -- March 2025
(9, '2025-04-03 19:10:00', 99.99),   -- April 2025
(10, '2025-05-11 12:33:00', 259.00); -- May 2025

INSERT INTO orders (customer_id, order_date, total_amount) VALUES
(1, '2025-10-29 10:15:00', 420.50);

INSERT INTO order_details (order_id, product_id, quantity, unit_price) VALUES
(1, 4, 1, 120.50),      -- Microwave
(2, 7, 1, 250.00),      -- Office Chair
(3, 5, 1, 25.99),       -- Football
(4, 1, 1, 799.99),      -- Smartphone
(5, 2, 1, 19.99),       -- T-shirt
(6, 7, 1, 250.00),      -- Office Chair
(6, 6, 1, 9.99),        -- Lipstick
(7, 9, 1, 45.00),       -- Lego Set
(8, 8, 4, 2.15),        -- Pasta Pack (x4)
(9, 3, 2, 12.50);       -- Novel (x2)

--

SELECT SUM(orders.total_amount) as 'Total Day Revenue'
FROM orders
WHERE orders.order_date BETWEEN "2024-11-10 00:00:00" AND "2024-11-10 23:59:59";

SELECT od.product_id, p.name, SUM(od.quantity) as total_quantity
FROM order_details od INNER JOIN product p
ON od.product_id = p.id
INNER JOIN orders o
ON od.order_id = o.id
WHERE o.order_date >= '2025-03-01' AND o.order_date < '2025-04-01'
GROUP BY od.product_id
ORDER BY total_quantity DESC
LIMIT 3;

SELECT CONCAT(c.first_name, " ", c.last_name) as Name, SUM(o.total_amount) as total_spent
FROM customer c INNER JOIN orders o
ON c.id = o.customer_id
WHERE o.order_date >= DATE_FORMAT(CURRENT_DATE - INTERVAL 1 MONTH, '%Y-%m-01')
  AND o.order_date <  DATE_FORMAT(CURRENT_DATE, '%Y-%m-01')
GROUP BY c.id
HAVING total_spent > 500
ORDER BY total_spent DESC;