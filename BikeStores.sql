-- This is a Work-In-Progress SSMS sandbox where I practice writing intermediate/advance scripts
-- Used in this script: Subqueries inside FROM, Subqueries inside SELECT, Subqueries inside WHERE, Window Functions, 
-- Sliding Windows, CASE statements, Left Join, Inner Join, Except


-- Profit per each product category for bikes built in 2018.
SELECT category_name, profit
FROM (SELECT c.category_name, ROUND(SUM(((oi.list_price - oi.list_price*oi.discount) * oi.quantity)), 0) AS profit
		FROM order_items AS oi
		LEFT JOIN products AS p
		ON oi.product_id = p.product_id
		LEFT JOIN categories as c
		ON p.category_id = c.category_id
		WHERE p.model_year = 2018
		GROUP BY c.category_name) AS subquery
ORDER BY profit DESC;

-- Compare products list price with the average price
SELECT product_name, list_price,
	AVG(list_price) OVER() AS avg_price
FROM products
ORDER BY list_price DESC;


-- How many brands each product category has? 
SELECT category_name, 
	(SELECT COUNT(brand_id)
	FROM products
	WHERE categories.category_id = products.category_id) AS brands_count
FROM categories
ORDER BY brands_count DESC;


-- Which stores sold bikes with a discount of 20% and more? Where are those stores located and how many bikes were sold?
SELECT stores.store_name, stores.state, COUNT(orders.order_id) AS Num_of_orders
FROM orders
LEFT JOIN stores
ON orders.store_id = stores.store_id
WHERE order_id IN
	(SELECT order_id
	FROM order_items
	WHERE discount >= 0.2)
GROUP BY stores.store_name, stores.state;

--Amount of rejected orders per store in 2018:
SELECT s.store_name, 
	COUNT(CASE WHEN DATEPART(yy, o.order_date) = 2018
			AND o.order_status = 3
			THEN o.order_id END) AS rejected_orders_2018
FROM orders AS o
LEFT JOIN stores AS s
ON o.store_id = s.store_id
GROUP BY s.store_name;


-- How much does each store earned on average and how does it compare to the overall average?
SELECT s.store_name, ROUND(AVG(((oi.list_price - oi.list_price*oi.discount) * oi.quantity)), 0) AS avg_profit,
	AVG(AVG((oi.list_price - oi.list_price*oi.discount) * oi.quantity)) OVER() AS overall_avg_profit
FROM order_items AS oi
INNER JOIN orders AS o
ON oi.order_id = o.order_id
INNER JOIN stores AS s
ON o.store_id = s.store_id
GROUP BY s.store_name;

-- Return total sales per month and the running total
SELECT DATEPART(yy, o.order_date) AS year, DATEPART(mm, o.order_date) AS month,
	ROUND((SUM(oi.quantity) * SUM(oi.list_price)), 0) AS sales,
	SUM(ROUND(SUM(oi.quantity),0) * ROUND(SUM(oi.list_price),0))
		OVER(ORDER BY MONTH(o.order_date) ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM orders AS o
LEFT JOIN order_items AS oi
ON o.order_id = oi.order_id
--WHERE DATEPART(yy, o.order_date) = 2016 AND DATEPART(mm, o.order_date) = 12
GROUP BY DATEPART(yy, o.order_date), DATEPART(mm, o.order_date)
ORDER BY year, month;


--Customers who placed an order in 2017 but not in 2018. Show their total spending and last order date.
WITH sub AS (
	SELECT o.customer_id, o.order_date, (oi.quantity * oi.list_price) AS total_spending
	FROM orders AS o
	LEFT JOIN order_items AS oi
	ON o.order_id = oi.order_id) -- use USING() instead if not working in Microsoft SQL Server Management Studio
SELECT customer_id, MAX(order_date) AS last_order_date, ROUND(SUM(total_spending),0) AS total_spending
FROM sub 
WHERE customer_id IN (
	SELECT customer_id
	FROM orders
	WHERE DATEPART(yy, order_date) = 2017
	EXCEPT 
	SELECT customer_id
	FROM orders
	WHERE DATEPART(yy, order_date) = 2018)
GROUP BY customer_id
ORDER BY customer_id;

-- The top 5 customers with the highest total spending. Include their total number of orders and average order value.
WITH sub AS (
	SELECT o.customer_id, c.email, o.order_id, o.order_date, (oi.quantity * oi.list_price) AS total_spending
	FROM orders AS o
	LEFT JOIN order_items AS oi
	ON o.order_id = oi.order_id
	LEFT JOIN customers AS c
	ON o.customer_id = c.customer_id)
SELECT TOP 5 sub.customer_id, email, COUNT(order_id) AS number_of_orders, ROUND(AVG(total_spending),0) AS avg_order_value
FROM sub
GROUP BY customer_id, email
ORDER BY SUM(total_spending) DESC;

--How many customers placed only one order vs. those who placed multiple orders
WITH one AS (
	SELECT customer_id, COUNT(order_id) AS number_of_orders
	FROM orders
	GROUP BY customer_id
	HAVING COUNT(order_id) = 1),
multiple AS (
	SELECT customer_id, COUNT(order_id) AS number_of_orders2
	FROM orders
	GROUP BY customer_id
	HAVING COUNT(order_id) > 1)
SELECT COUNT(one.customer_id) 
FROM one
UNION 
SELECT COUNT(multiple.customer_id)
FROM multiple;


-- Find the top 5 best-selling products (by quantity) across all stores. 
-- Include the product name, brand name, and total quantity sold.
SELECT TOP 5 p.product_name, b.brand_name, SUM(oi.quantity) AS total_quantity_sold
FROM products AS p
LEFT JOIN brands AS b
ON p.brand_id = b.brand_id
LEFT JOIN order_items AS oi
ON p.product_id = oi.product_id
GROUP BY p.product_name, b.brand_name
ORDER BY total_quantity_sold DESC;


--Which sales reps sold the most and which sold the least?
SELECT s.first_name, s.last_name, SUM(oi.quantity) AS total_quntity_sold,
SUM(oi.quantity * (oi.list_price * oi.discount)) AS total_sales_$,
RANK() OVER(ORDER BY SUM(oi.quantity) DESC) AS quantity_rank,
RANK() OVER(ORDER BY SUM(oi.list_price * oi.discount) DESC) AS sales_rank
FROM staffs AS s
LEFT JOIN orders AS o
ON s.staff_id = o.staff_id
LEFT JOIN order_items AS oi
ON o.order_id = oi.order_id
GROUP BY s.first_name, s.last_name;

